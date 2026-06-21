//
//  CategoryCorrectionExample.swift
//  KnowledgeTree
//
//  spec 097 Phase 2 — ユーザーがカテゴリ分類を修正した「正解例」。
//  分類プロンプトに少数 few-shot として注入し、同じ間違いを繰り返さないようにする (学習ループ)。
//
//  ※ アプリ専用の別 ModelContainer に保存する (拡張は触らないため SharedSchema には入れない
//     = 拡張ターゲットの pbxproj 編集が不要)。CloudKit private DB で端末間同期。
//  全フィールド default 付き・relationship なし = CloudKit 安全。
//

import Foundation
import SwiftData

@Model
final class CategoryCorrectionExample {
    var id: UUID = UUID()
    /// 修正対象のタグ名 (正規化前の表示名でよい)。
    var tagName: String = ""
    /// タグが登場した文脈の抜粋 (記事タイトル/essence、最大 ~120字)。few-shot の手がかり。
    var contextSnippet: String = ""
    /// AI が誤って付けたカテゴリ (任意。誤り→正解の対比で学習効果が上がる)。
    var wrongCategory: String?
    /// ユーザーが指定した正しいカテゴリ。
    var correctCategory: String = ""
    var createdAt: Date = Date.now

    init(
        tagName: String,
        contextSnippet: String = "",
        wrongCategory: String? = nil,
        correctCategory: String,
        createdAt: Date = .now
    ) {
        self.tagName = tagName
        self.contextSnippet = contextSnippet
        self.wrongCategory = wrongCategory
        self.correctCategory = correctCategory
        self.createdAt = createdAt
    }
}
