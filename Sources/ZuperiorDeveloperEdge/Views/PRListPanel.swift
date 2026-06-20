import SwiftUI
import AppKit
import Pow

private let myPRsURL = "https://github.com/pulls?q=is%3Apr+is%3Aopen+author%3A%40me"
private let maxMyPRs = 7

struct PRListPanel: View {
    @ObservedObject var store: Store
    var onOpenSettings: () -> Void = {}

    private var isEmpty: Bool { store.myPRs.isEmpty && store.reviewRequests.isEmpty }

    var body: some View {
        if store.githubToken.isEmpty {
            noTokenView
        } else {
            listView
        }
    }

    private var githubActions: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                GridButton(data: GridButtonData(
                    icon: "eye", color: Theme.blue,
                    title: "Review Requests", subtitle: "Waiting on you",
                    url: "https://github.com/pulls?q=is%3Apr+is%3Aopen+review-requested%3A%40me"))
                GridButton(data: GridButtonData(
                    icon: "building.columns", color: Theme.blue,
                    title: "Org Repos", subtitle: AppConfig.current.github.org,
                    url: "https://github.com/orgs/\(AppConfig.current.github.org)/repositories"))
            }
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
    }

    private var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                githubActions
                if store.prsFetching && isEmpty {
                    LoadingStateView(message: "Loading pull requests…")
                } else if isEmpty {
                    emptyView
                } else {
                    prSections
                }
            }
            .padding(.bottom, 8)
            .animation(.easeOut(duration: 0.35), value: store.myPRs.count)
            .animation(.easeOut(duration: 0.35), value: store.reviewRequests.count)
        }
    }

    @ViewBuilder
    private var prSections: some View {
        Group {
            if !store.reviewRequests.isEmpty {
                sectionHeader("Review Requests", count: store.reviewRequests.count)
                ForEach(Array(store.reviewRequests.enumerated()), id: \.element.id) { i, pr in
                    PRRow(pr: pr)
                    if i < store.reviewRequests.count - 1 {
                        Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
                    }
                }
            }
            if !store.myPRs.isEmpty {
                let visible = Array(store.myPRs.prefix(maxMyPRs))
                sectionHeader("My PRs", count: store.myPRs.count)
                ForEach(Array(visible.enumerated()), id: \.element.id) { i, pr in
                    PRRow(pr: pr)
                        .transition(.movingParts.move(edge: .top).combined(with: .opacity))
                    if i < visible.count - 1 {
                        Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
                    }
                }
                if store.myPRs.count > maxMyPRs {
                    showAllButton
                }
            }
        }
    }

    private var showAllButton: some View {
        Button(action: { NSWorkspace.shared.open(URL(string: myPRsURL)!) }) {
            HStack(spacing: 4) {
                Text("Show all \(store.myPRs.count) on GitHub")
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(Theme.blue.opacity(0.8))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: Theme.FontSize.tiny, weight: .semibold))
                    .foregroundColor(Theme.blue.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(_ label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: Theme.FontSize.tinyMd, weight: .semibold)).tracking(0.6)
                .foregroundColor(Theme.textMuted)
            Text("\(count)")
                .font(.system(size: Theme.FontSize.tinyMd, weight: .semibold))
                .foregroundColor(Theme.textMuted.opacity(0.5))
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var emptyView: some View {
        EmptyStateView(icon: "checkmark.circle",
                       iconColor: Theme.green.opacity(0.6),
                       title: "Nothing needs your attention",
                       subtitle: "No open PRs or review requests")
    }

    private var noTokenView: some View {
        VStack(spacing: 0) {
            githubActions
            EmptyStateView(icon: "lock.circle",
                           title: "GitHub token required",
                           subtitle: "Connect GitHub to see your PRs and review requests.",
                           actionTitle: "Add GitHub Token",
                           action: onOpenSettings)
        }
    }
}

private struct PRRow: View {
    let pr: PRItem

    var body: some View {
        Button(action: { NSWorkspace.shared.open(URL(string: pr.htmlUrl)!) }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        repoBadge
                        if pr.draft { draftBadge }
                        Spacer(minLength: 0)
                        Text(relativeTime)
                            .font(.system(size: Theme.FontSize.tinyMd))
                            .foregroundColor(Theme.textMuted.opacity(0.55))
                    }
                    Text(pr.title)
                        .font(.system(size: Theme.FontSize.title, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text("#\(pr.number)")
                            .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                            .foregroundColor(Theme.textMuted.opacity(0.6))
                        Text("\u{00B7}")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted.opacity(0.4))
                        Text(pr.author)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                Image(systemName: "arrow.up.right")
                    .font(.system(size: Theme.FontSize.tiny, weight: .semibold))
                    .foregroundColor(Theme.textMuted.opacity(0.3))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var repoBadge: some View {
        Text(shortRepo)
            .font(.system(size: Theme.FontSize.tiny, weight: .medium))
            .foregroundColor(Theme.purple.opacity(0.85))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Theme.purple.opacity(0.10)))
    }

    private var draftBadge: some View {
        Text("Draft")
            .font(.system(size: Theme.FontSize.tiny, weight: .medium))
            .foregroundColor(Theme.textMuted.opacity(0.7))
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)))
    }

    private var shortRepo: String {
        var s = pr.repo
        if let prefix = AppConfig.current.github.repoPrefix, !prefix.isEmpty {
            s = s.hasPrefix(prefix) ? String(s.dropFirst(prefix.count)) : s
        }
        return s
            .replacingOccurrences(of: "frontend-", with: "fe/")
            .replacingOccurrences(of: "backend-", with: "be/")
            .replacingOccurrences(of: "mobile-", with: "mobile/")
            .replacingOccurrences(of: "-website", with: "")
            .replacingOccurrences(of: "-service", with: "")
    }

    private var relativeTime: String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: pr.updatedAt, relativeTo: Date())
    }
}
