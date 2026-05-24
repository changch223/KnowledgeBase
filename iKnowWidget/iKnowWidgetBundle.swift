//
//  iKnowWidgetBundle.swift
//  iKnowWidget
//
//  spec 052 — Widget bundle entry。
//  MVP では LearningCardsWidget (iKnowWidget) のみ公開。
//  Control / Live Activity は spec 053 以降で別途 spec 化、本 bundle では含めない。
//

import WidgetKit
import SwiftUI

@main
struct iKnowWidgetBundle: WidgetBundle {
    var body: some Widget {
        iKnowWidget()
    }
}
