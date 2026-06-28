//
//  ColorAdaptiveTests.swift
//  KnowledgeTreeTests
//
//  spec 017 — Color.adaptive(light:dark:) 純関数 7 ケース。
//  UITraitCollection で Light/Dark trait 注入、UIColor.cgColor.components で RGB 比較。
//

import Testing
import SwiftUI
import UIKit
@testable import KnowledgeBase

struct ColorAdaptiveTests {

    /// epsilon 0.01 の許容誤差で 2 つの CGFloat を比較
    private func approx(_ a: CGFloat, _ b: CGFloat, eps: CGFloat = 0.01) -> Bool {
        abs(a - b) < eps
    }

    /// UIColor → RGB tuple (alpha 1.0 前提)
    private func rgb(_ uiColor: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    /// SwiftUI Color を Light/Dark trait で resolve した UIColor を返す
    private func resolved(_ color: Color, style: UIUserInterfaceStyle) -> UIColor {
        let uiColor = UIColor(color)
        return uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    /// 1: Light で light が返る
    @Test func testReturnsLightColorInLightMode() {
        let light = Color(red: 0.1, green: 0.2, blue: 0.3)
        let dark = Color(red: 0.7, green: 0.8, blue: 0.9)
        let adaptive = Color.adaptive(light: light, dark: dark)

        let resolvedLight = resolved(adaptive, style: .light)
        let (r, g, b) = rgb(resolvedLight)

        #expect(approx(r, 0.1))
        #expect(approx(g, 0.2))
        #expect(approx(b, 0.3))
    }

    /// 2: Dark で dark が返る
    @Test func testReturnsDarkColorInDarkMode() {
        let light = Color(red: 0.1, green: 0.2, blue: 0.3)
        let dark = Color(red: 0.7, green: 0.8, blue: 0.9)
        let adaptive = Color.adaptive(light: light, dark: dark)

        let resolvedDark = resolved(adaptive, style: .dark)
        let (r, g, b) = rgb(resolvedDark)

        #expect(approx(r, 0.7))
        #expect(approx(g, 0.8))
        #expect(approx(b, 0.9))
    }

    /// 3: actionBlue Light = #0a4d8c (10/255, 77/255, 140/255)
    @Test func testActionBlueLightHex() {
        let resolvedLight = resolved(DS.Color.actionBlue, style: .light)
        let (r, g, b) = rgb(resolvedLight)

        #expect(approx(r, 10.0 / 255.0))
        #expect(approx(g, 77.0 / 255.0))
        #expect(approx(b, 140.0 / 255.0))
    }

    /// 4: actionBlue Dark = #3a8eef (58/255, 142/255, 239/255)
    @Test func testActionBlueDarkHex() {
        let resolvedDark = resolved(DS.Color.actionBlue, style: .dark)
        let (r, g, b) = rgb(resolvedDark)

        #expect(approx(r, 58.0 / 255.0))
        #expect(approx(g, 142.0 / 255.0))
        #expect(approx(b, 239.0 / 255.0))
    }

    /// 5: parchment Light = #faf8f3 (250/255, 248/255, 243/255)
    @Test func testParchmentLightHex() {
        let resolvedLight = resolved(DS.Color.parchment, style: .light)
        let (r, g, b) = rgb(resolvedLight)

        #expect(approx(r, 250.0 / 255.0))
        #expect(approx(g, 248.0 / 255.0))
        #expect(approx(b, 243.0 / 255.0))
    }

    /// 6: parchment Dark = #1c1c1e (28/255, 28/255, 30/255)
    @Test func testParchmentDarkHex() {
        let resolvedDark = resolved(DS.Color.parchment, style: .dark)
        let (r, g, b) = rgb(resolvedDark)

        #expect(approx(r, 28.0 / 255.0))
        #expect(approx(g, 28.0 / 255.0))
        #expect(approx(b, 30.0 / 255.0))
    }

    /// 7: tagFill Light = #eaeaef (234/255, 234/255, 239/255) / Dark = #2c2c2e (44/255, 44/255, 46/255)
    @Test func testTagFillBothModes() {
        let resolvedLight = resolved(DS.Color.tagFill, style: .light)
        let (rL, gL, bL) = rgb(resolvedLight)
        #expect(approx(rL, 234.0 / 255.0))
        #expect(approx(gL, 234.0 / 255.0))
        #expect(approx(bL, 239.0 / 255.0))

        let resolvedDark = resolved(DS.Color.tagFill, style: .dark)
        let (rD, gD, bD) = rgb(resolvedDark)
        #expect(approx(rD,  44.0 / 255.0))
        #expect(approx(gD,  44.0 / 255.0))
        #expect(approx(bD,  46.0 / 255.0))
    }
}
