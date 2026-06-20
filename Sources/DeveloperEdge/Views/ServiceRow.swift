import SwiftUI
import AppKit

// MARK: - ServiceTableRow (table layout)

struct ServiceTableRow: View {
    let svc: ZService
    let env: Env
    @ObservedObject var store: Store
    var urlStr: String? { svc.urls[env] }
    var mainURL: String? { urlStr }
    // Prefer the latest run we have a status for; fall back to the full actions list.
    var pipelineURL: String {
        store.pipelineRunURLs[svc.repo] ?? "https://github.com/\(AppConfig.current.github.org)/\(svc.repo)/actions"
    }
    var reach: ReachStatus { urlStr.map { store.status(for: $0) } ?? .unknown }
    var pipeline: PipelineStatus { store.pipeline(for: svc.repo) }
    var color: Color { kindColor(svc.kind) }

    var body: some View {
        HStack(spacing: 0) {
            // Name + URL → opens main URL
            Button(action: { open(mainURL) }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(svc.name)
                        .font(.system(size: Theme.FontSize.title, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if let u = urlStr {
                        Text(u.replacingOccurrences(of: "https://", with: ""))
                            .font(.system(size: Theme.FontSize.tinyMd, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Health · display only
            statusTag(label: reachLabel, color: reachColor)
                .frame(width: 48, alignment: .leading)
                .padding(.leading, 10)

            // Pipeline → opens GitHub Actions
            if !store.githubToken.isEmpty {
                Button(action: { NSWorkspace.shared.open(URL(string: pipelineURL)!) }) {
                    statusTag(label: pipelineLabel, color: pipelineColor)
                        .frame(width: 62, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
            }

            // Arrow → opens main URL (frontends only); reserved space keeps columns aligned
            if svc.kind == .frontend {
                Button(action: { open(mainURL) }) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                        .foregroundColor(color.opacity(0.5))
                        .frame(width: 22, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
                .help("Open \(svc.repo) in browser")
                .accessibilityLabel("Open \(svc.repo) in browser")
            } else {
                Spacer().frame(width: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .contextMenu {
            if let u = mainURL, let url = URL(string: u) {
                Button("Open in Browser") { NSWorkspace.shared.open(url) }
            }
            Button(store.pipelineRunURLs[svc.repo] != nil ? "Open Latest Run" : "Open GitHub Actions") {
                guard let url = URL(string: pipelineURL) else { return }
                NSWorkspace.shared.open(url)
            }
            Divider()
            if let u = mainURL {
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(u, forType: .string)
                }
            }
        }
    }

    private func open(_ urlStr: String?) {
        guard let u = urlStr, let url = URL(string: u) else { return }
        NSWorkspace.shared.open(url)
    }

    @ViewBuilder
    private func statusTag(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: Theme.FontSize.caption, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.12)))
    }

    var reachColor: Color {
        switch reach {
        case .unknown: return Theme.textMuted.opacity(0.35)
        case .up:      return Theme.green
        case .down:    return Theme.red
        }
    }
    var reachLabel: String {
        switch reach {
        case .unknown: return "·"
        case .up:      return "Up"
        case .down:    return "Down"
        }
    }
    var pipelineColor: Color {
        switch pipeline {
        case .unknown:  return Theme.textMuted.opacity(0.35)
        case .running:  return Theme.orange
        case .success:  return Theme.green
        case .failure:  return Theme.red
        }
    }
    var pipelineLabel: String {
        switch pipeline {
        case .unknown:  return "·"
        case .running:  return "Running"
        case .success:  return "Pass"
        case .failure:  return "Fail"
        }
    }
}

// MARK: - ServiceCard (2-column grid)

struct ServiceCard: View {
    let svc: ZService
    let env: Env
    @ObservedObject var store: Store
    @State private var hovered = false

    var urlStr: String? { svc.urls[env] }
    var openURLStr: String? {
        guard let base = urlStr else { return nil }
        return svc.kind == .api ? base + svc.healthPath : base
    }
    var reach: ReachStatus { urlStr.map { store.status(for: $0) } ?? .unknown }
    var pipeline: PipelineStatus { store.pipeline(for: svc.repo) }
    var color: Color { kindColor(svc.kind) }

    var body: some View {
        Button(action: {
            guard let u = openURLStr, let url = URL(string: u) else { return }
            NSWorkspace.shared.open(url)
        }) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(color.opacity(hovered ? 0.18 : 0.10))
                            .frame(width: 30, height: 30)
                        Image(systemName: svc.icon)
                            .font(.system(size: Theme.FontSize.heading))
                            .foregroundColor(color)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        statusDot
                        if !store.githubToken.isEmpty {
                            pipelineDot
                        }
                    }
                    .padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(svc.name)
                        .font(.system(size: Theme.FontSize.title, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    if let u = urlStr {
                        Text(u.replacingOccurrences(of: "https://", with: ""))
                            .font(.system(size: Theme.FontSize.tinyMd))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else {
                        Text("No URL")
                            .font(.system(size: Theme.FontSize.tinyMd))
                            .foregroundColor(Theme.textMuted.opacity(0.5))
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(hovered ? color.opacity(0.07) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(hovered ? color.opacity(0.22) : Color.white.opacity(0.08), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .contextMenu {
            if let u = openURLStr {
                Button("Open in Browser") { NSWorkspace.shared.open(URL(string: u)!) }
                Divider()
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(u, forType: .string)
                }
            }
        }
    }

    @ViewBuilder
    var statusDot: some View {
        switch reach {
        case .unknown: Circle().fill(Theme.textMuted.opacity(0.3)).frame(width: 7, height: 7)
        case .up:      Circle().fill(Theme.green).frame(width: 7, height: 7)
        case .down:    Circle().fill(Theme.red).frame(width: 7, height: 7)
        }
    }

    @ViewBuilder
    var pipelineDot: some View {
        switch pipeline {
        case .unknown:  RoundedRectangle(cornerRadius: 1.5).fill(Theme.textMuted.opacity(0.3)).frame(width: 7, height: 7)
        case .running:  RoundedRectangle(cornerRadius: 1.5).fill(Theme.orange).frame(width: 7, height: 7)
        case .success:  RoundedRectangle(cornerRadius: 1.5).fill(Theme.green).frame(width: 7, height: 7)
        case .failure:  RoundedRectangle(cornerRadius: 1.5).fill(Theme.red).frame(width: 7, height: 7)
        }
    }
}

struct ServiceRow: View {
    let svc: ZService
    let env: Env
    @ObservedObject var store: Store
    @State private var hovered = false

    var urlStr: String? { svc.urls[env] }
    var openURLStr: String? {
        guard let base = urlStr else { return nil }
        return svc.kind == .api ? base + svc.healthPath : base
    }
    var reach: ReachStatus { urlStr.map { store.status(for: $0) } ?? .unknown }

    var body: some View {
        let color = kindColor(svc.kind)
        let row = HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color.opacity(0.7))
                .frame(width: 3, height: 28)
                .padding(.leading, 4).padding(.trailing, 10)

            Image(systemName: svc.icon)
                .font(.system(size: Theme.FontSize.heading))
                .foregroundColor(color.opacity(0.85))
                .frame(width: 18)
                .padding(.trailing, 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(svc.name)
                    .font(.system(size: Theme.FontSize.heading, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                if let u = urlStr {
                    Text(u.replacingOccurrences(of: "https://", with: ""))
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1).truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)
            statusDot.padding(.trailing, urlStr != nil ? 8 : 12)

            if urlStr != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(hovered ? envColor(env) : Theme.textMuted.opacity(0.6))
                    .padding(.trailing, 12)
            }
        }
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 8).fill(hovered && urlStr != nil ? Theme.rowHover : Color.clear))
        .contentShape(Rectangle())
        .contextMenu {
            if let u = openURLStr {
                Button("Open in Browser") { NSWorkspace.shared.open(URL(string: u)!) }
                Divider()
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(u, forType: .string)
                }
            }
        }

        if let u = openURLStr, let url = URL(string: u) {
            Button(action: { NSWorkspace.shared.open(url) }) { row }
                .buttonStyle(.plain)
                .onHover { hovered = $0 }
        } else {
            row
        }
    }

    @ViewBuilder
    var statusDot: some View {
        switch reach {
        case .unknown: Circle().fill(Theme.textMuted.opacity(0.3)).frame(width: 6, height: 6)
        case .up:      Circle().fill(Theme.green).frame(width: 6, height: 6)
        case .down:    Circle().fill(Theme.red).frame(width: 6, height: 6)
        }
    }
}
