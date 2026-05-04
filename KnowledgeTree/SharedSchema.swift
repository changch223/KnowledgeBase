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
        ])
    }

    /// App Group container を使った共有 ModelConfiguration。
    /// main app と Share Extension の双方でこの factory を使うことで
    /// schema / groupContainer の指定がブレない。
    static func sharedConfiguration() -> ModelConfiguration {
        ModelConfiguration(
            schema: all,
            groupContainer: .identifier(AppGroup.identifier)
        )
    }
}
