//
//  ThumbnailView.swift
//  KnowledgeTree
//
//  spec 002 — OG image サムネイル表示
//

import SwiftUI

struct ThumbnailView: View {
    let urlString: String?

    private var url: URL? {
        guard let s = urlString, let u = URL(string: s), u.scheme == "https" else { return nil }
        return u
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("articleListThumbnail")
            } else {
                EmptyView()
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.2))
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        ThumbnailView(urlString: "https://example.com/og.jpg")
        ThumbnailView(urlString: nil)
    }
    .padding()
}
