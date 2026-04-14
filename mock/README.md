# Mock Server

Mock HTTP server for curl-paging integration tests.

## Build

```bash
make build
```

## Usage

```bash
./mock-server              # Default: 127.0.0.1:8080
./mock-server -p 3000      # Custom port
./mock-server -h 0.0.0.0   # Bind to all interfaces
```

## Endpoints

### GET /api/items

Returns paginated item list.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `page` | 1 | Current page |
| `total_pages` | 3 | Total number of pages |
| `page_size` | 2 | Items per page |
| `page_param` | page | Page parameter name |

```bash
curl http://127.0.0.1:8080/api/items
# {"data":[{"id":"item-1-1","page":1,"index":0},{"id":"item-1-2","page":1,"index":1}],"pagination":{"page":1,"total_pages":3}}

curl "http://127.0.0.1:8080/api/items?page=2&total_pages=5&page_size=3"
```

### GET/POST /api/echo

Echoes request details back.

```bash
curl http://127.0.0.1:8080/api/echo
curl http://127.0.0.1:8080/api/echo -X POST -d '{"test": true}'
```

Response:
```json
{
  "method": "POST",
  "path": "/api/echo",
  "query": {},
  "headers": {"Content-Type": "..."},
  "body": "{\"test\": true}"
}
```

### GET /api/fault

Fault injection endpoint. Use `mode` parameter to select behavior.

| mode | Description |
|------|-------------|
| `http_500` | HTTP 500 Internal Server Error |
| `invalid_json` | Truncated/broken JSON |
| `missing_pagination` | No `pagination` key |
| `missing_data` | No `data` key |
| `wrong_types` | `pagination.page` is a string |
| `inconsistent_total` | `total_pages` changes per page |
| `loop_trap` | Page cycles 1→2→1→2... (triggers loop detection) |
| `empty_data` | `data` is an empty array |
| `slow` | Delayed response (`delay` seconds, default 1) |

```bash
curl "http://127.0.0.1:8080/api/fault?mode=http_500"
curl "http://127.0.0.1:8080/api/fault?mode=invalid_json"
curl "http://127.0.0.1:8080/api/fault?mode=slow&delay=3"
```

## Integration test example

```bash
# Start server
./mock-server -p 18080 &

# Normal case
../curl-paging http://127.0.0.1:18080/api/items

# Error case (should exit non-zero)
../curl-paging "http://127.0.0.1:18080/api/fault?mode=missing_pagination" || echo "Expected failure"

# Stop server
pkill mock-server
```
