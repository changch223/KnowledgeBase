# 01 — Andrej Karpathy が考えていること

## Status: WIP (初稿、2026-05-16)

ソース:
- 動画: AI Native Conference "From Vibe Coding to Agentic Engineering" (29 min)
- gist: [LLM Wiki](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- X 投稿: "LLM Knowledge Bases"
- 副読: Tsurubee 「LLM Wiki を 1 ヶ月運用してみて」(Zenn, 2026-05)

---

## 1. 中核思想:「LLM は新しい計算機 (Software 3.0)」

Karpathy は LLM を **新しいプログラミング・パラダイム** として捉えている。歴史的整理:

| 世代 | プログラミング対象 | プログラマの操作 |
|---|---|---|
| Software 1.0 | 明示的コード | コードを書く |
| Software 2.0 | 学習済み weights | データセットと目的関数を設計、ニューラルネットを訓練 |
| **Software 3.0** | **LLM のコンテキストウィンドウ** | **プロンプトを書く = インタプリタへのレバー** |

> "your programming now turns to prompting and what's in the context window is your lever over the interpreter that is the LLM"

Software 3.0 の象徴的事例として、彼は **menu gen** を出している。レストランのメニュー写真から料理画像を生成するアプリを「自前で OCR + 画像生成 + UI を組む」(Software 1.0/2.0 hybrid) のは間違いで、本来は **「Gemini に写真渡して Nano Banana で重ねろ」** とプロンプトするだけで済む (Software 3.0)。「自分のアプリは存在すべきでなかった」と認めている。

→ **多くの既存アプリは「LLM を後付けした 1.0 アプリ」のままで、3.0 の発想で組み直すと根本的に再設計される**。

## 2.「LLM ナレッジベース」というアイデア

Karpathy は LLM のトークン消費の大部分が、最近は **コード操作よりも知識操作** に向かっていると言う。

> "a large fraction of my recent token throughput is going less into manipulating code, and more into manipulating knowledge (stored as markdown and images)"

これが LLM Wiki の出発点。動画では「LLM Wiki = 組織や個人のための wiki を LLM に作らせる」と紹介し、「これは以前存在し得なかった新しい種類のソフトウェアだ」と強調する:

> "with my LLM knowledge bases project [...] you get LLMs to create wikis for your organization or for you in person etc. This is not even a program. This is not something that could exist before because there was no code that would create a knowledge base based on a bunch of facts."

つまり彼にとって LLM Wiki は **「Software 3.0 で初めて可能になった新カテゴリの典型例」**。

### 既存 RAG への不満

> "the LLM is rediscovering knowledge from scratch on every question. There's no accumulation."

NotebookLM / ChatGPT のファイルアップロード / 一般的 RAG は質問のたびに知識をゼロから再発見する。**蓄積されない**。Karpathy の提案する LLM Wiki は逆に **持続的に成長する compounding artifact** を作る。

> "the wiki is a persistent, compounding artifact. The cross-references are already there. The contradictions have already been flagged."

## 3.「Vibe Coding」 vs「Agentic Engineering」

2024 年に Karpathy は "vibe coding" を造語した。それは LLM にプロンプトを投げて出てきたコードを (内容を吟味せずに) そのまま信用するスタイル。最近 (2025 年末頃) 彼は別の語を強調するようになる:

- **Vibe Coding** = ソフトウェアの「下限」を上げる (誰でも何でも書ける)
- **Agentic Engineering** = プロフェッショナルな品質基準を維持しながら速度を上げる規律

> "vibe coding is about raising the floor for everyone in terms of what they can do in software [...] agentic engineering is about preserving the quality bar of what existed before in professional software."

そして彼は agentic engineer の「天井」は 10× どころではない、と言う。優秀な人間 + 良い tooling + 良い workflow で実現する増幅率は計測しきれないほど大きい。

これは LLM Wiki の運用にも直結する: **wiki を維持する agentic discipline** を確立できる人が知識生産の天井を突破する。

## 4. 「Jagged Intelligence (ギザギザな知能)」と「verifiability」

LLM は均一に賢いわけではない。**特定タスクでは超人的、隣のタスクでは初歩的なミスをする**。Karpathy はこの「ギザギザさ」を analyze している。

例:
- GPT 5 級のモデルが 10 万行のリファクタリングや 0-day 脆弱性発見はできる
- 同じモデルが「50m 先の car wash に車で行くべきか歩くべきか」と聞かれて「歩け」と答える (車を洗いに行くんだから車で行かないと意味がない)

なぜ? 彼の仮説:

> "verifiability plus labs care"

つまり (a) 検証可能なタスクは RL で大量に学習されるから強い、(b) Lab が手を入れた領域は強い。逆に検証不能 or Lab が興味を持たなかった領域は弱い。

LLM Wiki のための示唆: **「正確な要約 + クロスリファレンス維持 + 矛盾検出」は LLM が verifiable に得意な領域**。一方「美的判断 / 重要度の判断 / どこを深掘りするか」は jagged で人間が必要。

## 5. 「Animals vs Ghosts」フレーミング

Karpathy は「我々は動物的知能を作っているのではなく、幽霊を召喚している」と書いた。

- 動物 = 進化で内発的動機・好奇心・遊び・empowerment を持つ
- LLM = データ + 報酬関数だけで形成された統計シミュレーション回路の集合

> "if you yell at them, they're not going to work better or worse [...] it's all just kind of like these statistical simulation circuits"

実用上の含意: LLM を「内発的に賢い助手」と思って働かせると失敗する。**動作の根拠は統計回路と RL 環境にあり、回路にハマれば飛び、外れれば苦戦する**。プロンプターの仕事は「どの回路を起動するか」をコントロールすること。

## 6.「Outsource thinking, but not understanding」

動画の最後で彼が引用したツイート:

> "you can outsource your thinking but you can't outsource your understanding."

そして自分自身がボトルネックである、と認める:

> "I feel like I'm becoming a bottleneck of just even knowing what are we trying to build, why is it worth doing, how do I direct my agents and so on. [...] the LLMs certainly don't excel at understanding, you still are uniquely in charge of that."

彼は LLM ナレッジベースに興奮する理由をこの文脈で語る:

> "this is one reason I also was very excited about all the LLM knowledge bases because I feel like that's a way for me to process information [...] tools to enhance understanding."

→ **LLM Wiki の真の目的は「情報の機械処理」ではなく「人間の理解を増幅する道具」**。

## 7. Memex への接続 (歴史的位置づけ)

gist の末尾で Karpathy は Vannevar Bush の Memex (1945) に触れる:

> "The idea is related in spirit to Vannevar Bush's Memex (1945) — a personal, curated knowledge store with associative trails between documents. [...] The part he couldn't solve was who does the maintenance. The LLM handles that."

Memex は「個人がキュレーションする、ドキュメント間の連想トレイルを持つ知識ストア」のビジョン。Web はこのビジョンの一部だけ実現 (ハイパーリンク = 連想)、しかし「個人キュレーション + 連想の維持」は誰もやらなかった。Bush が解けなかった「誰が維持するのか」を LLM が解く、というのが Karpathy のフレーミング。

## 8. 主要キーフレーズ (引用集)

| 原文 | 訳出 | 含意 |
|---|---|---|
| "wiki is a persistent, compounding artifact" | wiki は持続的に蓄積する成果物 | RAG は瞬間的、wiki は累積的 |
| "the LLM writes; you read" | LLM が書き、人間が読む | 役割分担の逆転 |
| "Obsidian is the IDE; the LLM is the programmer; the wiki is the codebase" | Obsidian が IDE、LLM がプログラマ、wiki がコードベース | 知識生産を「ソフトウェア工学」化 |
| "you can outsource your thinking but you can't outsource your understanding" | 思考は外部化できるが、理解は外部化できない | 人間の不可代替性 |
| "humans abandon wikis because the maintenance burden grows faster than the value" | 人間が wiki を放棄するのは維持負荷が価値より速く増えるから | LLM が解く問題 |
| "the labs care" | Lab が気にする領域 | jaggedness の起源 |
| "what is the piece of text to copy paste to your agent? That's the programming paradigm" | 「エージェントに貼り付けるテキストは何か」がプログラミング・パラダイム | Software 3.0 のエッセンス |

## 9. 未消化な論点 (深掘り候補)

- **動画で言及されている「一つドメインがある」がぼかされた件** (14:55 付近): "there is one domain that I think is very [valuable RL environment]" → 何か具体的に念頭にあるが秘匿。要監視。
- **「Synthetic data + fine-tuning でモデル weights に wiki 知識を焼く」発展** (X 投稿末尾): wiki を context として使うのではなく weights に注入する未来。これが実現すると wiki の役割が変質する。
- **動物 vs 幽霊フレーミングの実用性**: Karpathy 本人が "I'm not sure if it actually has like real power [...] a little bit of philosophizing" と認めている。
