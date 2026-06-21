<div align="center">

# 🧠 Knowledge Base

### Your private, on-device AI second brain for iOS

**Save anything → AI organizes it → ask your own knowledge anything**

[日本語 README](README.ja.md) • [Concept & Philosophy](#-design-concept--philosophy) • [Features](#-key-features) • [How It Works](#-how-it-works) • [Architecture](#-architecture) • [Build](#-build--run)

![Platform](https://img.shields.io/badge/platform-iOS%2026%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![AI](https://img.shields.io/badge/AI-Apple%20Foundation%20Models%20(on--device)-black)
![License](https://img.shields.io/badge/license-All%20rights%20reserved-lightgrey)

</div>

Knowledge Base is a **fully on-device, privacy-first knowledge app** for iPhone and iPad. Save an article — or a PDF, photo, voice memo, or any shared text — and Apple's on-device Foundation Models automatically extract its essence, key facts, and entities, then weave everything into a living **Wiki of concepts** you can browse, search, and chat with. Nothing leaves your device except the optional sync to *your own* iCloud private database. No accounts, no servers, no tracking.

> [!NOTE]
> Knowledge Base runs Apple Intelligence **entirely on-device**. All summarization, classification, translation, concept synthesis, and chat happen locally — the app never sends your data to the developer or any third party.

> **One sentence:** *Read articles, and AI quietly edits them into your own personal encyclopedia in the background — open it and watch your knowledge grow.*

---

## 💡 Design Concept & Philosophy

The full write-up lives in **[`docs/design-concept.md`](docs/design-concept.md)**. The essentials:

### Inspired by Andrej Karpathy's "LLM Wiki"

> *"You can outsource your thinking, but you cannot outsource your understanding."*

You can have an AI summarize for you (outsource the *thinking*), but "actually understanding something" can only happen inside you. So Knowledge Base doesn't just show you AI output — it lets your reading **compound into one growing body of knowledge that is yours**, which you can correct when the AI is wrong. Karpathy's LLM Wiki maps onto the app as three layers:

| Karpathy's layer | In Knowledge Base | Nature |
|---|---|---|
| **Raw sources** | `Article` (saved content + body + photo + audio/PDF/OCR) | **Immutable.** The user saves it; the AI only reads it, never rewrites it. The ground truth for everything. |
| **The wiki** | `ConceptPage` (a Markdown page per person / thing / concept) | AI-generated & updated: summaries, cross-source key points, the big picture, cross-links between pages. **The AI writes all of it; the user writes none of it.** |
| **The schema** | [`docs/iknow-schema.md`](docs/iknow-schema.md) (bundled) | The rulebook that tells the AI *how* to organize. Ingest & lint rules, in one place. |

**Two operations, not three.** Karpathy's wiki runs on *Ingest / Lint / Query*. We deliberately keep only two:

- **Ingest** — Saving an article makes the AI read it, build/update concept pages, and cross-link them. One save ripples into several pages, so knowledge **compounds**.
- **Lint** — A resumable background loop periodically checks the knowledge base's health (stale text, contradictions, orphan pages, classification drift). Runs on launch + weekly; never stops, resumes where it left off.
- **~~Query → page~~** — We *don't* build "ask the wiki and turn the answer into a page." It would add a new ritual to learn. Questions are handled by the existing **AI Chat (RAG)**.

### Why fold everything into a "Wiki"

Mid-development, the data model for "people / things / concepts" split into **7 different types**, and saving one article called the AI **12–15 times** — heavy and overwhelming. The LLM Wiki insight answers this with **subtraction-by-unification**: fold the 7 split concepts into a single `ConceptPage`, collapsing both the *weight* (one generation pipeline) and the *clutter* (one concept type) at once.

### Design principles

1. **Wiki-centric** — people/things/concepts are one type, not seven.
2. **AI manages, humans verify & correct** — the AI organizes everything in the background; you only save. But the AI errs (audio/OCR proper nouns, category calls), so you can **correct, delete, or hide** — the human keeps final authority.
3. **Lightness first** — *don't generate what no one sees*. Target ~2–3 AI calls per save; first screen in ~1s; hard output caps so a runaway never breaks the whole result.
4. **Source-grounded** — every summary, key point, and chat answer traces back to an immutable `Article`. No unsupported claims; references enforced at the data-model layer.
5. **Calm UX** — no unread badges, no anxiety-inducing nudges. A tool that *reduces* information overload.
6. **Privacy-first / local-first** — all data on-device + your private iCloud; all AI on-device.
7. **Japanese-first** — UI and AI output (including Wiki bodies) are Japanese; foreign-language articles are translated to Japanese before extraction.

---

## ✨ Key Features

| | Capability |
|---|---|
| 📥 **Universal capture** | Save from any app via the Share Sheet — **web pages, selected text, files (PDF / txt / Markdown), photos (OCR), and audio (auto-transcribed)** — plus shared PDF attachments (e.g. from Gmail). A synthetic-URL pipeline routes every input through the same flow. An optional Safari Web Extension can auto-save pages you read. |
| 🧩 **Automatic knowledge extraction** | On-device AI distills each item into an *essence*, *key facts*, and *entities* — no manual tagging. Non-Japanese content (English, Chinese, …) is **translated on-device** before extraction. |
| 📚 **Living concept Wiki** | Related articles are auto-synthesized into **concept pages** with a 2-level hierarchy (broad theme → specific concept), Markdown bodies, and cross-links — Karpathy's "LLM Wiki" idea, on your phone. |
| 🎯 **Answer-first feed** | The Knowledge feed surfaces each concept's most important points up front ("超・まとめ"), newest & most-active first, with the source article behind every point. |
| 💬 **Conversational AI Chat (RAG)** | Ask questions over *your* saved knowledge. Answers are grounded in your articles with **numbered citations `[1] [2]`** + a sources list. History-aware query rewriting; honest "not in your knowledge base" fallback with a badge. |
| 🏷️ **Self-improving categorization** | Every article is auto-tagged and sorted into one of 10 domains **with a confidence level**. Low-confidence calls fall back to "Other"; a background lint loop re-visits the uncertain ones first. When **you correct a category, the AI learns from it** (few-shot) and stops repeating the mistake. |
| ✍️ **Review & customize the AI** | Re-review an article's wording against your knowledge base (fix misheard names like *gloadcode → Claude Code*), give natural-language correction instructions, or **customize what the AI generates** (e.g. "emphasize technical detail," "keep summaries short"). |
| 🔄 **iCloud sync (opt-in)** | Sync across your devices through your **private** CloudKit database. Off by default; your data, your iCloud. |
| 🛡️ **Privacy by design** | 100% on-device AI. No data collection, no analytics SDKs, no ads, no tracking. |

---

## 🔍 How It Works

```
   Save anything (URL · text · PDF · photo/OCR · audio)
          │
          ▼
   ┌──────────────┐   on-device    ┌─────────────────────┐
   │  Raw article │ ─────────────▶ │ Knowledge extraction │  essence · key facts · entities
   │ (immutable)  │  Foundation    └─────────────────────┘  (+ on-device translation if foreign)
   └──────────────┘   Models                 │
          │                                   ▼
          │                        ┌─────────────────────┐
          │                        │  Auto tags + domain  │  classify w/ confidence (High/Med/Low)
          │                        └─────────────────────┘
          │                                   │
          │                                   ▼
          │                        ┌─────────────────────┐
          └──────── linked ───────▶│  Concept Wiki page   │  AI-synthesized summary + key points
                                   │ (2-level hierarchy)  │  + cross-links + per-point sources
                                   └─────────────────────┘
                                              │
                            ┌─────────────────┼──────────────────┐
                            ▼                 ▼                  ▼
                     Knowledge feed      AI Chat (RAG)      Self-organize loop
                    (answer-first)     (cited answers)    (lint · learn · heal)
```

Everything above runs locally. The only network access is fetching the content of URLs **you** choose to save (and your optional iCloud sync). Saving completes instantly; the AI work proceeds in the background and is reflected when ready.

---

## 📱 The App

Three tabs, intentionally simple:

- **ナレッジ (Knowledge)** — the answer-first feed of concept super-summaries, newest & most-active first; pin your favorites to the top; a "For You" Wiki shelf and recommended cards.
- **ライブラリ (Library)** — every saved article, grouped by date, fully searchable (relevance-ranked across title / essence / facts / entities / tags).
- **AI チャット (AI Chat)** — a ChatGPT/Gemini-style chat grounded in your own knowledge, with numbered citations, history sidebar, and inline source links.

Settings (via the avatar) cover iCloud sync, Safari/translation setup, **tag & category management**, a **"Review classifications"** screen (shows low-confidence tags + accuracy stats, fix them inline), and one-tap **"organize now."**

---

## 🔁 Self-improving accuracy (the learning loop)

Category classification is the place an on-device model is most likely to drift, so it's built as a loop that gets better with use:

```
① On capture, classify each tag with a confidence [High / Medium / Low]
      Low → conservatively "Other"   ·   Medium / Other → flagged "needs review"
② The lint loop re-visits uncertain tags first (cheap, only when needed)
③ You fix a tag's category in "Review classifications"
      → the correction is stored on-device as a "right answer" example
④ Next classification feeds those examples to the AI as few-shot guidance
      → it stops repeating the same mistake
```

The classifier carries tie-breaker rules for major domains (so it isn't IT-biased), and concept-page generation is **tuned per domain** (health emphasizes symptoms/treatment; sports emphasizes players/results; tech normalizes names). *Human verification becomes the AI's teacher* — the practical embodiment of "don't outsource your understanding."

---

## 🛡️ Privacy

Knowledge Base is built privacy-first and ships with an Apple [Privacy Manifest](KnowledgeTree/PrivacyInfo.xcprivacy):

- **No data collection.** Saved content, extracted knowledge, chat history, and concept pages live only in on-device SwiftData (and, if you enable sync, *your* iCloud private database).
- **No tracking, no analytics, no ads.**
- **On-device AI.** Summaries, classification, translation, concept synthesis, and chat use Apple Foundation Models locally — never sent to external servers.
- **Encryption export compliance** is declared exempt (standard HTTPS only).

See the [Privacy Policy](docs/privacy-policy.md).

---

## 🏗️ Architecture

A single-target SwiftUI app with three app extensions, built on **SwiftData + CloudKit**. Knowledge is layered to mirror the LLM Wiki: an immutable **raw article** → derived **extracted knowledge** → synthesized **concept Wiki pages**.

```
KnowledgeTree/
├── KnowledgeTreeApp.swift        # App entry, 3 tabs, bootstrap & DI, BGTask registration
├── Models/                       # 22 SwiftData @Models (CloudKit-backed, shared schema)
│   ├── Article / ArticleBody / ArticleEnrichment / ExtractedKnowledge (+ KeyFact / KnowledgeEntity)
│   ├── ConceptPage               # the "Wiki page" (summary, key points, hierarchy, links, sources)
│   ├── ChatSession / ChatMessage / SavedAnswer
│   ├── Tag / CategoryDefinition   # tags + dynamic category registry (10 seed domains)
│   ├── GraphNode / GraphEdge / KnowledgeDigest / ConflictProposal / UserTopic  # legacy, retired from generation
│   └── LintLog …                  # + an app-only CategoryCorrectionExample store (local learning)
├── Services/                     # ~90 services (Protocol + DI, unit-tested)
│   ├── KnowledgeExtractionService     # article → essence/facts/entities (chunked, token-safe)
│   ├── KnowledgeExtractor             # prompt building + on-device translation pre-processing
│   ├── ConceptSynthesisService        # articles → concept Wiki pages (hierarchical, per-domain prompts)
│   ├── ChatService                    # conversational RAG: retrieve → cite → answer (history-aware)
│   ├── EmbeddingService               # NLEmbedding + Accelerate cosine similarity (off-main, cached)
│   ├── AutoCategoryClassifier         # category + confidence + few-shot learning
│   ├── LintEngine                     # resumable background self-organization loop
│   ├── TranslationCache               # avoids re-translating the same chunk on re-extraction
│   ├── LanguageModelSessionProtocol   # Foundation Models wrapper + serialization gate + token probe
│   └── …
├── Views/                        # ~90 SwiftUI views (3 tabs + detail / settings / review)
├── AppIntents/                   # Shortcuts / "Save to Knowledge Base" intent
├── Localization/                 # Localizable.xcstrings (Japanese-first)
└── Resources/                    # iknow-schema.md (externalized AI rules)

KnowledgeTreeShareExtension/      # Share Sheet capture (text / URL / PDF / file)
KnowledgeTreeSafariExtension/     # Optional auto-save Web Extension
iKnowWidget/                      # Home-screen widget
```

### The knowledge pipeline (per save)
1. **Intake** — Web/text/file/photo/audio is normalized; non-URL inputs get a synthetic `knowledgebase://…` URL so they ride the same path.
2. **Body** — extract readable text (HTML body extractor, PDFKit, Vision OCR, Speech transcription).
3. **Translate (if needed)** — foreign-language body → Japanese, with a session cache to avoid re-translating on re-extraction.
4. **Extract** — single-shot for short bodies, otherwise **chunked + hierarchical meta-summary** for long ones.
5. **Tag + classify** — auto-tags from entities; each tag classified with confidence + few-shot learning.
6. **Synthesize** — upsert/refresh `ConceptPage`s (broad + specific), link articles, generate Markdown body & cross-links.
7. **Surface** — feed / chat / search read it reactively.

### Token-safety & performance
- Apple Foundation Models have a **4096-token window**; the dominant overflow driver is `@Generable` output reservation. Schemas are kept slim, with **adaptive compact-retry** and **hard `maximumResponseTokens` caps** so a runaway can't break the whole generation.
- All on-device inference is **serialized through a single gate** to avoid Neural Engine contention; background synthesis **yields to active chat** for snappy replies.
- Chat retrieval scores cosine similarity **off the main thread** and caches query embeddings; full-corpus scan preserves recall.
- The lint loop is **resumable & batched** (progress tracked per tag) so it survives app restarts and never blocks the UI.

---

## 🛠️ Tech Stack

- **Swift 6** · **SwiftUI** · **SwiftData + CloudKit** (App Group shared store)
- **Apple Foundation Models** (on-device LLM, `@Generable` structured output) · **NaturalLanguage** (`NLEmbedding`, language detection) · **Translation** framework · **Speech** (on-device transcription) · **Vision** (OCR) · **PDFKit** · **Accelerate** (`vDSP`)
- **BGTaskScheduler** (background extraction / concept synthesis / weekly organize)
- Share Extension · Safari Web Extension · App Intents / Shortcuts · Widget
- Spec-driven development via [Spec Kit](.specify/) (`specify → plan → tasks → implement`)

---

## 🧭 How this project is built — spec-driven development

Every feature is a numbered **spec** (`specs/NNN-name/`) carried through a disciplined pipeline:

```
/specify   → spec.md          (what & why, user stories, acceptance criteria)
/plan      → plan.md          (design, data-model, contracts, constitution check)
/tasks     → tasks.md         (dependency-ordered, testable tasks)
/implement → code + unit tests (build green, tests pass, @Model migrations CloudKit-safe)
```

A project **constitution** (`.specify/memory/constitution.md`) encodes 7 core principles (privacy-first, source-grounded generation, calm UX, maintainable SwiftUI, Japanese-first, …) that every plan is checked against. The long-term direction — the "LLM Wiki" second-brain model — is in [`VISION.md`](VISION.md). 80+ specs have shipped this way.

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

Development is spec-driven — see [`VISION.md`](VISION.md), [`docs/design-concept.md`](docs/design-concept.md), and the `specs/` directory for the long-term "LLM Wiki" second-brain direction.

**Shipped:** universal capture (URL/text/PDF/photo-OCR/audio) · on-device knowledge extraction + translation · concept Wiki with hierarchy, cross-links & per-point sources · conversational RAG chat with numbered citations · self-improving auto-tag/category with confidence + few-shot learning · per-domain concept synthesis · background self-organization (lint) · review & customize the AI · iCloud sync.

**Exploring:** cross-device sync of the learning store · deeper concept relationship discovery · periodic "this week" digests.

---

## ❓ FAQ

**Is my data sent anywhere?**
No. All AI runs on-device. Your data stays on your device and, if you opt in, in your own iCloud private database. The only network access is fetching the pages you choose to save.

**Does it need an API key or subscription?**
No. It uses Apple's on-device Foundation Models — no API keys, no cloud LLM costs.

**Which devices are supported?**
iPhone / iPad on iOS 26.4+ with Apple Intelligence. On unsupported devices the app degrades gracefully (keyword search instead of semantic, AI features disabled, save/browse/search still work).

**How does the AI chat avoid making things up?**
Answers are grounded in your saved articles with numbered citations. When nothing relevant is found, it says so explicitly and labels the reply as general knowledge.

**The AI mis-categorized something — can I fix it?**
Yes. Open *Settings → Review classifications* (or long-press a tag in tag management) and pick the right domain. The correction is stored locally and used to teach the classifier going forward.

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
