# curl-paging

curl互換のCLIラッパーで、オプションでページングAPIから全ページを取得し集約したJSONを出力する。

## 仕様

詳細は [SPEC.md](SPEC.md) を参照。

## 実装

- [crystal/](crystal/) - Crystal実装

## モード

### デフォルト: curlラッパーモード

`--cp` オプションなしの場合、単純にcurlにパススルーする。

```bash
curl-paging https://api.example.com/items
# → curl https://api.example.com/items と同等
```

### ページングモード

`--cp` オプションを指定すると、全ページを取得して集約する。

```bash
curl-paging --cp https://api.example.com/items
# → 全ページを取得し、集約したJSONを出力
```

## オプション

### curl-paging 固有オプション（--cp 指定時のみ有効）

| オプション | デフォルト | 説明 |
|------------|------------|------|
| `--cp` | - | ページングモードを有効化 |
| `--cp-data-key` | `data` | レスポンスJSONのアイテム配列キー名 |
| `--cp-pagination-key` | `pagination` | ページングメタ情報キー名 |
| `--cp-page-key` | `page` | pagination内の現在ページキー名 |
| `--cp-total-pages-key` | `total_pages` | pagination内の総ページ数キー名 |
| `--cp-page-param` | `page` | URLに付加するページパラメータ名 |
| `--cp-max-pages` | 無制限 | 最大ページ数（正常打ち切り） |
| `--cp-limit-pages` | `100` | ページ数上限（超過時エラー終了） |
| `--cp-artifacts-dir` | `./paging` | ページ単位生成物のディレクトリ |

### 特別扱いされるcurlオプション

| オプション | 動作 |
|------------|------|
| `-o`, `--output` | 最終集約結果をファイルに出力（curlには渡さない） |
| `-D`, `--dump-header` | 最終ページのヘッダをファイルに出力（curlには渡さない） |

### curlオプション

上記以外のオプションは全てcurlにパススルーされる。

## 使用例

```bash
# 単純なcurlラッパー
curl-paging https://api.example.com/items

# ページングモード
curl-paging --cp https://api.example.com/items

# ヘッダー付き
curl-paging --cp -H "Authorization: Bearer token" https://api.example.com/items

# カスタムキー
curl-paging --cp --cp-data-key items --cp-pagination-key meta https://api.example.com/items

# 最大10ページで打ち切り
curl-paging --cp --cp-max-pages 10 https://api.example.com/items

# ファイルに出力
curl-paging --cp -o result.json https://api.example.com/items
```

## 出力

### 標準出力

成功時、集約したJSONを出力:

```json
{"data":[{"id":1},{"id":2},...]}
```

### 生成物 (./paging/)

各ページごとにディレクトリが作成される:

```
./paging/
  0001/
    req.header   - 送信したリクエストヘッダ
    req.body     - 送信したリクエストボディ（存在する場合）
    res.header   - 受信したレスポンスヘッダ
    res.body     - 受信したレスポンスボディ（生）
    res.json     - ページングメタ情報を除去したJSON
  0002/
    ...
```

### エラー時のデバッグ

リクエストが失敗した場合、`.wip` サフィックス付きのディレクトリが残る:

```
./paging/
  0001/           # 成功したページ
  0002.wip/       # 失敗したページ（デバッグ用）
    req.header
    res.header
    res.body
```

## 安全機能

- **limit_pages**: 総ページ数がこの値を超えるとエラー終了（デフォルト: 100）
- **重複検出**: 同じpage_idやURLの重複リクエストを検出してエラー終了
- **レスポンス検証**: レスポンスのpage番号の重複を検出してエラー終了

## ビルド

```bash
cd crystal
make build
```

## 既知の制限

- 対応するページング型は `page/total_pages` 型のみ（cursor/next_url/Linkヘッダは未対応）
- JSONキーはトップレベルのみ対応（ネストしたパスは未対応）
- リトライ機能なし
- 並列リクエスト未対応（順次取得のみ）
