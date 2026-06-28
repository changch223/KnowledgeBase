//
//  URLSessionProtocol.swift
//  KnowledgeTree
//
//  spec 002 — research.md R7
//

import Foundation

protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
