# Mock Server

curl-paging の統合テスト用モックHTTPサーバー。

## ビルド

```bash
make build
```

## 起動

```bash
./mock-server              # デフォルト: 127.0.0.1:8080
./mock-server -p 3000      # ポート指定
./mock-server -h 0.0.0.0   # 全インターフェースでバインド
```

## エンドポイント

### GET /api/items

ページング付きアイテム一覧を返す。

| パラメータ | デフォルト | 説明 |
|------------|------------|------|
| `page` | 1 | 現在ページ |
| `total_pages` | 3 | 総ページ数 |
| `page_size` | 2 | 1ページあたり件数 |
| `page_param` | page | ページパラメータ名（このパラメータでページを指定） |

```bash
curl http://127.0.0.1:8080/api/items
# {"data":[{"id":"item-1-1","page":1,"index":0},{"id":"item-1-2","page":1,"index":1}],"pagination":{"page":1,"total_pages":3}}

curl "http://127.0.0.1:8080/api/items?page=2&total_pages=5&page_size=3"
```

### GET/POST /api/echo

リクエスト内容を反射して返す。

```bash
curl http://127.0.0.1:8080/api/echo
curl http://127.0.0.1:8080/api/echo -X POST -d '{"test": true}'
```

レスポンス:
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

異常系シミュレーション。`mode` パラメータで挙動を切り替える。

| mode | 説明 |
|------|------|
| `http_500` | HTTP 500 Internal Server Error |
| `invalid_json` | 壊れたJSON（途中で切断） |
| `missing_pagination` | `pagination` キーなし |
| `missing_data` | `data` キーなし |
| `wrong_types` | `pagination.page` が文字列 |
| `inconsistent_total` | `total_pages` がページごとに変化 |
| `loop_trap` | `page` が常に1（無限ループ誘発） |
| `empty_data` | `data` が空配列 |
| `slow` | `delay` 秒遅延（デフォルト1秒） |

```bash
curl "http://127.0.0.1:8080/api/fault?mode=http_500"
curl "http://127.0.0.1:8080/api/fault?mode=invalid_json"
curl "http://127.0.0.1:8080/api/fault?mode=slow&delay=3"
```

## curl-paging との統合テスト例

```bash
# サーバー起動
./mock-server -p 18080 &

# 正常系テスト
../crystal/curl-paging http://127.0.0.1:18080/api/items

# 異常系テスト（非0で終了することを確認）
../crystal/curl-paging "http://127.0.0.1:18080/api/fault?mode=missing_pagination" || echo "Expected failure"

# サーバー停止
pkill mock-server
```
