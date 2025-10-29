//
//  Color+Tokens.swift
//  Sparkify
//
//  Created by Willow Zhang on 2025/10/12.
//

import SwiftUI

// MARK: - Theme Preference

enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .system:
            String(localized: "theme_follow_system", defaultValue: "跟随系统")
        case .light:
            String(localized: "theme_light", defaultValue: "浅色")
        case .dark:
            String(localized: "theme_dark", defaultValue: "深色")
        }
    }

    var forcedColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// MARK: - Palette

struct AppPalette {
    let background: Color
    let surfacePrimary: Color
    let surfaceSecondary: Color
    let outline: Color
    let textPrimary: Color
    let textSecondary: Color
    let textInverted: Color
    let neutralHigh: Color
    let neutralLow: Color
    let shadowStrong: Color
    let shadowSoft: Color
    let accent: Color
    let accentEmphasis: Color
    let accentForeground: Color

    static let light = AppPalette(
        background: Color(white: 0.97),
        surfacePrimary: Color.white,
        surfaceSecondary: Color(red: 0.93, green: 0.94, blue: 0.96),
        outline: Color(red: 0, green: 0, blue: 0, opacity: 0.08),
        textPrimary: Color(red: 0.14, green: 0.15, blue: 0.16),
        textSecondary: Color(red: 0.38, green: 0.39, blue: 0.41),
        textInverted: Color(white: 0.98),
        neutralHigh: Color(red: 0.09, green: 0.1, blue: 0.11),
        neutralLow: Color(white: 1.0),
        shadowStrong: Color(red: 0, green: 0, blue: 0, opacity: 0.25),
        shadowSoft: Color(red: 0, green: 0, blue: 0, opacity: 0.12),
        accent: Color(red: 0.92, green: 1.0, blue: 0.0),
        accentEmphasis: Color(red: 0.87, green: 0.95, blue: 0.0),
        accentForeground: Color(red: 0.09, green: 0.1, blue: 0.11)
    )

    static let dark = AppPalette(
        background: Color(red: 0.08, green: 0.08, blue: 0.09),
        surfacePrimary: Color(red: 0.10, green: 0.11, blue: 0.11),
        surfaceSecondary: Color(red: 0.14, green: 0.15, blue: 0.16),
        outline: Color(red: 1, green: 1, blue: 1, opacity: 0.10),
        textPrimary: Color(red: 0.83, green: 0.85, blue: 0.87),
        textSecondary: Color(red: 0.61, green: 0.64, blue: 0.67),
        textInverted: Color(white: 0.98),
        
        neutralHigh: Color(red: 0.22, green: 0.35, blue: 0.25),
        neutralLow: Color(red: 0.11, green: 0.12, blue: 0.13),
        shadowStrong: Color(red: 0, green: 0, blue: 0, opacity: 0.65),
        shadowSoft: Color(red: 0, green: 0, blue: 0, opacity: 0.35),
        accent: Color(red: 0.82, green: 0.95, blue: 0.0),
        accentEmphasis: Color(red: 0.89, green: 0.97, blue: 0.12),
        accentForeground: Color(red: 0.1, green: 0.1, blue: 0.11)
    )
}

enum AppColors {
    static let neonYellow = Color(red: 0.92, green: 1.0, blue: 0.0)

    static func palette(for colorScheme: ColorScheme) -> AppPalette {
        colorScheme == .dark ? .dark : .light
    }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette.light
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

extension View {
    func applyAppPalette(_ preference: ThemePreference) -> some View {
        modifier(AppPaletteModifier(preference: preference))
    }
}

private struct AppPaletteModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let preference: ThemePreference

    private var resolvedColorScheme: ColorScheme {
        preference.forcedColorScheme ?? colorScheme
    }

    func body(content: Content) -> some View {
        let palette = AppColors.palette(for: resolvedColorScheme)
        ThemeColorProvider.shared.updatePalette(palette)
        return content.environment(\.appPalette, palette)
    }
}

// MARK: - Static Color Bridge

@MainActor
final class ThemeColorProvider {
    static let shared = ThemeColorProvider()
    private(set) var palette: AppPalette = .light

    func updatePalette(_ palette: AppPalette) {
        self.palette = palette
    }
}

extension Color {
    static var neonYellow: Color { ThemeColorProvider.shared.palette.accent }
    static var neonYellowEmphasis: Color { ThemeColorProvider.shared.palette.accentEmphasis }
    static var appBackground: Color { ThemeColorProvider.shared.palette.background }
    static var appForeground: Color { ThemeColorProvider.shared.palette.textPrimary }
    static var appForegroundMuted: Color { ThemeColorProvider.shared.palette.textSecondary }
    static var invertedForeground: Color { ThemeColorProvider.shared.palette.textInverted }
    static var cardBackground: Color { ThemeColorProvider.shared.palette.surfacePrimary }
    static var cardSurface: Color { ThemeColorProvider.shared.palette.surfaceSecondary }
    static var cardOutline: Color { ThemeColorProvider.shared.palette.outline }
    static var neutralHigh: Color { ThemeColorProvider.shared.palette.neutralHigh }
    static var neutralLow: Color { ThemeColorProvider.shared.palette.neutralLow }
    static var shadowStrong: Color { ThemeColorProvider.shared.palette.shadowStrong }
    static var shadowSoft: Color { ThemeColorProvider.shared.palette.shadowSoft }
    static var textSecondary: Color { ThemeColorProvider.shared.palette.textSecondary }
    static var accentForeground: Color { ThemeColorProvider.shared.palette.accentForeground }
}
