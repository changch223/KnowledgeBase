//
//  ShareReceivedItem.swift
//  KnowledgeTreeShareExtension
//
//  spec 001 / contracts/share-received-item.md
//

import Foundation

struct ShareReceivedItem: Equatable, Sendable {
    let url: URL?
    let suppliedTitle: String?
}
