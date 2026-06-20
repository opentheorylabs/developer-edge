import SwiftUI

enum Theme {
    /// Single source of truth for font sizes used across the panel.
    /// One-off display sizes (logo, splash) stay as literals.
    enum FontSize {
        static let tiny:    CGFloat = 9      // hover hints, chevrons
        static let tinyMd:  CGFloat = 9.5    // status pills
        static let caption: CGFloat = 10     // subtitles
        static let label:   CGFloat = 10.5   // form labels, secondary text
        static let small:   CGFloat = 11     // most icons, footer text
        static let body:    CGFloat = 11.5   // settings rows
        static let title:   CGFloat = 12     // row titles
        static let heading: CGFloat = 13     // section headings
        static let icon:    CGFloat = 14     // larger icons
    }

    static let green   = Color(red: 118/255, green: 185/255, blue: 0)
    static let blue    = Color(red: 0.38,  green: 0.68, blue: 1.0)
    static let orange  = Color(red: 1.0,   green: 0.72, blue: 0.30)
    static let purple  = Color(red: 0.80,  green: 0.55, blue: 1.0)
    static let red     = Color(red: 0.886, green: 0.333, blue: 0.310)
    static let panel        = Color(red: 0.086, green: 0.086, blue: 0.094)
    static let rowHover     = Color.white.opacity(0.06)
    static let divider      = Color.white.opacity(0.08)
    static let textPrimary  = Color(white: 0.92)
    static let textMuted    = Color(white: 0.48)
    static let badge        = Color.white.opacity(0.07)
}

func envColor(_ env: Env) -> Color {
    switch env {
    case .dev:     return Theme.green
    case .staging: return Theme.orange
    case .prod:    return Theme.blue
    }
}

func kindColor(_ kind: ServiceKind) -> Color {
    kind == .frontend ? Theme.blue : Theme.green
}

func clusterColor(_ env: String) -> Color {
    switch env {
    case "Development": return Theme.green
    case "Staging":     return Theme.orange
    case "Production":  return Theme.blue
    default:            return Theme.textMuted
    }
}
