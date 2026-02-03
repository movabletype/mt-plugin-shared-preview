# SharedPreview プラグイン for Movable Type

記事、ページ、コンテンツデータのプレビューを共有できるようにします。

## ダウンロード

[releases](https://github.com/movabletype/mt-plugin-shared-preview/releases)からダウンロードしてください。

## インストール

* ダウンロードした zip ファイルを展開します。
* 展開したフォルダの中の plugins > SharedPreview のフォルダを、サーバー上の plugins フォルダの中にアップロードします。
* 次に mt-static > plugins > SharedPreview のフォルダを、サーバー上の mt-static > plugins のフォルダの中にアップロードします。
* 最後に mt-shared-preview.cgi のファイルをアップロードします。
※ Movable Type クラウド版も含む PSGI 動作の場合は mt-shared-preview.cgi のアップロードは必要ありません。

## 動作確認環境

* Movable Type 7 r.4601 以降

## 制限事項

* PHP ファイルのプレビューはできません。
* クラウド版では環境変数 `SharedPreviewScript` の変更はできません。

## 更新履歴

### version 0.5
* Bootstrap 5 対応を行いました。

### version 0.4
* プラグイン設定画面で、他のプラグインのスクリプトが本プラグインに悪影響しないようidにプラグイン名を前置しました。

### version 0.3
* [MTC-28655] Movable Type本体に同梱されていたsvg4everybodyが、将来廃止の予定となったため、プラグインではsvg4everybodyを利用しないように変更しました。

### version 0.2
* Movable Type 7 r.4603で共有プレビュープラグインを利用する際に一部表示の不具合があり、修正致しました。

## フィードバック

本プラグインは Movable Type 製品サポートの対象外となります。 不具合・ご要望は GitHub リポジトリの Issues の方までご連絡ください。

https://github.com/movabletype/mt-plugin-shared-preview/issues

## ライセンス

MIT License

Copyright (c) 2019 Six Apart Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

