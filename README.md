# curl-paging [![CI](https://github.com/maiha/curl-paging/actions/workflows/ci.yml/badge.svg)](https://github.com/maiha/curl-paging/actions/workflows/ci.yml)

A thin curl wrapper that transparently supports paginated APIs.

- All arguments except `--cp` are passed directly to curl as a subprocess
- With `--cp`, fetches all pages by calling curl repeatedly and outputs merged JSON
- Each request/response is saved as artifacts for debugging

## Quick Start

```bash
# Without --cp: same as curl
curl-paging https://api.example.com/items

# With --cp: fetches all pages and outputs merged JSON
curl-paging --cp https://api.example.com/items
```

## Options

### curl-paging options (only effective with --cp)

| Option | Default | Description |
|--------|---------|-------------|
| `--cp` | - | Enable pagination mode |
| `--cp-data-key` | `data` | Item array key in response JSON |
| `--cp-pagination-key` | `pagination` | Pagination metadata key |
| `--cp-page-key` | `page` | Current page key in pagination |
| `--cp-total-pages-key` | `total_pages` | Total pages key in pagination |
| `--cp-page-param` | `page` | Page query parameter name in URL |
| `--cp-max-pages` | unlimited | Max pages to fetch (truncates gracefully) |
| `--cp-limit-pages` | `100` | Page count hard limit (errors if exceeded) |
| `--cp-artifacts-dir` | `./paging` | Directory for per-page artifacts |

### Intercepted curl options (in pagination mode)

| Option | Behavior |
|--------|----------|
| `-o`, `--output` | Writes aggregated result to file (not passed to curl) |
| `-D`, `--dump-header` | Writes last page headers to file (not passed to curl) |

In curl wrapper mode, `-o` is intercepted and `-D` is passed through to curl.

### curl options

All other options are passed through to curl.

## Examples

```bash
# Simple curl wrapper
curl-paging https://api.example.com/items

# Pagination mode
curl-paging --cp https://api.example.com/items

# With headers
curl-paging --cp -H "Authorization: Bearer token" https://api.example.com/items

# Custom keys
curl-paging --cp --cp-data-key items --cp-pagination-key meta https://api.example.com/items

# Limit to 10 pages
curl-paging --cp --cp-max-pages 10 https://api.example.com/items

# Output to file
curl-paging --cp -o result.json https://api.example.com/items
```

## Output

### stdout

On success, outputs aggregated JSON:

```json
{"data":[{"id":1},{"id":2},...]}
```

### Artifacts (./paging/)

A directory is created for each page:

```
./paging/
  0001/
    cmd          - curl command executed
    req.header   - Request headers sent
    req.body     - Request body (if any)
    res.header   - Response headers received
    res.body     - Raw response body
    res.json     - JSON with pagination metadata stripped
  0002/
    ...
```

### Debugging on error

On failure, the `.wip` suffixed directory is left for debugging:

```
./paging/
  0001/           # Successful page
  0002.wip/       # Failed page (for debugging)
    req.header
    res.header
    res.body
```

## Safety

All safety checks are designed to prevent client-side mistakes from causing excessive or repeated requests to the server.

| Check | Exit | stderr | Default |
|-------|------|--------|---------|
| `--cp-limit-pages` | 1 | `total_pages (N) exceeds limit_pages (N)` | 100 |
| `--cp-max-pages` | 0 | `Limiting to N pages (total: N)` | unlimited |
| `total_pages < 1` | 1 | `total_pages (N) must be at least 1` | - |
| Duplicate URL | 1 | `Duplicate URL detected` | - |
| Duplicate page number | 1 | `Duplicate response page detected` | - |
| Clean start | - | - | - |

## Build & Test

Written in Crystal. Builds via Docker.

```bash
make build   # Build binary
make test    # Run E2E tests
make         # Show available tasks
```

## Known Limitations

- Only supports `page/total_pages` pagination (no cursor/next_url/Link header support)
- JSON keys are top-level only (no nested path support)
- No retry mechanism
- Sequential fetching only (no parallel requests)
