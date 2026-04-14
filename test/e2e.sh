#!/bin/bash
#
# E2E tests for curl-paging
# Usage: ./e2e.sh <path-to-curl-paging-binary>
#
# Requires: mock-server binary in ../mock/mock-server
#

set -uo pipefail

CURL_PAGING="${1:-}"
MOCK_SERVER="${MOCK_SERVER:-$(dirname "$0")/../mock/mock-server}"
PORT="${PORT:-18080}"
BASE_URL="http://127.0.0.1:${PORT}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

log_pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

cleanup() {
    # Kill mock server if running
    if [[ -n "${MOCK_PID:-}" ]]; then
        kill "$MOCK_PID" 2>/dev/null || true
        wait "$MOCK_PID" 2>/dev/null || true
    fi
    # Clean up artifacts
    rm -rf ./paging ./custom_paging 2>/dev/null || true
}

trap cleanup EXIT

# Validation
if [[ -z "$CURL_PAGING" ]]; then
    echo "Usage: $0 <path-to-curl-paging-binary>"
    exit 1
fi

if [[ ! -x "$CURL_PAGING" ]]; then
    echo "Error: $CURL_PAGING is not executable"
    exit 1
fi

if [[ ! -x "$MOCK_SERVER" ]]; then
    echo "Error: $MOCK_SERVER is not executable"
    echo "Build it with: cd ../mock && make build"
    exit 1
fi

# Start mock server
echo "Starting mock server on port $PORT..."
"$MOCK_SERVER" -p "$PORT" >/dev/null 2>&1 &
MOCK_PID=$!
sleep 1

# Check mock server is running
if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "Error: Failed to start mock server"
    exit 1
fi

echo "Running E2E tests against: $CURL_PAGING"
echo "==========================================="
echo ""

# Clean up before tests
rm -rf ./paging ./custom_paging 2>/dev/null || true

# -----------------------------------------------------------------------------
# Test 1: Simple curl wrapper (no --cp)
# -----------------------------------------------------------------------------
echo "Test 1: Simple curl wrapper (default mode)"
rm -rf ./paging
OUTPUT=$("$CURL_PAGING" -s "$BASE_URL/api/items?total_pages=3&page_size=2" 2>/dev/null) || true

# Should return single page with pagination (not aggregated)
if echo "$OUTPUT" | grep -q '"pagination"'; then
    log_pass "Simple wrapper - returns raw response with pagination"
else
    log_fail "Simple wrapper - should include pagination"
fi

# Should NOT create artifacts
if [[ ! -d "./paging" ]]; then
    log_pass "Simple wrapper - no artifacts created"
else
    log_fail "Simple wrapper - should not create artifacts"
fi

# -----------------------------------------------------------------------------
# Test 2: Pagination mode (with --cp)
# -----------------------------------------------------------------------------
echo ""
echo "Test 2: Pagination mode (--cp)"
rm -rf ./paging
OUTPUT=$("$CURL_PAGING" --cp "$BASE_URL/api/items?total_pages=3&page_size=2" 2>/dev/null) || true

if echo "$OUTPUT" | grep -q '"data"'; then
    # Check aggregated count (3 pages * 2 items = 6 items)
    ITEM_COUNT=$(echo "$OUTPUT" | grep -o '"id"' | wc -l)
    if [[ "$ITEM_COUNT" -eq 6 ]]; then
        log_pass "Pagination mode - correct item count"
    else
        log_fail "Pagination mode - expected 6 items, got $ITEM_COUNT"
    fi

    # Check no pagination in output
    if echo "$OUTPUT" | grep -q '"pagination"'; then
        log_fail "Pagination mode - pagination should be stripped"
    else
        log_pass "Pagination mode - pagination stripped"
    fi

    # Check artifacts created
    if [[ -d "./paging/0001" && -d "./paging/0002" && -d "./paging/0003" ]]; then
        log_pass "Pagination mode - artifacts created"
    else
        log_fail "Pagination mode - missing artifacts"
    fi
else
    log_fail "Pagination mode - no output"
fi

# -----------------------------------------------------------------------------
# Test 3: Custom artifacts directory
# -----------------------------------------------------------------------------
echo ""
echo "Test 3: Custom artifacts directory"
rm -rf ./custom_paging
OUTPUT=$("$CURL_PAGING" --cp --cp-artifacts-dir ./custom_paging "$BASE_URL/api/items?total_pages=1" 2>/dev/null) || true

if [[ -d "./custom_paging/0001" ]]; then
    log_pass "Custom artifacts directory"
else
    log_fail "Custom artifacts directory - ./custom_paging/0001 not found"
fi

