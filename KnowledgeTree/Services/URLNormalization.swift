//
//  URLNormalization.swift
//  KnowledgeTree
//
//  spec 007 — URL の同一性判定用に正規化された文字列を生成する純粋関数 extension。
//  pagination 追跡で訪問済 URL set のキー、自己ループ検出に使う。
//
//  正規化:
//   - scheme を lowercased
//   - host を lowercased + 先頭 "www." を削除
//   - fragment (#...) を削除
//   - query string から tracking params (utm_*, fbclid, gclid 等) を削除
//   - path の末尾 "/" を削除 (但し path == "/" は維持)
//

import Foundation

extension URL {
    /// 正規化された URL 文字列を返す。同一コンテンツを示す URL バリエーションを同一視するため。
    /// 失敗時は absoluteString をそのまま返す (best effort)。
    func normalized() -> String {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self.absoluteString
        }

        // scheme: lowercase
        components.scheme = components.scheme?.lowercased()

        // host: lowercase + www. 削除
        if var host = components.host?.lowercased() {
            if host.hasPrefix("www.") {
                host = String(host.dropFirst(4))
            }
            components.host = host
        }

        // fragment 削除
        components.fragment = nil

        // tracking params 削除
        if let items = components.queryItems {
            let filtered = items.filter { item in
                !Self.trackingParamPrefixes.contains(where: { item.name.hasPrefix($0) }) &&
                !Self.trackingParamExactNames.contains(item.name)
            }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        // path: trailing slash 削除 (但し "/" 単体は維持)
        if components.path.count > 1, components.path.hasSuffix("/") {
            components.path = String(components.path.dropLast())
        }

        return components.string ?? self.absoluteString
    }

    /// 削除対象 tracking params の prefix (utm_source, utm_medium 等を一括カバー)
    private static let trackingParamPrefixes: Set<String> = [
        "utm_"
    ]

    /// 削除対象 tracking params の正確な名前
    private static let trackingParamExactNames: Set<String> = [
        "fbclid",
        "gclid",
        "yclid",
        "msclkid",
        "_ga"
    ]

    /// 同一ホスト判定 (www. 違いは同一視)
    static func sameHost(_ a: URL, _ b: URL) -> Bool {
        let normalize: (String?) -> String? = { host in
            guard var h = host?.lowercased() else { return nil }
            if h.hasPrefix("www.") {
                h = String(h.dropFirst(4))
            }
            return h
        }
        return normalize(a.host) == normalize(b.host)
    }
}
