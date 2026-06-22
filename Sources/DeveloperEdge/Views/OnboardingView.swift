import SwiftUI
import AppKit
import Defaults

/// Multi-step onboarding wizard:
/// folder(0) → github(1) → orgs(2) → repos(3) → cloning(4) → done(5)
struct OnboardingView: View {
    @ObservedObject var store: Store
    var onDone: () -> Void

    @State private var step = 0
    @State private var githubDraft = ""
    @State private var workspaceDraft = ""
    @State private var selectedOrgLogins: Set<String> = []
    @State private var selectedRepoIds: Set<Int> = []
    @State private var lastPasteCount = NSPasteboard.general.changeCount
    private let clipboardTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let totalSteps = 6  // 0..5

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
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
                    case 0: folderStep
                    case 1: githubStep
                    case 2: orgsStep
                    case 3: reposStep
                    case 4: cloningStep
                    default: doneStep
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .frame(height: 500)
        .onReceive(clipboardTimer) { _ in pollClipboardForToken() }
    }

    // MARK: - Step 0: Folder

    private var folderStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("📁", "Choose your workspace folder",
                       "All repos will be cloned here. You can always change it later in Settings.")

            let display = workspaceDraft.isEmpty
                ? store.workspaceRoot.replacingOccurrences(of: NSHomeDirectory(), with: "~")
                : workspaceDraft.replacingOccurrences(of: NSHomeDirectory(), with: "~")

            if !display.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: Theme.FontSize.small))
                        .foregroundColor(Theme.blue)
                    Text(display)
                        .font(.system(size: Theme.FontSize.body, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.blue.opacity(0.35), lineWidth: 0.5))
            }

            Button(action: pickFolder) {
                HStack(spacing: 7) {
                    Image(systemName: "folder.badge.plus")
                    Text(workspaceDraft.isEmpty && store.workspaceRoot.isEmpty ? "Choose Folder" : "Change Folder")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.blue.opacity(0.75)))
            }
            .buttonStyle(.plain)

            if workspaceDraft.isEmpty && !store.workspaceRoot.isEmpty {
                note("Using the folder from your last session. Tap \u{201C}Change Folder\u{201D} to pick a different one.")
            } else {
                note("Tip: pick a folder like ~/Developer/Projects or ~/Code. A subfolder per org will be created inside it.")
            }
        }
    }

    private func pickFolder() {
        if let path = store.pickWorkspaceFolder() {
            workspaceDraft = path
        }
    }

    // MARK: - Step 1: GitHub token

    private var githubStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("🔑", "Connect GitHub",
                       "Powers the PRs tab and lets us list your repos for cloning.")
            link("Create a Classic token: repo + read:org",
                 "https://github.com/settings/tokens/new?scopes=repo,read:org&description=Developer%20Edge")
            tokenField("Paste your GitHub token (ghp_…)", text: $githubDraft, accent: Theme.purple)
            if !store.githubToken.isEmpty {
                statusLine("GitHub token saved", ok: true)
            }
            note("If your org uses SSO, authorize the token for the org after creating it.")
        }
    }

    // MARK: - Step 2: Orgs

    private var orgsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("🏢", "Pick an account or org",
                       "Choose whose repos to clone. You can clone from multiple orgs — come back to this step after finishing one.")

            if store.orgsFetching {
                HStack(spacing: 8) {
                    Spinner(color: Theme.purple, size: Theme.FontSize.heading, lineWidth: 1.5)
                    Text("Fetching your orgs…")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.vertical, 6)
            } else if store.onboardingOrgs.isEmpty {
                Button(action: { store.fetchOnboardingOrgs() }) {
                    Text("Load Orgs & Accounts")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Theme.purple))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.onboardingOrgs) { org in
                        orgRow(org)
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))

                if selectedOrgLogins.isEmpty {
                    note("Select one or more orgs or accounts, then press Continue to choose repos.")
                } else {
                    note("\(selectedOrgLogins.count) selected — repos will be fetched on the next step.")
                }
            }
        }
        .onAppear {
            if store.onboardingOrgs.isEmpty && !store.orgsFetching && !store.githubToken.isEmpty {
                store.fetchOnboardingOrgs()
            }
        }
    }

    private func orgRow(_ org: OnboardingOrg) -> some View {
        let selected = selectedOrgLogins.contains(org.login)
        return Button(action: {
            if selected {
                selectedOrgLogins.remove(org.login)
            } else {
                selectedOrgLogins.insert(org.login)
                // Prefetch repos as soon as org is selected
                if store.orgRepos[org.login] == nil {
                    store.fetchOnboardingRepos(for: org)
                }
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.system(size: Theme.FontSize.heading))
                    .foregroundColor(selected ? Theme.purple : Theme.textMuted.opacity(0.4))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(org.isUser ? "@\(org.login)" : org.login)
                        .font(.system(size: Theme.FontSize.title, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Text(org.isUser ? "Personal account" : "Organization")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
                if store.orgReposFetching.contains(org.login) {
                    ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                } else if let count = store.orgRepos[org.login]?.count {
                    Text("\(count) repos")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12).padding(.vertical, 9)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Repos

    private var reposStep: some View {
        let sortedLogins = selectedOrgLogins.sorted()
        let allPending = sortedLogins.flatMap { (store.orgRepos[$0] ?? []).filter { !$0.alreadyCloned } }
        let allSelected = !allPending.isEmpty && allPending.allSatisfy { selectedRepoIds.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            stepHeader("📦", "Select repos to clone",
                       "Repos land at workspace/org/repo. Already-cloned repos are skipped automatically.")

            HStack {
                Text("\(selectedRepoIds.count) selected")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.textMuted)
                Spacer()
                Button(allSelected ? "Deselect All" : "Select All") {
                    if allSelected {
                        selectedRepoIds = []
                    } else {
                        selectedRepoIds = Set(allPending.map(\.id))
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: Theme.FontSize.caption, weight: .medium))
                .foregroundColor(Theme.blue)
            }

            ForEach(sortedLogins, id: \.self) { login in
                orgRepoSection(login: login)
            }
        }
        .onAppear {
            for login in selectedOrgLogins {
                if store.orgRepos[login] == nil,
                   !store.orgReposFetching.contains(login),
                   let org = store.onboardingOrgs.first(where: { $0.login == login }) {
                    store.fetchOnboardingRepos(for: org)
                }
            }
        }
    }

    @ViewBuilder
    private func orgRepoSection(login: String) -> some View {
        let fetching = store.orgReposFetching.contains(login)
        let repos = store.orgRepos[login]

        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Text(login)
                    .font(.system(size: Theme.FontSize.label, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                if fetching { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                if let count = repos?.count {
                    Text("· \(count)")
                        .font(.system(size: Theme.FontSize.tiny))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(0.03))

            if let repos {
                if repos.isEmpty {
                    Text("No repos found.")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                } else {
                    ForEach(repos) { repo in
                        repoRow(repo)
                        if repo.id != repos.last?.id {
                            Rectangle().fill(Theme.divider).frame(height: 1).padding(.leading, 42)
                        }
                    }
                }
            } else if !fetching {
                Text("Tap to load…")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.textMuted.opacity(0.5))
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func repoSection(repos: [OnboardingRepo], login: String) -> some View {
        VStack(spacing: 2) {
            ForEach(repos) { repo in
                repoRow(repo)
            }
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func repoRow(_ repo: OnboardingRepo) -> some View {
        let selected = selectedRepoIds.contains(repo.id)
        let dimmed = repo.alreadyCloned

        return Button(action: {
            guard !dimmed else { return }
            if selected { selectedRepoIds.remove(repo.id) }
            else { selectedRepoIds.insert(repo.id) }
        }) {
            HStack(spacing: 10) {
                Image(systemName: dimmed ? "checkmark.circle.fill" : (selected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: Theme.FontSize.heading))
                    .foregroundColor(dimmed ? Theme.textMuted.opacity(0.5) : (selected ? Theme.purple : Theme.textMuted))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(repo.name)
                            .font(.system(size: Theme.FontSize.title, weight: .medium))
                            .foregroundColor(dimmed ? Theme.textMuted.opacity(0.5) : Theme.textPrimary)
                        if repo.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.system(size: Theme.FontSize.tiny))
                                .foregroundColor(Theme.textMuted.opacity(0.5))
                        }
                    }
                    if let desc = repo.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted.opacity(dimmed ? 0.4 : 0.7))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if dimmed {
                    Text("cloned")
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12).padding(.vertical, 8)
            .opacity(dimmed ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 4: Cloning

    private var cloningStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("⬇", "Cloning repos",
                       "This may take a minute depending on repo sizes and your connection.")

            if let state = store.onboardingClone {
                // Progress bar
                let progress = state.total > 0 ? Double(state.completed) / Double(state.total) : 0
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(state.completed) / \(state.total)")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted)
                        Spacer()
                        if !state.finished {
                            Spinner(color: Theme.purple, size: Theme.FontSize.heading, lineWidth: 1.5)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08))
                            RoundedRectangle(cornerRadius: 4).fill(Theme.purple)
                                .frame(width: geo.size.width * progress)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)
                }

                // Log
                if !state.log.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(state.log.enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: 6) {
                                Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: Theme.FontSize.small))
                                    .foregroundColor(entry.success ? Theme.green : Theme.red)
                                Text(entry.repo)
                                    .font(.system(size: Theme.FontSize.body, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text(entry.success ? "cloned" : "failed")
                                    .font(.system(size: Theme.FontSize.caption))
                                    .foregroundColor(entry.success ? Theme.textMuted : Theme.red)
                            }
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                }

                if state.finished {
                    let failures = state.log.filter { !$0.success }
                    if failures.isEmpty {
                        statusLine("All repos cloned successfully", ok: true)
                    } else {
                        statusLine("\(failures.count) clone\(failures.count == 1 ? "" : "s") failed — check SSH key access", ok: false)
                        note("Make sure your SSH key is added to GitHub and authorized for the org. Test with: ssh -T git@github.com")
                    }
                }
            } else {
                // Kick off cloning
                let root = workspaceDraft.isEmpty ? store.workspaceRoot : workspaceDraft
                let toClone = selectedOrgLogins.sorted()
                    .flatMap { store.orgRepos[$0] ?? [] }
                    .filter { selectedRepoIds.contains($0.id) }
                Button(action: { store.cloneSelectedRepos(toClone, into: root) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.on.square")
                        Text("Start Cloning \(toClone.count) Repo\(toClone.count == 1 ? "" : "s")")
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Theme.purple))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { beginCloning() }
    }

    private func beginCloning() {
        guard store.onboardingClone == nil else { return }
        let root = workspaceDraft.isEmpty ? store.workspaceRoot : workspaceDraft
        guard !root.isEmpty else { return }
        let toClone = selectedOrgLogins.sorted()
            .flatMap { store.orgRepos[$0] ?? [] }
            .filter { selectedRepoIds.contains($0.id) }
        guard !toClone.isEmpty else {
            store.onboardingClone = OnboardingCloneState(total: 0, completed: 0, log: [], finished: true)
            return
        }
        store.cloneSelectedRepos(toClone, into: root)
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🎉")
                .font(.system(size: 40))
            Text("You're all set!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("Your workspace is ready. Use the tabs to check PR status, environment health, and your tasks.")
                .font(.system(size: Theme.FontSize.heading))
                .foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                if !store.workspaceRoot.isEmpty {
                    statusLine("Workspace: \(store.workspaceRoot.replacingOccurrences(of: NSHomeDirectory(), with: "~"))", ok: true)
                }
                if !store.githubToken.isEmpty {
                    statusLine("GitHub connected", ok: true)
                }
                if let state = store.onboardingClone, state.finished {
                    let ok = state.log.filter { $0.success }.count
                    statusLine("\(ok) repo\(ok == 1 ? "" : "s") cloned", ok: true)
                }
            }

            note("You can add more repos, change the workspace folder, or connect Jira/Linear at any time in Settings.")
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step > 0 && !(step == 4 && store.onboardingClone != nil && store.onboardingClone?.finished == false) {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.plain)
                    .font(.system(size: Theme.FontSize.title))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()

            let label = nextLabel
            let disabled = isNextDisabled

            Button(action: advance) {
                Text(label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.purple.opacity(disabled ? 0.4 : 1)))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Theme.divider).frame(height: 1) }
    }

    private var nextLabel: String {
        switch step {
        case 0: return "Continue"
        case 1: return "Continue"
        case 2: return selectedOrgLogins.isEmpty ? "Skip" : "Continue (\(selectedOrgLogins.count))"
        case 3: return selectedRepoIds.isEmpty ? "Skip" : "Clone \(selectedRepoIds.count) Repo\(selectedRepoIds.count == 1 ? "" : "s")"
        case 4:
            guard let state = store.onboardingClone else { return "Continue" }
            return state.finished ? "Continue" : "Cloning…"
        default: return "Finish"
        }
    }

    private var isNextDisabled: Bool {
        switch step {
        case 4:
            guard let state = store.onboardingClone else { return false }
            return !state.finished
        default: return false
        }
    }

    // MARK: - Navigation

    private func advance() {
        switch step {
        case 0:
            // Save folder
            let root = workspaceDraft.isEmpty ? store.workspaceRoot : workspaceDraft
            if !root.isEmpty {
                store.workspaceRoot = root
                Defaults[.workspaceRoot] = root
            }
        case 1:
            let t = githubDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty {
                store.githubToken = t
                _ = Keychain.write("githubToken", t)
            }
        case 2:
            if selectedOrgLogins.isEmpty {
                finish(); return
            }
        case 3:
            // If skipping repos, jump to done
            if selectedRepoIds.isEmpty {
                finish()
                return
            }
            // Reset any prior clone state before entering step 4
            store.onboardingClone = nil
        case 5:
            finish()
            return
        default: break
        }
        withAnimation { step += 1 }
    }

    private func finish() {
        Defaults[.onboardingComplete] = true
        onDone()
    }

    // MARK: - Clipboard polling (unused in new flow but kept for future use)

    private func pollClipboardForToken() {
        guard step == 1, store.githubToken.isEmpty else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastPasteCount else { return }
        lastPasteCount = pb.changeCount
        guard let s = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              s.hasPrefix("ghp_") || s.hasPrefix("github_pat_") else { return }
        githubDraft = s
    }

    // MARK: - Small helpers

    private func stepHeader(_ emoji: String, _ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emoji).font(.system(size: 30))
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text(desc)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

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

    private func link(_ label: String, _ url: String) -> some View {
        Button(action: { NSWorkspace.shared.open(URL(string: url)!) }) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: Theme.FontSize.caption))
                Text(label)
                    .font(.system(size: Theme.FontSize.body, weight: .medium))
            }
            .foregroundColor(Theme.blue)
        }
        .buttonStyle(.plain)
    }

    private func statusLine(_ text: String, ok: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(ok ? Theme.green : Theme.red)
            Text(text)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.textMuted)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.FontSize.small))
            .foregroundColor(Theme.textMuted.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}
