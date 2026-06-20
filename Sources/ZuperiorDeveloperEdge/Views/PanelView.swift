import SwiftUI
import AppKit
import Pow
import Defaults

struct TabBar: View {
    @Binding var active: String

    private let tabs: [(id: String, label: String, color: Color, icon: TabIcon)] = [
        ("dev",   "Development", Theme.green,  .sf("hammer.fill")),
        ("prs",   "GitHub",      Theme.blue,   .brand(.github)),
        ("jira",  "JIRA",        Theme.orange, .brand(.jira)),
        ("envs",  "Services",    Theme.purple, .sf("square.stack.3d.up.fill")),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { t in
                let on = active == t.id
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { active = t.id } }) {
                    VStack(spacing: 4) {
                        TabIconView(icon: t.icon, color: t.color, active: on, size: Theme.FontSize.heading)
                            .frame(height: 15)
                        Text(t.label)
                            .font(.system(size: Theme.FontSize.label, weight: on ? .semibold : .regular))
                            .foregroundColor(on ? t.color : Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8).padding(.bottom, 7)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(on ? t.color : Color.clear)
                            .frame(height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PanelView: View {
    @ObservedObject var store: Store
    @State private var activeTab = "dev"
    @State private var showSettings = false
    @State private var footerMsg = ""
    @State private var showMascot = false
    // Decided once at launch: an existing user (token already set) or someone who
    // finished onboarding is "onboarded". Kept stable so entering the token mid-flow
    // doesn't dismiss the remaining steps.
    @State private var onboarded = Defaults[.onboardingComplete] || !Defaults[.githubToken].isEmpty

    private static let logoImage: NSImage? = {
        guard let path = Bundle.main.path(forResource: "logo", ofType: "png") else { return nil }
        return NSImage(contentsOfFile: path)
    }()

    private static let mascotImage: NSImage? = {
        guard let path = Bundle.main.path(forResource: "mascot", ofType: "png") else { return nil }
        return NSImage(contentsOfFile: path)
    }()

    private func tapLogo() {
        guard Self.mascotImage != nil else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showMascot = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.easeIn(duration: 0.3)) { showMascot = false }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Theme.divider).frame(height: 1)

            if !onboarded {
                OnboardingView(store: store, onDone: { withAnimation { onboarded = true } })
            } else if showSettings {
                SettingsView(store: store, dismiss: { showSettings = false })
            } else {
                TabBar(active: $activeTab)
                Rectangle().fill(Theme.divider).frame(height: 1)

                Group {
                    switch activeTab {
                    case "dev":  DevelopmentPanel(store: store)
                    case "prs":  PRListPanel(store: store, onOpenSettings: { showSettings = true })
                    case "jira": QuickActionsPanel(store: store, onOpenSettings: { showSettings = true })
                    default:     EnvironmentsPanel(store: store)
                    }
                }
                .frame(height: 440)
                .onChange(of: activeTab) { tab in
                    if tab == "prs" { store.fetchOpenPRs() }
                }
            }

            Rectangle().fill(Theme.divider).frame(height: 1)
            footer
        }
        .frame(width: 390)
        .background(Theme.panel)
        .overlay(alignment: .bottom) {
            if showMascot, let mascot = Self.mascotImage {
                Image(nsImage: mascot)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 150)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .clipped()
        .onAppear { refreshIfStale() }
        .onChange(of: store.popoverSession) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                footerMsg = FooterMessage.current(name: store.firstName, fullName: store.userName)
            }
            refreshIfStale()
        }
    }

    /// Refresh GitHub PRs and Jira tickets whose needsRefresh flag has been
    /// flipped by the 60s timer · so each open shows fresh data without
    /// spamming the APIs on rapid open/close.
    private func refreshIfStale() {
        if !store.githubToken.isEmpty, store.prsNeedsRefresh, !store.prsFetching {
            store.fetchOpenPRs()
        }
        if !store.jiraApiToken.isEmpty, store.jiraNeedsRefresh, !store.jiraFetching {
            store.fetchJiraTickets()
        }
    }

    // MARK: - Header

    var header: some View {
        HStack(spacing: 8) {
            if let nsImg = Self.logoImage {
                Image(nsImage: nsImg)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 20, height: 20)
                    .onTapGesture { tapLogo() }
            }

            Text("Developer Edge")
                .font(.system(size: Theme.FontSize.icon, weight: .bold))
                .foregroundStyle(LinearGradient(
                    colors: [Theme.purple, Theme.blue],
                    startPoint: .leading, endPoint: .trailing
                ))

            Text("BETA")
                .font(.system(size: 8, weight: .heavy))
                .tracking(0.5)
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .frame(height: 14)
                .background(Capsule().fill(.white))

            Spacer()

            if store.updateRunning {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 12, height: 12)
                    Text("Updating…")
                        .font(.system(size: Theme.FontSize.label))
                        .foregroundColor(Theme.green)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.35), lineWidth: 0.5))
            } else if store.updateAvailable {
                Button(action: { store.runUpdate() }) {
                    Text("Update available!")
                        .font(.system(size: Theme.FontSize.label, weight: .semibold))
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.green.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.green.opacity(0.35), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: Theme.FontSize.title, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Footer

    var footer: some View {
        HStack {
            Text(footerMsg)
                .font(.system(size: Theme.FontSize.label))
                .foregroundColor(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .truncationMode(.tail)
                .id(footerMsg)
                .transition(.movingParts.blur.combined(with: .opacity))
            Spacer(minLength: 8)
            Button(action: { NSWorkspace.shared.open(URL(string: "https://github.com/zuperior-platform/zuperior-developer-edge/issues/new")!) }) {
                Text("Request a feature")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }
}
