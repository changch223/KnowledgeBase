//
//  RefreshTrigger.swift
//  KnowledgeTree
//
//  spec 005 — SwiftData の @Query は relationship target のプロパティ変更を観察しない。
//  Store が save() を成功させるたびに version を bump し、ビュー側で読むことで
//  Observation 経由の確実な再描画を起こす。
//
//  ProcessingMonitor は phase 切り替え時しか変化しないため、
//  保存完了までの末端反映には不十分 → このトリガが補完する。
//

import Foundation
import Observation

@MainActor
@Observable
final class RefreshTrigger {
    private(set) var version: UUID = UUID()

    func bump() {
        version = UUID()
    }
}
