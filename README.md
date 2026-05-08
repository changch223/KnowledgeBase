# 知積 (KnowledgeTree)

> **読んだ知識を AI が自動で体系化・更新し、必要な時だけ開けば最新の自分が見える、優しい第二の脳。**

iOS / iPadOS 26+、Apple Intelligence (on-device) を活用した、完全ローカルファーストな知識管理アプリ。

---

## 📚 ドキュメント

| ドキュメント | 内容 |
|---|---|
| [マーケティング (機能紹介)](docs/marketing.md) | プロダクト全体の機能と魅力 |
| [サポート (FAQ)](docs/support.md) | よくある質問 / 既知の問題 / 連絡先 |
| [App Store 申請テキスト](docs/app-store-listing.md) | 申請用 4 文言 |
| [プロダクトビジョン](specs/VISION.md) | 設計原則と長期方針 |
| [ロードマップ](specs/ROADMAP.md) | 開発履歴と将来計画 |

## ✨ 主要機能

- 📜 **「最近のあなた」差分ダイジェスト** — 前回開いた時から今までの保存記事を AI 3 段落で統合
- 🔍 **動的トピック自動発見** — 「AI と Product Management」のような興味分野を AI が発見
- ⚠️ **時系列事実の更新** — 「店オープン → 店閉店」のような矛盾を AI が検出して提案
- 💬 **AI チャット (RAG)** — 自分の保存記事に対話できる、引用付き回答

## 🛡️ プライバシー

完全ローカルファースト。AI 処理は Apple Intelligence (on-device)、外部送信ゼロ。広告 SDK / アナリティクス / クラウド同期 は一切なし。

## 🛠️ 開発

- Swift 6 / SwiftUI 6 / SwiftData / Foundation Models / NaturalLanguage / Accelerate
- iOS 26+ / iPadOS 26+
- 開発手法: [Spec Kit](.specify/) (specify → plan → tasks → implement)

## 📞 連絡

- 不具合報告 / 機能要望: [GitHub Issues](https://github.com/changch223/KnowledgeTree/issues)

---

開発: changch223 (個人開発)
