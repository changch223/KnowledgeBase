//
//  SharedSchema.swift
//  KnowledgeTree
//
//  spec 005 — 共通 SwiftData Schema 定義。
//
//  main app と Share Extension の双方で **同一の** Schema を使うことが必須。
//  Schema が片方のプロセスで Article 単体、もう片方で 6 entity だと
//  SwiftData 内部の persistent store metadata が一致せず、
//  cross-process sync が破壊される (実機で「閉じて再起動するまで反映されない」根本原因)。
//
//  このファイルは両ターゲット (KnowledgeTree + KnowledgeTreeShareExtension) の
//  build phase に追加される必要がある。
//

import Foundation
import SwiftData

enum SharedSchema {
    /// アプリ全体で永続化する @Model 型の完全なリスト。
    /// 新規 @Model を追加するときはここに必ず追記する。
    static var all: Schema {
        Schema([
            Article.self,
            ArticleEnrichment.self,
            ArticleBody.self,
            ExtractedKnowledge.self,
            KeyFact.self,
            KnowledgeEntity.self,
            Tag.self,  // spec 008
            KnowledgeChunkProgress.self,           // spec 009
            BackgroundExtractionQueueEntry.self,   // spec 009
            KnowledgeDigest.self,                  // spec 018
            ChatSession.self,                      // spec 021
            ChatMessage.self,                      // spec 021
            ConflictProposal.self,                 // spec 037
            UserTopic.self,                        // spec 036
            GraphNode.self,                        // spec 040
            GraphEdge.self,                        // spec 040
            ConceptPage.self,                      // spec 042
            SavedAnswer.self,                      // spec 043
            UnderstandingInteraction.self,         // spec 044
        ])
    }

    /// spec 051 Phase A: iCloud sync 有効化フラグの UserDefaults key。
    /// SettingsView の toggle で書き込み、KnowledgeTreeApp launch 時に読んで
    /// `sharedConfiguration(cloudKitEnabled:)` を呼び分ける。
    /// **トグル切替後はアプリ再起動が必要** (ModelContainer は launch 時に 1 度だけ構築)。
    static let iCloudSyncFlagKey = "icloud_sync_enabled"

    /// 現在のユーザー設定 (UserDefaults) を読んで iCloud sync が有効か返す。
    static var isCloudKitEnabledByUser: Bool {
        UserDefaults.standard.bool(forKey: iCloudSyncFlagKey)
    }

    /// App Group container を使った共有 ModelConfiguration。
    /// main app と Share Extension の双方でこの factory を使うことで
    /// schema / groupContainer の指定がブレない。
    ///
    /// spec 051 Phase A: `cloudKitEnabled: true` で CloudKit private DB と App Group を
    /// 同時指定する (実機 spike で iOS 26 動作確認済)。
    static func sharedConfiguration(cloudKitEnabled: Bool = isCloudKitEnabledByUser) -> ModelConfiguration {
        if cloudKitEnabled {
            return ModelConfiguration(
                schema: all,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .private("iCloud.app.KnowledgeTree")
            )
        } else {
            return ModelConfiguration(
                schema: all,
                groupContainer: .identifier(AppGroup.identifier)
            )
        }
    }
}
