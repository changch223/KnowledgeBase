# Privacy Policy — まとメモ（Knowledge Base）

_Last updated: 2026-11-26_

まとメモ, also listed as Knowledge Base outside Japan ("the App"), is a personal knowledge app that saves articles you choose and organizes them on your device using on-device AI. This policy explains how the App handles your information.

## 日本語

### データの収集について
- 本アプリは、**あなたのデータを開発者に送信・収集しません**。
- 保存した記事・抽出した知識・AI への質問履歴・トピックは、すべて**お使いの端末内 (SwiftData) に保存**されます。
- iCloud 同期を ON にした場合のみ、データは**あなた自身の iCloud プライベートデータベース**に同期されます。これは Apple の iCloud によって暗号化され、開発者はアクセスできません。

### 第三者への提供・トラッキング
- 第三者へのデータ提供・販売は**一切行いません**。
- 広告・解析 SDK・トラッキングは**使用していません**。

### 通信について
- あなたが保存しようとした記事の URL に対してのみ、本文・メタデータ取得のための通信を行います (あなたの操作で開始)。
- AI による要約・分類・質問への回答は、Apple のオンデバイス基盤モデル (Foundation Models) を用いて**端末内で処理**され、外部サーバーには送信されません。
- 翻訳 (Apple の Translation)・音声の文字起こし (Speech)・写真の文字認識 (Vision) も**端末内で処理**されます。取り込んだ写真・PDF・音声は、文字を取り出すためだけに使い、外部には送信しません。

### データの削除
- アプリ内から記事・質問履歴・トピックを個別/一括で削除できます。
- アプリを削除すると端末内データは消去されます。iCloud 同期データは iOS の iCloud 設定から削除できます。

### お問い合わせ
ご質問・ご要望は GitHub Issues よりご連絡ください:
https://github.com/changch223/KnowledgeBase/issues

## English

### Data Collection
- The App **does not collect or transmit your data to the developer**.
- Saved articles, extracted knowledge, question history, and topics are stored **on your device** (SwiftData).
- If you enable iCloud sync, data syncs only to **your own private iCloud database**, encrypted by Apple and inaccessible to the developer.

### Third Parties & Tracking
- No data is sold or shared with third parties.
- No advertising, analytics SDKs, or tracking are used.

### Networking
- The App fetches content/metadata only for URLs you choose to save (initiated by your action).
- AI summarization, classification, and answers run **on-device** via Apple's Foundation Models; nothing is sent to external servers.
- Translation (Apple Translation), audio transcription (Speech), and text recognition in photos (Vision) also run **on-device**. Photos, PDFs, and audio you import are used only to extract their text and are never sent anywhere.

### Data Deletion
- You can delete articles, question history, and topics individually or in bulk within the App.
- Deleting the App removes on-device data; iCloud-synced data can be removed via iOS iCloud settings.

### Contact
Please reach us via GitHub Issues:
https://github.com/changch223/KnowledgeBase/issues
