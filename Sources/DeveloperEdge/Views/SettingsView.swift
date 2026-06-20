import SwiftUI
import AppKit
import Defaults
import LaunchAtLogin

struct SettingsView: View {
    @ObservedObject var store: Store
    var dismiss: () -> Void

    @State private var githubTokenDraft = ""
    @State private var editingGithubToken = false
    @State private var savingGithubToken = false

    @State private var jiraEmailDraft = ""
    @State private var editingJiraEmail = false
    @State private var savingJiraEmail = false

    @State private var jiraTokenDraft = ""
    @State private var editingJiraToken = false
    @State private var savingJiraToken = false

    @State private var jiraIdDraft = ""
    @State private var editingJiraId = false
    @State private var savingJiraId = false

    @State private var clipboard: String? = nil
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "·"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            backBar
            Rectangle().fill(Theme.divider).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Workspace")
                    workspaceRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)

                    sectionHeader("Terminal")
                    terminalSection
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)

                    sectionHeader("GitHub")
                    githubTokenRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)

                    sectionHeader("Jira")
                    jiraEmailRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                    jiraTokenRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                    jiraAccountRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)

                    sectionHeader("Quick Links")
                    quickLinksSection
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)

                    sectionHeader("Slack Channels")
                    slackSection
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)

                    sectionHeader("App")
                    launchAtLoginRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)

                    Text("\(AppConfig.current.branding.appName) · v\(appVersion)")
                        .font(.system(size: Theme.FontSize.tinyMd))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 14)
                }
            }
        }
        .frame(height: 520)
        .onAppear {
            clipboard = NSPasteboard.general.string(forType: .string)
            store.autoDetectJiraEmail()
            guard let clip = clipboard, !clip.isEmpty else { return }
            if store.githubToken.isEmpty    { githubTokenDraft = clip; editingGithubToken = true }
            if store.jiraApiToken.isEmpty   { jiraTokenDraft = clip;   editingJiraToken = true }
            if store.jiraAccountId.isEmpty  { jiraIdDraft = clip;      editingJiraId = true }
        }
    }

    // MARK: - Back bar

    private var backBar: some View {
        ZStack {
            Text("Settings")
                .font(.system(size: Theme.FontSize.heading, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: dismiss) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: Theme.FontSize.small, weight: .semibold))
                        Text("Back")
                            .font(.system(size: Theme.FontSize.title, weight: .medium))
                    }
                    .foregroundColor(Theme.textMuted)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Workspace row

    private var workspaceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("Workspace")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            Text(store.workspaceRoot.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                .font(.system(size: Theme.FontSize.label, design: .monospaced))
                .foregroundColor(Theme.textPrimary.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: { store.openInTerminal(store.workspaceRoot) }) {
                Image(systemName: "terminal")
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(Theme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Open workspace in terminal")
            .accessibilityLabel("Open workspace in terminal")
            Button("Change") { store.selectWorkspace() }
                .buttonStyle(.plain)
                .font(.system(size: Theme.FontSize.label))
                .foregroundColor(Theme.purple)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Terminal section

    private var terminalSection: some View {
        let installed = store.installedTerminals
        let current = installed.first { $0.id == store.defaultTerminal } ?? installed[0]
        return HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("Default")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Menu {
                ForEach(installed) { term in
                    Button(action: {
                        store.defaultTerminal = term.id
                        Defaults[.defaultTerminal] = term.id
                    }) {
                        if store.defaultTerminal == term.id {
                            Label(term.name, systemImage: "checkmark")
                        } else {
                            Text(term.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(current.name)
                        .font(.system(size: Theme.FontSize.label, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: Theme.FontSize.tiny, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - GitHub token row

    private var githubTokenRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.horizontal")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("PAT")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            if editingGithubToken {
                TextField("ghp_…", text: $githubTokenDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .onSubmit { saveGithubToken() }
                    .contextMenu {
                        Button("Paste") {
                            if let s = NSPasteboard.general.string(forType: .string) {
                                githubTokenDraft = s
                            }
                        }
                    }
            } else {
                Text(store.githubToken.isEmpty
                     ? "Not set · pipeline status hidden"
                     : String(repeating: "•", count: min(store.githubToken.count, 20)))
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(store.githubToken.isEmpty
                                     ? Theme.textMuted.opacity(0.4)
                                     : Theme.textPrimary.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            fieldAction(
                currentValue: store.githubToken,
                isEditing: editingGithubToken,
                isSaving: savingGithubToken,
                draft: githubTokenDraft,
                onSet:    { githubTokenDraft = ""; editingGithubToken = true },
                onPaste:  { githubTokenDraft = clipboard ?? ""; editingGithubToken = true },
                onSave:   { saveGithubToken() },
                onChange: { githubTokenDraft = store.githubToken; editingGithubToken = true }
            )
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func saveGithubToken() {
        let trimmed = githubTokenDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { editingGithubToken = false; return }
        editingGithubToken = false
        savingGithubToken = true
        store.githubToken = trimmed
        Defaults[.githubToken] = trimmed
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { savingGithubToken = false }
        }
    }

    // MARK: - Jira rows

    private var jiraEmailRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("Email")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            if editingJiraEmail {
                TextField("you@company.com", text: $jiraEmailDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .onSubmit { saveJiraEmail() }
            } else {
                Text(store.jiraEmail.isEmpty ? "Auto-detecting from git config…" : store.jiraEmail)
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(store.jiraEmail.isEmpty ? Theme.textMuted.opacity(0.4) : Theme.textPrimary.opacity(0.6))
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            fieldAction(
                currentValue: store.jiraEmail, isEditing: editingJiraEmail, isSaving: savingJiraEmail, draft: jiraEmailDraft,
                onSet:    { jiraEmailDraft = ""; editingJiraEmail = true },
                onPaste:  { jiraEmailDraft = clipboard ?? ""; editingJiraEmail = true },
                onSave:   { saveJiraEmail() },
                onChange: { jiraEmailDraft = store.jiraEmail; editingJiraEmail = true }
            )
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func saveJiraEmail() {
        let trimmed = jiraEmailDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { editingJiraEmail = false; return }
        editingJiraEmail = false; savingJiraEmail = true
        store.jiraEmail = trimmed
        Defaults[.jiraEmail] = trimmed
        Task { try? await Task.sleep(nanoseconds: 500_000_000); await MainActor.run { savingJiraEmail = false } }
    }

    private var jiraTokenRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.horizontal")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("API Token")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            if editingJiraToken {
                TextField("atatt3x…", text: $jiraTokenDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .onSubmit { saveJiraToken() }
            } else {
                Text(store.jiraApiToken.isEmpty
                     ? "Not set · required for tickets"
                     : String(repeating: "•", count: min(store.jiraApiToken.count, 20)))
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(store.jiraApiToken.isEmpty ? Theme.textMuted.opacity(0.4) : Theme.textPrimary.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            fieldAction(
                currentValue: store.jiraApiToken, isEditing: editingJiraToken, isSaving: savingJiraToken, draft: jiraTokenDraft,
                onSet:    { jiraTokenDraft = ""; editingJiraToken = true },
                onPaste:  { jiraTokenDraft = clipboard ?? ""; editingJiraToken = true },
                onSave:   { saveJiraToken() },
                onChange: { jiraTokenDraft = store.jiraApiToken; editingJiraToken = true }
            )
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func saveJiraToken() {
        let trimmed = jiraTokenDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { editingJiraToken = false; return }
        editingJiraToken = false; savingJiraToken = true
        store.jiraApiToken = trimmed
        Defaults[.jiraApiToken] = trimmed
        store.fetchJiraDisplayName()
        Task { try? await Task.sleep(nanoseconds: 500_000_000); await MainActor.run { savingJiraToken = false } }
    }

    private var jiraAccountRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("Jira ID")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            if editingJiraId {
                TextField("Paste account ID…", text: $jiraIdDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .onSubmit { saveJiraId() }
                    .contextMenu {
                        Button("Paste") {
                            if let s = NSPasteboard.general.string(forType: .string) {
                                jiraIdDraft = s
                            }
                        }
                    }
            } else {
                Text(store.jiraAccountId.isEmpty
                     ? "Not set · board filter falls back to JQL"
                     : store.jiraAccountId)
                    .font(.system(size: Theme.FontSize.label, design: .monospaced))
                    .foregroundColor(store.jiraAccountId.isEmpty
                                     ? Theme.textMuted.opacity(0.4)
                                     : Theme.textPrimary.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            fieldAction(
                currentValue: store.jiraAccountId,
                isEditing: editingJiraId,
                isSaving: savingJiraId,
                draft: jiraIdDraft,
                onSet:    { jiraIdDraft = ""; editingJiraId = true },
                onPaste:  { jiraIdDraft = clipboard ?? ""; editingJiraId = true },
                onSave:   { saveJiraId() },
                onChange: { jiraIdDraft = store.jiraAccountId; editingJiraId = true }
            )
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private func saveJiraId() {
        let trimmed = jiraIdDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { editingJiraId = false; return }
        editingJiraId = false
        savingJiraId = true
        store.jiraAccountId = trimmed
        Defaults[.jiraAccountId] = trimmed
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { savingJiraId = false }
        }
    }

    // MARK: - Shared field action button

    @ViewBuilder
    private func fieldAction(
        currentValue: String,
        isEditing: Bool,
        isSaving: Bool,
        draft: String,
        onSet: @escaping () -> Void,
        onPaste: @escaping () -> Void,
        onSave: @escaping () -> Void,
        onChange: @escaping () -> Void
    ) -> some View {
        if isSaving {
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 40, height: 16)
        } else if isEditing {
            Button("Save") { onSave() }
                .buttonStyle(.plain)
                .font(.system(size: Theme.FontSize.label, weight: .semibold))
                .foregroundColor(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                 ? Theme.textMuted.opacity(0.35)
                                 : Theme.green)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        } else if currentValue.isEmpty {
            let hasClip = !(clipboard ?? "").isEmpty
            Button(hasClip ? "Paste" : "Set") {
                if hasClip { onPaste() } else { onSet() }
            }
            .buttonStyle(.plain)
            .font(.system(size: Theme.FontSize.label, weight: hasClip ? .medium : .regular))
            .foregroundColor(hasClip ? Theme.purple : Theme.textMuted.opacity(0.35))
        } else {
            Button("Change") { onChange() }
                .buttonStyle(.plain)
                .font(.system(size: Theme.FontSize.label))
                .foregroundColor(Theme.purple)
        }
    }

    // MARK: - Quick Links

    private var quickLinksSection: some View {
        VStack(spacing: 1) {
            ForEach(allQuickLinks, id: \.id) { link in
                let enabled = store.enabledQuickLinks.contains(link.id)
                Button(action: {
                    guard !link.mandatory else { return }
                    var updated = store.enabledQuickLinks
                    if enabled { updated.remove(link.id) } else { updated.insert(link.id) }
                    store.enabledQuickLinks = updated
                    Defaults[.enabledQuickLinks] = updated
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(enabled ? link.color : Color.white.opacity(0.06))
                                .frame(width: 18, height: 18)
                            if enabled {
                                Image(systemName: "checkmark")
                                    .font(.system(size: Theme.FontSize.caption, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Image(systemName: link.icon)
                            .font(.system(size: Theme.FontSize.small))
                            .foregroundColor(enabled ? link.color : Theme.textMuted.opacity(0.5))
                            .frame(width: 14)
                        Text(link.title)
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                            .foregroundColor(enabled ? Theme.textPrimary : Theme.textMuted.opacity(0.6))
                        Spacer()
                        if link.mandatory {
                            Text("always on")
                                .font(.system(size: Theme.FontSize.tinyMd))
                                .foregroundColor(Theme.textMuted.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.03))
                if link.id != allQuickLinks.last?.id {
                    Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 12)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Slack section (2-column)

    private var slackSection: some View {
        let atMax = store.enabledSlackChannels.count >= 3
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(allSlackChannels) { ch in
                let enabled = store.enabledSlackChannels.contains(ch.id)
                Button(action: {
                    guard enabled || !atMax else { return }
                    var updated = store.enabledSlackChannels
                    if enabled { updated.remove(ch.id) } else { updated.insert(ch.id) }
                    store.enabledSlackChannels = updated
                    Defaults[.enabledSlackChannels] = updated
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(enabled ? ch.color : Color.white.opacity(0.06))
                                .frame(width: 16, height: 16)
                            if enabled {
                                Image(systemName: "checkmark")
                                    .font(.system(size: Theme.FontSize.tiny, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        Image(systemName: ch.icon)
                            .font(.system(size: Theme.FontSize.small))
                            .foregroundColor(enabled ? ch.color : Theme.textMuted.opacity(0.5))
                            .frame(width: 14)
                        Text(ch.title)
                            .font(.system(size: Theme.FontSize.small, weight: .medium))
                            .foregroundColor(enabled ? Theme.textPrimary : Theme.textMuted.opacity(0.6))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(enabled ? ch.color.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.5))
                    .contentShape(Rectangle())
                    .opacity(!enabled && atMax ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(!enabled && atMax)
            }
        }
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }

    // MARK: - Launch at login row

    private var launchAtLoginRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "power")
                .font(.system(size: Theme.FontSize.small))
                .foregroundColor(Theme.textMuted)
                .frame(width: 14)
            Text("Launch at login")
                .font(.system(size: Theme.FontSize.label, weight: .medium))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.purple)
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

}