# -----------------------------------------------------------------------------
# Test 4: Max pages limit (should succeed with limited pages)
# -----------------------------------------------------------------------------
echo ""
echo "Test 4: Max pages limit"
rm -rf ./paging
OUTPUT=$("$CURL_PAGING" --cp --cp-max-pages 2 "$BASE_URL/api/items?total_pages=5&page_size=2" 2>&1) || true

# Should succeed and only fetch 2 pages (4 items)
ITEM_COUNT=$(echo "$OUTPUT" | grep -o '"id"' | wc -l)
if [[ "$ITEM_COUNT" -eq 4 ]]; then
    log_pass "Max pages limit - fetched limited pages"
else
    log_fail "Max pages limit - expected 4 items, got $ITEM_COUNT"
fi

# -----------------------------------------------------------------------------
# Test 5: Fault - missing pagination (in paging mode)
# -----------------------------------------------------------------------------
echo ""
echo "Test 5: Fault - missing pagination"
rm -rf ./paging
if "$CURL_PAGING" --cp "$BASE_URL/api/fault?mode=missing_pagination" >/dev/null 2>&1; then
    log_fail "Missing pagination - should have failed"
else
    log_pass "Missing pagination - correctly rejected"
fi

# -----------------------------------------------------------------------------
# Test 6: Fault - HTTP 500 (in paging mode)
# -----------------------------------------------------------------------------
echo ""
echo "Test 6: Fault - HTTP 500"
rm -rf ./paging
if "$CURL_PAGING" --cp "$BASE_URL/api/fault?mode=http_500" >/dev/null 2>&1; then
    log_fail "HTTP 500 - should have failed"
else
    log_pass "HTTP 500 - correctly rejected"
fi

# -----------------------------------------------------------------------------
# Test 7: Fault - invalid JSON (in paging mode)
# -----------------------------------------------------------------------------
echo ""
echo "Test 7: Fault - invalid JSON"
rm -rf ./paging
if "$CURL_PAGING" --cp "$BASE_URL/api/fault?mode=invalid_json" >/dev/null 2>&1; then
    log_fail "Invalid JSON - should have failed"
else
    log_pass "Invalid JSON - correctly rejected"
fi

# -----------------------------------------------------------------------------
# Test 8: Empty data (should succeed in paging mode)
# -----------------------------------------------------------------------------
echo ""
echo "Test 8: Empty data (valid response)"
rm -rf ./paging
if OUTPUT=$("$CURL_PAGING" --cp "$BASE_URL/api/fault?mode=empty_data&total_pages=1" 2>/dev/null); then
    log_pass "Empty data - succeeded"
else
    log_fail "Empty data - should have succeeded"
fi

# -----------------------------------------------------------------------------
# Test 9: Help output
# -----------------------------------------------------------------------------
echo ""
echo "Test 9: Help output"
HELP_OUTPUT=$("$CURL_PAGING" --help 2>&1) || true
if echo "$HELP_OUTPUT" | grep -q -- "--cp"; then
    log_pass "Help output - shows --cp option"
else
    log_fail "Help output - missing --cp option"
fi

# -----------------------------------------------------------------------------
# Test 10: --cp-XXX without --cp (should be ignored)
# -----------------------------------------------------------------------------
echo ""
echo "Test 10: --cp-XXX without --cp"
rm -rf ./paging
OUTPUT=$("$CURL_PAGING" -s --cp-max-pages 1 "$BASE_URL/api/items?total_pages=3" 2>/dev/null) || true

# Should return raw response (not paginated)
if echo "$OUTPUT" | grep -q '"pagination"'; then
    log_pass "--cp-XXX ignored without --cp"
else
    log_fail "--cp-XXX should be ignored without --cp"
fi

# -----------------------------------------------------------------------------
# Test 11: Artifact contents
# -----------------------------------------------------------------------------
echo ""
echo "Test 11: Artifact file contents"
rm -rf ./paging
"$CURL_PAGING" --cp "$BASE_URL/api/items?total_pages=1" >/dev/null 2>&1 || true

if [[ -f "./paging/0001/res.body" && -f "./paging/0001/res.json" && -f "./paging/0001/res.header" ]]; then
    # res.json should not have pagination
    if grep -q "pagination" ./paging/0001/res.json 2>/dev/null; then
        log_fail "Artifact contents - res.json should not have pagination"
    else
        log_pass "Artifact contents - res.json stripped"
    fi

    # res.body should have pagination (raw response)
    if grep -q "pagination" ./paging/0001/res.body 2>/dev/null; then
        log_pass "Artifact contents - res.body has raw response"
    else
        log_fail "Artifact contents - res.body missing pagination"
    fi
else
    log_fail "Artifact contents - missing files"
fi

