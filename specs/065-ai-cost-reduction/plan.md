# Implementation Plan: AI 処理削減 (軽さ優先)

**Branch**: `064-wiki-links-discovery` (継続) | **Date**: 2026-05-31 | **Spec**: [spec.md](./spec.md)

## Summary

記事保存・起動の AI 呼び出しを削減。**矛盾検出を 1 回に削減** (ConflictDetectionService 定数 2×5→1×1) + **graph 抽出 hook 停止** (bootstrap で DI nil) + **起動 backfill から digest 再生成 / UserTopic clustering を除外**。@Model 削除ゼロ (生成停止のみ、退役は spec 066) = CloudKit 安全。手段は最小 (定数 2 + bootstrap 2 ブロック)、ロールバック容易。

## Technical Context
- Swift 6 / SwiftUI / SwiftData + CloudKit、@Model 変更なし
- 改修 2 ファイル: ConflictDetectionService.swift / KnowledgeTreeApp.swift
- Testing: 既存 regression のみ (新ロジックなし、停止 = 既存 nil 経路と同一)

## Constitution Check
- I privacy ✅ / II 引き算 (まさに不要処理の削除) ✅ / III source 不変 ✅ / IV iOS ✅ / V calm (軽さ) ✅ / VI @Model 不変・DI nil ✅ / VII 日本語 ✅

## 設計 (Plan エージェント診断ベース)
- **FR-001 矛盾 1 回**: `ConflictDetectionService` の `topEntityCount 2→1` / `comparisonLimit 5→1` (最大 10→1 回)
- **FR-002 graph 停止**: `KnowledgeTreeApp` の `DefaultKnowledgeExtractionService(... graphExtractionService: nil)` (hook は `guard let` で no-op、既存 GraphNode は残る)
- **FR-003/004 起動軽量化**: `runStartupBackfills()` の `async let digestRegeneration` / `topicClustering` を削除 + await tuple から除外
- **FR-005 オンデマンド維持**: CategoryKnowledgeDetailView / pull-to-refresh の digest 生成は無改修
- **依存安全性**: ChatService RAG (`resolveRelatedEntities`) / KnowledgeDigestService は graphTraversal を optional で受け既存ノードで動作 → graph 停止で痩せるが crash なし

## 検証
- clean build + 全 unit test serial regression (ConflictDetectionServiceTests は service 単体テストで定数に非依存 → PASS、GraphExtractionServiceTests も service 残すので PASS)
- 実機検証 (ログで AI 回数減 / 起動軽量 / digest オンデマンド) はユーザー

## Out of Scope
@Model 退役 (spec 066) / カテゴリ分類削減 / News+ フィード / KnowledgeExtractor token (spec 062)
