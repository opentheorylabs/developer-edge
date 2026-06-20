import SwiftUI
import AppKit
import Defaults

/// First-run guided setup: GitHub token, Jira token, then clone the workspace.
struct OnboardingView: View {
    @ObservedObject var store: Store
    var onDone: () -> Void

    @State private var step = 0
    @State private var githubDraft = ""
    @State private var jiraDraft = ""

    enum JiraMode { case choose, create, have }
    @State private var jiraMode: JiraMode = .choose
    @State private var lastPasteCount = NSPasteboard.general.changeCount
    private let clipboardTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let total = 4   // welcome(0) github(1) jira(2) workspace(3)

    var body: some View {
        VStack(spacing: 0) {
            // progress dots
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.purple : Color.white.opacity(0.12))
                        .frame(width: i == step ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: step)
                }
            }
            .padding(.top, 16).padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch step {
                    case 0: welcomeStep
                    case 1: githubStep
                    case 2: jiraStep
                    default: workspaceStep
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .frame(height: 470)
        .onAppear { store.autoDetectJiraEmail() }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("👋")
                .font(.system(size: 40))
            Text("Welcome to Developer Edge")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("Your menu-bar cockpit for the trading platform: PRs, Jira, environments, and a one-click workspace. Let's get you set up in three quick steps.")
                .font(.system(size: Theme.FontSize.heading))
                .foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var githubStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("🔑", "Connect GitHub", "Powers the PRs tab and lists the repos to clone.")
            link("Create a token (classic): repo + read:org", "https://github.com/settings/tokens/new?scopes=repo,read:org&description=Developer%20Edge")
            tokenField("Paste your GitHub token (ghp_…)", text: $githubDraft, accent: Theme.purple)
            if !store.githubToken.isEmpty {
                statusLine("GitHub token saved", ok: true)
            }
            note("Important: if the token is fine-grained or your org uses SSO, authorize it for \(AppConfig.current.github.org).")
        }
    }

    private var jiraStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("📋", "Connect Jira", "Shows your sprint tickets. Account ID is fetched automatically.")

            HStack(spacing: 8) {
                Text("Email").font(.system(size: Theme.FontSize.small, weight: .medium)).foregroundColor(Theme.textMuted)
                TextField("you@company.com", text: jiraEmailBinding)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(.white)
                    .tint(Theme.orange)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            note("Auto-detected from git · fix it if that's not your Atlassian email (the token won't work otherwise).")

            if !store.jiraApiToken.isEmpty {
                statusLine("Jira token saved", ok: true)
            } else {
                switch jiraMode {
                case .choose:
                    HStack(spacing: 8) {
                        grayButton("Create a Token") { startCreateFlow() }
                        grayButton("I Already Have One") { withAnimation { jiraMode = .have } }
                    }
                case .create:
                    createTokenGuide
                case .have:
                    tokenField("Paste your Jira API token (ATATT…)", text: $jiraDraft, accent: Theme.orange)
                }
            }
            note("Optional · press Continue to skip. You can add it later in Settings.")
        }
        .onReceive(clipboardTimer) { _ in pollClipboardForToken() }
    }

    private var createTokenGuide: some View {
        VStack(alignment: .leading, spacing: 10) {
            numberedStep(1, "Open the page, then click \u{201C}Create API token\u{201D}.")
            grayButton("Open Token Page ↗") { openTokenPage() }
            numberedStep(2, "Name it \u{201C}\(AppConfig.current.branding.appName)\u{201D}, then click Copy.")
            numberedStep(3, "Switch back here · we grab it automatically.")
            HStack(spacing: 6) {
                Spinner(color: Theme.orange, size: Theme.FontSize.heading, lineWidth: 1.5)
                Text("Watching clipboard for your token…")
                    .font(.system(size: Theme.FontSize.small)).foregroundColor(Theme.textMuted)
            }
            .padding(.top, 2)
            tokenField("…or paste it here", text: $jiraDraft, accent: Theme.orange)
        }
    }

    private var jiraEmailBinding: Binding<String> {
        Binding(get: { store.jiraEmail },
                set: { store.jiraEmail = $0; Defaults[.jiraEmail] = $0 })
    }

    private func startCreateFlow() {
        lastPasteCount = NSPasteboard.general.changeCount   // only detect NEW copies
        withAnimation { jiraMode = .create }
        openTokenPage()
    }

    private func openTokenPage() {
        NSWorkspace.shared.open(URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
    }

    /// Detects a freshly-copied Jira token (ATATT…) and fills it in automatically.
    private func pollClipboardForToken() {
        guard jiraMode == .create, store.jiraApiToken.isEmpty else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastPasteCount else { return }
        lastPasteCount = pb.changeCount
        guard let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              s.hasPrefix("ATATT") else { return }
        jiraDraft = s
        store.jiraApiToken = s
        Defaults[.jiraApiToken] = s
        store.fetchJiraDisplayName()
    }

    private var workspaceStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("📦", "Set up your workspace", "Clones every repo you can access into Frontend / Backend / Mobile / DevOps.")
            if store.isWorkspaceSetUp && store.setupExitCode == nil && !store.setupRunning {
                statusLine("Workspace already set up", ok: true)
            }
            Button(action: { store.selectParentAndSetup() }) {
                HStack(spacing: 8) {
                    if store.setupRunning {
                        Spinner(color: .white, size: Theme.FontSize.heading, lineWidth: 1.5)
                        Text("Cloning \(store.setupCloned)/\(store.setupTotal)…")
                    } else {
                        Image(systemName: "square.and.arrow.down.on.square")
                        Text(store.setupExitCode == 0 ? "Set Up Again" : "Choose Folder & Clone")
                    }
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.purple.opacity(store.setupRunning ? 0.5 : 1)))
            }
            .buttonStyle(.plain)
            .disabled(store.setupRunning || store.githubToken.isEmpty)

            if store.githubToken.isEmpty {
                note("Add a GitHub token first (step 2) to clone repos.")
            }
            if !store.setupOutput.isEmpty {
                OutputConsole(output: store.setupOutput, running: store.setupRunning,
                              onClose: { store.setupOutput = "" })
            }
            if store.setupExitCode == 0 {
                statusLine("Workspace ready", ok: true)
            }
        }
    }

    // MARK: - Footer nav

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.plain).font(.system(size: Theme.FontSize.title)).foregroundColor(Theme.textMuted)
            }
            Spacer()
            Button(action: advance) {
                Text(step < total - 1 ? "Continue" : "Finish")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.purple))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }

    private func advance() {
        // Save the current step's input before moving on.
        if step == 1 {
            let t = githubDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { store.githubToken = t; Defaults[.githubToken] = t }
        }
        if step == 2 {
            let t = jiraDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                store.jiraApiToken = t; Defaults[.jiraApiToken] = t
                store.fetchJiraDisplayName()
            }
        }
        if step < total - 1 {
            withAnimation { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        Defaults[.onboardingComplete] = true
        onDone()
    }

    // MARK: - Small helpers

    private func stepHeader(_ emoji: String, _ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emoji).font(.system(size: 30))
            Text(title).font(.system(size: 17, weight: .bold)).foregroundColor(Theme.textPrimary)
            Text(desc).font(.system(size: 12.5)).foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Plain TextField (not SecureField) so the pasted token is legible on the dark
    // panel · SecureField renders black/invisible here.
    private func tokenField(_ placeholder: String, text: Binding<String>, accent: Color) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: Theme.FontSize.title, design: .monospaced))
            .foregroundColor(.white)
            .tint(accent)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.4), lineWidth: 0.5))
    }

    private func grayButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: Theme.FontSize.title, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func numberedStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.system(size: Theme.FontSize.caption, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 17, height: 17)
                .background(Circle().fill(Color.white.opacity(0.1)))
            Text(text)
                .font(.system(size: Theme.FontSize.title))
                .foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func link(_ label: String, _ url: String) -> some View {
        Button(action: { NSWorkspace.shared.open(URL(string: url)!) }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.square").font(.system(size: Theme.FontSize.caption))
                Text(label).font(.system(size: Theme.FontSize.body, weight: .medium))
            }
            .foregroundColor(Theme.blue)
        }
        .buttonStyle(.plain)
    }

    private func statusLine(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: Theme.FontSize.small)).foregroundColor(ok ? Theme.green : Theme.red)
            Text(text).font(.system(size: Theme.FontSize.body)).foregroundColor(Theme.textMuted)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.small))
            .foregroundColor(Theme.textMuted.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}
