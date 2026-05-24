# Feature Specification: Sign In with Apple (将来連携用、optional)

**Feature Branch**: `053-sign-in-with-apple`
**Created**: 2026-05-24
**Status**: Draft (v2.0 検討、優先度低)
**Risk**: 🟢 LOW (独立機能、CloudKit sync には不要)

## 重要 clarification

**Sign In with Apple は iCloud sync には不要**。

- SwiftData CloudKit private DB は **iOS の iCloud アカウント** (OS レベル) を自動利用
- Sign In with Apple は **app-level identity** (OAuth)、バックエンドサーバーがある場合のみ意味あり
- iKnow は完全 on-device + CloudKit (sync のみ) なのでバックエンドゼロ
- 結論: 本 spec は **「将来バックエンドが必要になった時のため」の preparation** に過ぎず、V2.0 release では **実装しない判断もアリ**

## なぜ (本 spec を作る場合)

- v3.0+ で iKnow Pro (有料 plan) / community 機能 / 共有 ConceptPage / Shared zone CloudKit が必要になった時、Apple Sign In はバックエンドユーザー識別子として最適
- Apple Store の hint: Apple Sign In を実装すると Apple がプロモーションしやすい
- ユーザー要望 Q1 で「iCloud sync 希望時に Apple Sign In opt-in」と言及 → 実装するなら本 spec で

## ゴール

- Settings に「Sign In with Apple」エントリ追加 (optional opt-in)
- Sign-in 完了で `Apple ID` (anonymized) と email (optional) を local 保存
- 現時点では sign-in 状態は **何も影響しない** (将来 backend 連携用の identity 確保のみ)
- Sign-out 可能

## 非ゴール

- バックエンドサーバー実装 (v3.0+)
- 共有 ConceptPage / community (v3.0+)
- iCloud sync と紐付け (本来別物、誤解防止のため明記)
- Sign in 必須化 (永久 opt-in only)

## ユーザストーリー

### US1 (P3) — Settings で Sign in with Apple

1. Settings → 「Sign in with Apple」エントリ
2. tap で `ASAuthorizationAppleIDButton` 表示
3. Face ID / Touch ID で sign-in 完了
4. 完了後 「Apple ID: ****@***」表示 + Sign out Button

### US2 (P3) — Sign out

1. Settings の sign-in entry の右側に Sign out Button
2. tap で 確認 alert → Sign out → 局所 keychain クリア

## 機能要件

- **FR-001**: Settings に Sign in with Apple entry
- **FR-002**: `AuthenticationServices.framework` で `ASAuthorizationAppleIDProvider` 利用
- **FR-003**: 成功時 Apple ID + email (もし shared) を Keychain に保存
- **FR-004**: 失敗 / cancel は silent (banner 等なし)
- **FR-005**: Sign-in 状態は **本 release では何も触らない** (V2.0 では何も影響しない、将来用)
- **FR-006**: Sign out で Keychain クリア
- **FR-007**: Privacy: 取得した email は端末内のみ、外部送信ゼロ (本 release では送信先がない)

## 成功基準

- SC-001: Settings tap で Apple Sign in button 表示
- SC-002: Sign-in 成功で Settings entry に Apple ID 表示
- SC-003: Sign out で entry 状態 reset
- SC-004: 既存機能 (記事保存 / 学習 / chat) は sign-in 状態に **一切依存しない**

## 規模

- 新規 1 file (`AppleSignInSection.swift`、~100 行)
- Settings 改修 (~10 行)
- Keychain helper (Apple ID 保存用、~80 行)
- xcstrings ~5 文言
- 合計 **~200 行**、tasks 6-8、期間 **3 日**

## 💡 推奨判断

**V2.0 では本 spec を実装しない** ことを推奨。理由:
- iCloud sync (spec 051) は Apple Sign In 不要
- バックエンドサーバーなしで sign-in しても **意味ある機能ゼロ** (将来用 placeholder のみ)
- ユーザーが「sign-in したのに何も起きない」と困惑するリスク
- V3.0 で 有料 / community / shared 機能を導入する時に同時に実装するのが自然

V2.0 release では **本 spec をスキップ** し、spec 051 (CloudKit sync) + spec 052 (Widget) のみで構成することを強く推奨。

## 依存

- 単独、CloudKit sync (spec 051) との依存なし
- v3.0+ のバックエンド計画があれば再検討
