import SwiftUI
import AppKit

struct AIPanel: View {
    @ObservedObject var store: Store
    @State private var installedTools: [AITool] = []
    @State private var hasClaudeMd = false
    @State private var hasAgentsMd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                contextSection
                toolsSection
                branchSection
                if AppConfig.current.ai?.server != nil { serverSection }
            }
            .padding(.top, 2).padding(.bottom, 12)
        }
        .onAppear {
            store.readCurrentBranch()
            installedTools = detectTools()
            scanInstructionFiles()
            if AppConfig.current.ai?.server != nil { store.checkAIServer() }
        }
    }

    // MARK: - Context section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Context")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: Theme.FontSize.small))
                        .foregroundColor(Theme.textMuted.opacity(0.6))
                    Text(workspaceName)
                        .font(.system(size: Theme.FontSize.body, design: .monospaced))
                        .foregroundColor(Theme.textPrimary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    fileChip("CLAUDE.md", present: hasClaudeMd)
                    fileChip("AGENTS.md", present: hasAgentsMd)
                    Spacer(minLength: 0)
                }
                Button(action: { store.copyWorkspaceContext() }) {
                    HStack(spacing: 6) {
                        Image(systemName: store.contextCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: Theme.FontSize.small, weight: .medium))
                        Text(store.contextCopied ? "Copied!" : "Copy context")
                            .font(.system(size: Theme.FontSize.body, weight: .medium))
                    }
                    .foregroundColor(store.contextCopied ? Theme.green : Theme.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(store.contextCopied ? Theme.green.opacity(0.10) : Theme.purple.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(store.contextCopied ? Theme.green.opacity(0.25) : Theme.purple.opacity(0.20), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func fileChip(_ name: String, present: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(present ? Theme.green : Theme.textMuted.opacity(0.3))
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: Theme.FontSize.tiny, weight: .medium, design: .monospaced))
                .foregroundColor(present ? Theme.textPrimary.opacity(0.7) : Theme.textMuted.opacity(0.4))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 5)
            .fill(present ? Color.white.opacity(0.06) : Color.white.opacity(0.03)))
    }

    // MARK: - Tools section

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Open with AI")
            if installedTools.isEmpty {
                Text("No AI editors detected.\nInstall Claude Code, Cursor, or VS Code.")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(installedTools) { tool in
                        ActionGridButton(
                            icon: tool.icon,
                            color: tool.color,
                            title: tool.label,
                            subtitle: tool.subtitle,
                            action: { launchTool(tool) }
                        )
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
    }

    // MARK: - Branch / ticket section

    @ViewBuilder
    private var branchSection: some View {
        let branch = store.currentBranch
        let trunks: Set<String> = ["main", "master", "development", "staging", "production", "HEAD", ""]
        if !trunks.contains(branch) {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Current branch")
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: Theme.FontSize.tiny, weight: .medium))
                            .foregroundColor(Theme.textMuted.opacity(0.5))
                        Text(branch)
                            .font(.system(size: Theme.FontSize.label, design: .monospaced))
                            .foregroundColor(Theme.textPrimary.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let id = store.currentBranchTicketId {
                        ticketRow(id: id)
                    }
                    Button(action: { store.copyPRPrompt() }) {
                        HStack(spacing: 6) {
                            Image(systemName: store.prPromptCopied ? "checkmark" : "doc.text")
                                .font(.system(size: Theme.FontSize.small, weight: .medium))
                            Text(store.prPromptCopied ? "Copied!" : "Copy PR prompt")
                                .font(.system(size: Theme.FontSize.body, weight: .medium))
                        }
                        .foregroundColor(store.prPromptCopied ? Theme.green : Theme.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(store.prPromptCopied ? Theme.green.opacity(0.10) : Theme.blue.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(store.prPromptCopied ? Theme.green.opacity(0.25) : Theme.blue.opacity(0.20), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func ticketRow(id: String) -> some View {
        let title: String? = {
            if AppConfig.current.linear != nil {
                return store.linearIssues.first { $0.identifier == id }?.title
            }
            return store.jiraTickets.first { $0.key == id }?.summary
        }()
        HStack(spacing: 6) {
            Text(id)
                .font(.system(size: Theme.FontSize.label, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.blue)
            if let title {
                Text("·")
                    .foregroundColor(Theme.textMuted.opacity(0.4))
                Text(title)
                    .font(.system(size: Theme.FontSize.label))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - Server section

    private var serverSection: some View {
        let cfg = AppConfig.current.ai?.server
        return VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Model server")
            HStack(spacing: 10) {
                serverStatusDot
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        serverStatusLabel
                        if let ms = store.aiServerLatency, store.aiServerStatus == .online {
                            Text("\(Int(ms))ms")
                                .font(.system(size: Theme.FontSize.tiny, design: .monospaced))
                                .foregroundColor(Theme.textMuted.opacity(0.5))
                        }
                    }
                    if let label = cfg?.label {
                        Text(label)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted.opacity(0.5))
                    }
                }
                Spacer(minLength: 0)
                Button(action: { store.checkAIServer() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: Theme.FontSize.small, weight: .medium))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .disabled(store.aiServerChecking)
            }
            .padding(.horizontal, 14).padding(.bottom, 12)
        }
    }

    private var serverStatusDot: some View {
        ZStack {
            Circle().fill(serverDotColor).frame(width: 8, height: 8)
            if store.aiServerStatus == .checking {
                Circle().stroke(serverDotColor.opacity(0.4), lineWidth: 1)
                    .frame(width: 14, height: 14)
            }
        }
    }

    private var serverDotColor: Color {
        switch store.aiServerStatus {
        case .online:   return Theme.green
        case .offline:  return Theme.red
        case .checking: return Theme.orange
        case .unknown:  return Theme.textMuted.opacity(0.3)
        }
    }

    @ViewBuilder
    private var serverStatusLabel: some View {
        switch store.aiServerStatus {
        case .online:
            Text(store.aiServerModel ?? "Online")
                .font(.system(size: Theme.FontSize.body, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textPrimary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
        case .offline:
            Text("Offline")
                .font(.system(size: Theme.FontSize.body, weight: .medium))
                .foregroundColor(Theme.red.opacity(0.8))
        case .checking:
            Text("Checking…")
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.textMuted)
        case .unknown:
            Text("—")
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.textMuted.opacity(0.5))
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: Theme.FontSize.tinyMd, weight: .semibold)).tracking(0.6)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var workspaceName: String {
        let root = store.workspaceRoot
        guard !root.isEmpty else { return "No workspace set" }
        return URL(fileURLWithPath: root).lastPathComponent
    }

    private func scanInstructionFiles() {
        let root = store.workspaceRoot
        guard !root.isEmpty else { return }
        let fm = FileManager.default
        hasClaudeMd  = fm.fileExists(atPath: root + "/CLAUDE.md")
        hasAgentsMd  = fm.fileExists(atPath: root + "/AGENTS.md")
    }

    // MARK: - AI tool detection

    private func detectTools() -> [AITool] {
        let fm = FileManager.default
        var tools: [AITool] = []

        // Claude Code CLI — check common install paths
        let claudePaths = [
            "/usr/local/bin/claude",
            NSHomeDirectory() + "/.claude/local/claude",
            NSHomeDirectory() + "/.local/bin/claude",
        ]
        if claudePaths.contains(where: { fm.fileExists(atPath: $0) }) {
            tools.append(AITool(id: "claude", label: "Claude Code", subtitle: "Open terminal", icon: "sparkles", color: Theme.purple))
        }

        if fm.fileExists(atPath: "/Applications/Cursor.app") {
            tools.append(AITool(id: "cursor", label: "Cursor", subtitle: "Open project", icon: "cursorarrow.rays", color: Theme.blue))
        }

        let vscodePath = ["/Applications/Visual Studio Code.app", "/Applications/Visual Studio Code - Insiders.app"]
            .first { fm.fileExists(atPath: $0) }
        if let path = vscodePath {
            let label = path.contains("Insiders") ? "VS Code Insiders" : "VS Code"
            tools.append(AITool(id: "vscode", label: label, subtitle: "Open project", icon: "chevron.left.forwardslash.chevron.right", color: Color(hex: "#0EA5E9")))
        }

        if fm.fileExists(atPath: "/Applications/Windsurf.app") {
            tools.append(AITool(id: "windsurf", label: "Windsurf", subtitle: "Open project", icon: "wind", color: Color(hex: "#10B981")))
        }

        if fm.fileExists(atPath: "/Applications/Zed.app") {
            tools.append(AITool(id: "zed", label: "Zed", subtitle: "Open project", icon: "bolt.fill", color: Color(hex: "#F59E0B")))
        }

        return tools
    }

    private func launchTool(_ tool: AITool) {
        let root = store.workspaceRoot.isEmpty ? NSHomeDirectory() : store.workspaceRoot
        switch tool.id {
        case "claude":
            store.openInTerminal(root)
        default:
            let appNames: [String: String] = [
                "cursor":   "Cursor",
                "vscode":   "Visual Studio Code",
                "windsurf": "Windsurf",
                "zed":      "Zed",
            ]
            guard let appName = appNames[tool.id] else { return }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", appName, root]
            try? proc.run()
        }
    }
}

// MARK: - AITool model

private struct AITool: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let icon: String
    let color: Color
}