# -----------------------------------------------------------------------------
# Test 12: Limit pages safety valve
# -----------------------------------------------------------------------------
echo ""
echo "Test 12: Limit pages safety valve"
rm -rf ./paging
ERROR_OUTPUT=$("$CURL_PAGING" --cp --cp-limit-pages 2 "$BASE_URL/api/items?total_pages=5" 2>&1) || true

# Should fail because total_pages (5) exceeds limit_pages (2)
if echo "$ERROR_OUTPUT" | grep -q "exceeds limit_pages"; then
    log_pass "Limit pages - error when exceeded"
else
    log_fail "Limit pages - should error when exceeded"
    echo "  Output: $ERROR_OUTPUT"
fi

# -----------------------------------------------------------------------------
# Test 13: Infinite loop prevention (non-consecutive duplicate: 1→2→1)
# -----------------------------------------------------------------------------
echo ""
echo "Test 13: Infinite loop prevention (recursive loop)"
rm -rf ./paging
ERROR_OUTPUT=$("$CURL_PAGING" --cp "$BASE_URL/api/fault?mode=loop_trap&total_pages=4" 2>&1) || true

# Page cycle: 1→2→1(duplicate!) - should fail with duplicate page error
if echo "$ERROR_OUTPUT" | grep -q "Duplicate response page"; then
    log_pass "Recursive loop prevention - duplicate page detected"
else
    log_fail "Recursive loop prevention - should detect duplicate page"
    echo "  Output: $ERROR_OUTPUT"
fi

# -----------------------------------------------------------------------------
# Test 14: Single page (total_pages=1)
# -----------------------------------------------------------------------------
echo ""
echo "Test 14: Single page (total_pages=1)"
rm -rf ./paging
OUTPUT=$("$CURL_PAGING" --cp "$BASE_URL/api/items?total_pages=1&page_size=2" 2>/dev/null) || true

ITEM_COUNT=$(echo "$OUTPUT" | grep -o '"id"' | wc -l)
if [[ "$ITEM_COUNT" -eq 2 ]]; then
    log_pass "Single page - correct item count"
else
    log_fail "Single page - expected 2 items, got $ITEM_COUNT"
fi

if [[ -d "./paging/0001" && ! -d "./paging/0002" ]]; then
    log_pass "Single page - only one artifact directory"
else
    log_fail "Single page - should have exactly one artifact directory"
fi

# -----------------------------------------------------------------------------
# Test 15: total_pages=0 should error
# -----------------------------------------------------------------------------
echo ""
echo "Test 15: total_pages=0 (invalid)"
rm -rf ./paging
ERROR_OUTPUT=$("$CURL_PAGING" --cp "$BASE_URL/api/items?total_pages=0" 2>&1) || true

if echo "$ERROR_OUTPUT" | grep -q "must be at least 1"; then
    log_pass "total_pages=0 - correctly rejected"
else
    log_fail "total_pages=0 - should error"
    echo "  Output: $ERROR_OUTPUT"
fi

# -----------------------------------------------------------------------------
# Test 16: -o file output in pagination mode
# -----------------------------------------------------------------------------
echo ""
echo "Test 16: -o file output (pagination mode)"
rm -rf ./paging
rm -f ./test_output.json
"$CURL_PAGING" --cp -o ./test_output.json "$BASE_URL/api/items?total_pages=2&page_size=2" 2>/dev/null || true

if [[ -f "./test_output.json" ]]; then
    ITEM_COUNT=$(grep -o '"id"' ./test_output.json | wc -l)
    if [[ "$ITEM_COUNT" -eq 4 ]]; then
        log_pass "-o file output - correct aggregated content"
    else
        log_fail "-o file output - expected 4 items, got $ITEM_COUNT"
    fi
else
    log_fail "-o file output - file not created"
fi
rm -f ./test_output.json

# -----------------------------------------------------------------------------
# Test 17: -D header output in pagination mode
# -----------------------------------------------------------------------------
echo ""
echo "Test 17: -D header output (pagination mode)"
rm -rf ./paging
rm -f ./test_header.txt
"$CURL_PAGING" --cp -D ./test_header.txt "$BASE_URL/api/items?total_pages=2&page_size=2" >/dev/null 2>/dev/null || true

if [[ -f "./test_header.txt" ]]; then
    if grep -q "HTTP/" ./test_header.txt; then
        log_pass "-D header output - contains HTTP response header"
    else
        log_fail "-D header output - no HTTP header found"
    fi
else
    log_fail "-D header output - file not created"
fi
rm -f ./test_header.txt

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "==========================================="
echo "Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed"

if [[ "$TESTS_FAILED" -gt 0 ]]; then
    exit 1
fi
