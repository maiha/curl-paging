# curl-paging 仕様

## 1. 概要

`curl-paging` は、curl互換のコマンドラインツールである。

- **デフォルト**: 単純なcurlラッパーとして動作
- **ページングモード** (`--cp`指定時): ページングAPIから全ページを取得し、集約したJSONを出力

---

## 2. 動作モード

### 2.1 curlラッパーモード（デフォルト）

`--cp` オプションなしの場合、全ての引数をそのままcurlに渡す。

```bash
curl-paging -H "Auth: token" https://api.example.com/items
# → curl -H "Auth: token" https://api.example.com/items と同等
```

### 2.2 ページングモード

`--cp` オプション指定時、ページングAPIとして処理する。

```bash
curl-paging --cp https://api.example.com/items
```

---

## 3. オプション

### 3.1 curl-paging固有オプション（ページングモード時のみ有効）

| オプション | デフォルト | 説明 |
|------------|------------|------|
| `--cp` | - | ページングモードを有効化 |
| `--cp-data-key` | `data` | アイテム配列のキー名 |
| `--cp-pagination-key` | `pagination` | ページングメタ情報のキー名 |
| `--cp-page-key` | `page` | 現在ページのキー名 |
| `--cp-total-pages-key` | `total_pages` | 総ページ数のキー名 |
| `--cp-page-param` | `page` | URLクエリパラメータ名 |
| `--cp-max-pages` | 無制限 | 最大取得ページ数（正常打ち切り） |
| `--cp-limit-pages` | `100` | ページ数上限（超過時エラー） |
| `--cp-artifacts-dir` | `./paging` | 生成物ディレクトリ |

### 3.2 特別扱いされるcurlオプション

| オプション | curlラッパーモード | ページングモード |
|------------|-------------------|-----------------|
| `-o`, `--output` | curlに渡す | 最終集約結果をファイル出力 |
| `-D`, `--dump-header` | curlに渡す | 最終ページのヘッダをファイル出力 |

### 3.3 URL引数を取るcurlオプション

以下のオプションの値はターゲットURLとして誤検出されない:
`-e`, `--referer`, `--proxy`, `--preproxy`, `--doh-url`

### 3.4 その他のcurlオプション

上記以外は全てcurlにパススルーされる。

---

## 4. 出力と生成物

### 4.1 標準出力

- 成功時：集約したJSONを出力
- 失敗時：集約結果を出力せず、非0で終了

### 4.2 ページ単位の生成物

取得した各ページについて、`./paging/<page_key>/` にディレクトリを作成:

```
./paging/
  0001/
    req.header   - リクエストヘッダ
    req.body     - リクエストボディ（存在する場合）
    res.header   - レスポンスヘッダ
    res.body     - レスポンスボディ（生）
    res.json     - ページング情報を除去したJSON
  0002/
    ...
```

### 4.3 エラー時のデバッグ

リクエスト失敗時、`.wip` サフィックス付きのディレクトリが残る:

```
./paging/
  0001/           # 成功
  0002.wip/       # 失敗（デバッグ用）
    req.header    # リクエスト情報は残る
    res.header    # 空またはエラー内容
    res.body      # 空またはエラー内容
```

---

## 5. ページング動作

### 5.1 対応するページング型

現時点では `page/total_pages` 型のみ対応:

```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "total_pages": 5
  }
}
```

### 5.2 処理フロー

1. 1ページ目を取得
2. `pagination.total_pages` を読み取り
3. 2ページ目以降を順次取得
4. 各ページの `data` を連結
5. 集約結果を出力

### 5.3 終了条件

- 最終ページまで取得完了 → 成功（exit 0）
- エラー発生 → 失敗（exit 1）

---

## 6. 安全機能

### 6.1 limit_pages（ハードリミット）

総ページ数が `--cp-limit-pages`（デフォルト: 100）を超える場合、エラー終了。

```
Error: total_pages (150) exceeds limit_pages (100)
```

### 6.2 max_pages（ソフトリミット）

`--cp-max-pages` 指定時、その数で正常打ち切り（exit 0）。

```
Note: Limiting to 10 pages (total: 50)
```

### 6.3 無限ループ防止

以下の重複を検出した場合、エラー終了:

1. **page_idの重複**: 同じディレクトリが既に存在
2. **URLの重複**: 同じURLへの再リクエスト
3. **レスポンスpage番号の重複**: APIが同じpage番号を返した

```
Error: Duplicate response page detected (infinite loop prevention): page 1
```

### 6.4 実行前クリーンアップ

ページングモード開始時、生成物ディレクトリを削除してからクリーンに開始。

---

## 7. 終了ステータス

| コード | 意味 |
|--------|------|
| 0 | 成功（全ページ取得完了、またはmax_pagesで打ち切り） |
| 1 | 失敗（エラー発生、集約出力なし） |

---

## 8. 既知の制限

- ページング型は `page/total_pages` のみ（cursor/next_url/Linkヘッダ未対応）
- JSONキーはトップレベルのみ（ネストしたパス未対応）
- リトライ機能なし
- 並列リクエスト未対応

---

## 9. 将来の拡張可能性

- cursor / next_url / Linkヘッダ対応
- ネストしたJSONパス対応
- 生成物の無効化オプション
- リトライ機能
