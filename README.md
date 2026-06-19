<div align="center">

# 🧠 Knowledge Base

### Your private, on-device AI second brain for iOS

**Save anything → AI organizes it → ask your own knowledge anything**

[日本語 README](README.ja.md) • [Features](#-key-features) • [How It Works](#-how-it-works) • [Privacy](#-privacy) • [Architecture](#-architecture) • [Build](#-build--run)

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![AI](https://img.shields.io/badge/AI-Apple%20Foundation%20Models%20(on--device)-black)
![License](https://img.shields.io/badge/license-All%20rights%20reserved-lightgrey)

</div>

Knowledge Base is a **fully on-device, privacy-first knowledge app** for iPhone and iPad. Save an article from anywhere with the Share Sheet, and Apple's on-device Foundation Models automatically extract its essence, key facts, and entities — then weave everything into a living **Wiki of concepts** you can browse, search, and chat with. Nothing leaves your device except the optional sync to *your own* iCloud private database. No accounts, no servers, no tracking.

> [!NOTE]
> Knowledge Base runs Apple Intelligence **entirely on-device**. All summarization, classification, concept synthesis, and chat happen locally — the app never sends your data to the developer or any third party.

---

## ✨ Key Features

| | Capability |
|---|---|
| 📥 **One-tap capture** | Save articles from Safari, Chrome, X, or any app via the Share Sheet. An optional Safari Web Extension can auto-save pages you read. |
| 🧩 **Automatic knowledge extraction** | On-device AI distills each article into an *essence*, *key facts*, and *entities* — no manual tagging. English articles are translated on-device before extraction. |
| 📚 **Living concept Wiki** | Related articles are auto-synthesized into **concept pages** with a 2-level hierarchy (broad theme → specific concept), Markdown bodies, and cross-links — Karpathy's "LLM Wiki" idea, on your phone. |
| 🎯 **Answer-first feed** | The Knowledge feed surfaces each concept's most important points up front ("超・まとめ"), newest & most-active first, with the source article behind every point. |
| 💬 **Conversational AI Chat (RAG)** | Ask questions over *your* saved knowledge. Answers are grounded in your articles with **numbered citations `[1] [2]`** + a sources list. History-aware retrieval; honest "not in your knowledge base" fallback with a badge. |
| 🏷️ **Auto-tagging & categorization** | Every article is auto-tagged and sorted into one of 10 domains. A background "lint" loop continuously merges duplicates, reclassifies, and prunes — resumable and never-ending. |
| 🔄 **iCloud sync (opt-in)** | Sync across your devices through your **private** CloudKit database. Off by default; your data, your iCloud. |
| 🛡️ **Privacy by design** | 100% on-device AI. No data collection, no analytics SDKs, no ads, no tracking. |

---

## 🔍 How It Works

```
   Share an article
          │
          ▼
   ┌──────────────┐   on-device    ┌─────────────────────┐
   │  Raw article │ ─────────────▶ │ Knowledge extraction │  essence · key facts · entities
   │ (immutable)  │  Foundation    └─────────────────────┘
   └──────────────┘   Models                 │
          │                                   ▼
          │                        ┌─────────────────────┐
          └──────── linked ───────▶│  Concept Wiki page   │  AI-synthesized summary + key points
                                   │ (2-level hierarchy)  │  + cross-links + per-point sources
                                   └─────────────────────┘
                                              │
                            ┌─────────────────┼──────────────────┐
                            ▼                 ▼                  ▼
                     Knowledge feed      AI Chat (RAG)      Auto-organize
                    (answer-first)     (cited answers)    (background lint)
```

Everything above runs locally. The only network access is fetching the content of URLs **you** choose to save.

---

## 📱 The App

Three tabs, intentionally simple:

- **ナレッジ (Knowledge)** — the answer-first feed of concept super-summaries, newest first, pin your favorites to the top.
- **ライブラリ (Library)** — every saved article, grouped by date, fully searchable (relevance-ranked).
- **AI チャット (AI Chat)** — a ChatGPT/Gemini-style chat grounded in your own knowledge, with numbered citations.

Settings (via the avatar) cover iCloud sync, Safari/translation setup, tag & category management, and one-tap "organize now."

---

## 🛡️ Privacy

Knowledge Base is built privacy-first and ships with an Apple [Privacy Manifest](KnowledgeTree/PrivacyInfo.xcprivacy):

- **No data collection.** Saved articles, extracted knowledge, chat history, and concept pages live only in on-device SwiftData (and, if you enable sync, *your* iCloud private database).
- **No tracking, no analytics, no ads.**
- **On-device AI.** Summaries, classification, concept synthesis, and chat use Apple Foundation Models locally — never sent to external servers.

See the [Privacy Policy](docs/privacy-policy.md).

---

## 🏗️ Architecture

A single-target SwiftUI app with three app extensions, built on SwiftData + CloudKit. Knowledge is layered: an immutable **raw article** → derived **extracted knowledge** → synthesized **concept Wiki pages**.

```
KnowledgeTree/
├── KnowledgeTreeApp.swift        # App entry, tabs, bootstrap & DI, BGTask registration
├── Models/                       # 22 SwiftData @Models (CloudKit-backed)
│   ├── Article / ArticleBody / ArticleEnrichment / ExtractedKnowledge
│   ├── ConceptPage               # the "Wiki page" (summary, key points, hierarchy, sources)
│   ├── ChatSession / ChatMessage / SavedAnswer
│   ├── Tag / CategoryDefinition / GraphNode / GraphEdge
│   └── LintLog / ConflictProposal / …
├── Services/                     # 78 services (Protocol + DI, testable)
│   ├── KnowledgeExtractionService    # article → essence/facts/entities (chunked, token-safe)
│   ├── ConceptSynthesisService       # articles → concept Wiki pages (hierarchical synthesis)
│   ├── ChatService                   # conversational RAG: retrieve → cite → answer
│   ├── EmbeddingService              # NLEmbedding + Accelerate cosine similarity
│   ├── LintEngine                    # resumable background self-organization loop
│   ├── LanguageModelSessionProtocol  # Foundation Models wrapper + serialization gate
│   └── …
├── Views/                        # 86 SwiftUI views (3 tabs + detail/settings)
├── AppIntents/                   # Shortcuts / "Save to Knowledge Base" intent
├── Localization/                 # Localizable.xcstrings (Japanese-first)
└── Resources/                    # iknow-schema.md (externalized AI rules)

KnowledgeTreeShareExtension/      # Share Sheet capture
KnowledgeTreeSafariExtension/     # Optional auto-save Web Extension
iKnowWidget/                      # Home-screen widget
```

### Token-safety & performance notes
- Apple Foundation Models have a **4096-token window**; `@Generable` output size is the dominant overflow driver. Schemas are kept slim, with **adaptive compact-retry** on overflow.
- All on-device inference is **serialized** through a single gate to avoid Neural Engine contention; background synthesis **yields to active chat** for snappy responses.
- Chat retrieval scores cosine similarity **off the main thread** and caches query embeddings.

---

## 🛠️ Tech Stack

- **Swift 6** · **SwiftUI** · **SwiftData + CloudKit**
- **Apple Foundation Models** (on-device LLM) · **NaturalLanguage** (`NLEmbedding`) · **Accelerate** (`vDSP`)
- **BGTaskScheduler** (background extraction / concept synthesis / weekly organize)
- App Group + Share Extension + Safari Web Extension + Widget
- Spec-driven development via [Spec Kit](.specify/) (`specify → plan → tasks → implement`)

---

## 🚀 Build & Run

**Requirements**
- Xcode 26+
- iOS / iPadOS **26.4+**
- An **Apple Intelligence–capable device** (on-device models; the Simulator falls back to keyword/heuristic paths)

```bash
git clone https://github.com/changch223/KnowledgeTree.git
cd KnowledgeTree
open KnowledgeTree.xcodeproj
# Select the KnowledgeTree scheme → run on an Apple Intelligence device
```

Run tests:

```bash
xcodebuild test -scheme KnowledgeTree \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

> The display name is **Knowledge Base**; the Xcode project/target keeps the historical name `KnowledgeTree` (renaming would break the CloudKit record schema).

---

## 🗺️ Roadmap

Development is spec-driven — see [`specs/ROADMAP.md`](specs/ROADMAP.md) and [`specs/VISION.md`](specs/VISION.md) for the long-term direction (the "LLM Wiki" second-brain model).

**Shipped:** on-device knowledge extraction · concept Wiki with hierarchy & cross-links · conversational RAG chat with numbered citations · auto-tag/category + background self-organization · iCloud sync · English translation pre-processing · per-point source attribution.

---

## ❓ FAQ

**Is my data sent anywhere?**
No. All AI runs on-device. Your data stays on your device and, if you opt in, in your own iCloud private database. The only network access is fetching the pages you choose to save.

**Does it need an API key or subscription?**
No. It uses Apple's on-device Foundation Models — no API keys, no cloud LLM costs.

**Which devices are supported?**
iPhone / iPad on iOS 26.4+ with Apple Intelligence. On unsupported devices the app degrades gracefully (keyword search instead of semantic, etc.).

**How does the AI chat avoid making things up?**
Answers are grounded in your saved articles with numbered citations. When nothing relevant is found, it says so explicitly and labels the reply as general knowledge.

---

## 💬 Support

Questions, bugs, or requests → [GitHub Issues](https://github.com/changch223/KnowledgeTree/issues). See also the [Support page](docs/support.md).

---

## 📄 License

© changch223. **All rights reserved.**

This source is published for transparency. It is **not** licensed for redistribution or reuse. Please open an issue if you'd like to discuss usage.

<div align="center">

Made with ❤️ as a personal project, with the help of Claude (Opus)

</div>
