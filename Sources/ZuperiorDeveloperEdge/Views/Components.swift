import SwiftUI
import AppKit

// MARK: - GridButtonData

struct GridButtonData: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let url: String
}

// MARK: - GridButton

struct GridButton: View {
    let data: GridButtonData
    @State private var hovered = false

    var body: some View {
        Button(action: {
            guard let url = URL(string: data.url) else { return }
            NSWorkspace.shared.open(url)
        }) {
            HStack(alignment: .center, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(data.color.opacity(hovered ? 0.18 : 0.10))
                        .frame(width: 32, height: 32)
                    Image(systemName: data.icon)
                        .font(.system(size: Theme.FontSize.icon))
                        .foregroundColor(data.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(.system(size: Theme.FontSize.title, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(data.subtitle)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(hovered ? data.color.opacity(0.07) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(hovered ? data.color.opacity(0.22) : Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - ActionGridButton

struct ActionGridButton: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    var running: Bool = false
    var statusText: String? = nil
    var statusColor: Color = Theme.green
    var alert: Bool = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: { if !running { action() } }) {
            HStack(alignment: .center, spacing: 9) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color.opacity(hovered ? 0.18 : 0.10))
                        .frame(width: 32, height: 32)
                    if running {
                        ProgressView().scaleEffect(0.5).frame(width: 32, height: 32)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: Theme.FontSize.icon))
                            .foregroundColor(color)
                            .frame(width: 32, height: 32)
                    }
                    if alert {
                        Circle().fill(Theme.orange).frame(width: 7, height: 7).offset(x: 2, y: -2)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: Theme.FontSize.title, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if let status = statusText {
                        Text(status)
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundColor(statusColor)
                            .lineLimit(1)
                    } else {
                        Text(subtitle)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(hovered ? color.opacity(0.07) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 9)
                .stroke(hovered ? color.opacity(0.22) : Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - LinkRow

struct LinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let url: String
    var customAction: (() -> Void)?
    @State private var hovered = false

    init(icon: String, iconColor: Color, title: String, subtitle: String, url: String, customAction: (() -> Void)? = nil) {
        self.icon = icon; self.iconColor = iconColor
        self.title = title; self.subtitle = subtitle
        self.url = url; self.customAction = customAction
    }

    var body: some View {
        Button(action: {
            if let custom = customAction {
                custom()
            } else if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(iconColor.opacity(0.10)).frame(width: 28, height: 28)
                    Image(systemName: icon).font(.system(size: Theme.FontSize.title)).foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: Theme.FontSize.title, weight: .medium)).foregroundColor(Theme.textPrimary)
                    Text(subtitle).font(.system(size: Theme.FontSize.caption)).foregroundColor(Theme.textMuted).lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: Theme.FontSize.tiny, weight: .semibold))
                    .foregroundColor(hovered ? iconColor : Theme.textMuted.opacity(0.4))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(hovered ? Theme.rowHover : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - OutputConsole

struct OutputConsole: View {
    let output: String
    let running: Bool
    var onClose: (() -> Void)? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(output)
                    .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                    .foregroundColor(Color(white: 0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .id("bottom")
            }
            .frame(maxHeight: 140)
            .background(Color.black.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
            .cornerRadius(8)
            .overlay(alignment: .topTrailing) {
                // Dismiss button · only once the task has finished.
                if let onClose, !running {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: Theme.FontSize.tiny, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                            .padding(5)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .help("Dismiss")
                    .accessibilityLabel("Dismiss")
                }
            }
            .onChange(of: output) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }
}
