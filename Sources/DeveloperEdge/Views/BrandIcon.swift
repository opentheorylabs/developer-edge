import SwiftUI
import AppKit

/// Monochrome brand marks (simple-icons single-path SVGs) rendered as tintable
/// template NSImages. Built once and cached · never recreate per render (avoids flicker).
enum Brand: String {
    case github, jira

    private static let svg: [String: String] = [
        "github": #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="black" d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222 0 1.606-.014 2.898-.014 3.293 0 .322.216.694.825.576C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>"#,
        "jira": #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="black" d="M11.571 11.513H0a5.218 5.218 0 0 0 5.232 5.215h2.13v2.057A5.215 5.215 0 0 0 12.575 24V12.518a1.005 1.005 0 0 0-1.005-1.005zm5.723-5.756H5.736a5.215 5.215 0 0 0 5.215 5.214h2.129v2.058a5.218 5.218 0 0 0 5.215 5.214V6.758a1.001 1.001 0 0 0-1.001-1.001zM23.013 0H11.455a5.215 5.215 0 0 0 5.215 5.215h2.129v2.057A5.215 5.215 0 0 0 24 12.483V1.005A1.001 1.001 0 0 0 23.013 0z"/></svg>"#,
    ]

    private static var cache: [String: NSImage] = [:]

    var image: NSImage? {
        if let cached = Brand.cache[rawValue] { return cached }
        guard let data = Brand.svg[rawValue]?.data(using: .utf8),
              let img = NSImage(data: data) else { return nil }
        img.isTemplate = true
        Brand.cache[rawValue] = img
        return img
    }
}

/// A tab icon: either an SF Symbol or a bundled brand mark.
enum TabIcon {
    case sf(String)
    case brand(Brand)
}

struct TabIconView: View {
    let icon: TabIcon
    let color: Color
    let active: Bool
    var size: CGFloat = 13

    var body: some View {
        let tint = active ? color : Theme.textMuted
        switch icon {
        case .sf(let name):
            Image(systemName: name)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(tint)
        case .brand(let brand):
            if let img = brand.image {
                Image(nsImage: img)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .foregroundColor(tint)
            } else {
                Image(systemName: "square")
                    .font(.system(size: size, weight: .medium))
                    .foregroundColor(tint)
            }
        }
    }
}
