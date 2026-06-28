//
//  AvatarMenu.swift
//  KnowledgeTree
//
//  spec 056 — 知識 Clip タブ右上に配置するアバター/プロフィール icon。
//  tap で SettingsView を sheet 表示 (NavigationStack 内)。Apple News パターン。
//  Settings root tab 削除に伴う新動線。
//

import SwiftUI

struct AvatarMenu: View {
    @State private var showSettings = false

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.title2)
                .foregroundStyle(.primary)
        }
        .accessibilityIdentifier("toolbar.avatar")
        .accessibilityLabel(Text("avatar.menu.accessibility"))
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
