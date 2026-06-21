import SwiftUI

struct DevelopmentPanel: View {
    @ObservedObject var store: Store
    @State private var editingPortRepo: String? = nil
    @State private var portDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {


                // ── Dev Tools ─────────────────────────────────────────────
                sectionHeader("Dev Tools")
                devToolsSection
                    .padding(.horizontal, 14).padding(.bottom, 4)

                // ── Links (quick links) ───────────────────────────────────
                let items = allQuickLinks
                    .filter { store.enabledQuickLinks.contains($0.id) }
                    .map { GridButtonData(icon: $0.icon, color: $0.color, title: $0.title, subtitle: $0.subtitle, url: $0.url) }
                if !items.isEmpty {
                    sectionHeader("Links")
                    VStack(spacing: 8) {
                        ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { i in
                            gridRow(Array(items[i..<min(i + 2, items.count)]))
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 4)
                }

                // ── Localhost ─────────────────────────────────────────────
                localhostSectionHeader
                localhostSection
                    .padding(.bottom, 14)
            }
            .padding(.top, 2)
        }
        .onAppear {
            store.checkLocalhostHealth()
            store.scanLocalListeners()
            if store.repos.isEmpty { store.scanRepos() }
            store.checkAIInstructionsUpdate()
            store.checkForNewRepos()
        }
    }

    // MARK: - Dev Tools

    @ViewBuilder
    private var devToolsSection: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ActionGridButton(
                    icon: "arrow.triangle.2.circlepath", color: Theme.green,
                    title: "Git Fetch All", subtitle: fetchSubtitle,
                    running: store.fetchRunning,
                    statusText: store.fetchRunning ? nil
                        : store.fetchExitCode == nil ? nil
                        : store.fetchExitCode == 0 ? "Done ✓" : "Failed ✗",
                    statusColor: store.fetchExitCode == 0 ? Theme.green : Theme.red,
                    alert: store.isFetchStale && store.fetchExitCode == nil,
                    action: { store.runGitFetchAll() }
                )
                ActionGridButton(
                    icon: "square.3.layers.3d", color: Theme.purple,
                    title: "Open Lens", subtitle: "Kubeconfig + Lens",
                    running: store.lensRunning,
                    action: { store.openLens() }
                )
                ActionGridButton(
                    icon: setupIcon, color: Theme.purple,
                    title: setupTitle,
                    subtitle: setupSubtitle,
                    running: store.setupRunning || store.aiInstructionsUpdating,
                    statusText: (store.setupRunning || store.aiInstructionsUpdating) ? nil
                        : store.setupExitCode == nil ? nil
                        : store.setupExitCode == 0 ? "Done ✓" : "Failed ✗",
                    statusColor: store.setupExitCode == 0 ? Theme.green : Theme.red,
                    alert: store.aiUpdateAvailable || !store.newReposAvailable.isEmpty,
                    action: { setupAction() }
                )
                ActionGridButton(
                    icon: "point.3.connected.trianglepath.dotted",
                    color: graphButtonColor,
                    title: graphBuildTitle,
                    subtitle: graphButtonSubtitle,
                    running: store.graphBuildRunning || store.graphInstallRunning,
                    statusText: graphStatusText,
                    statusColor: graphStatusColor,
                    alert: store.graphToolState == .notInstalled,
                    action: {
                        switch store.graphToolState {
                        case .notInstalled:
                            store.graphInstallOutput = ""
                            store.graphInstallExitCode = nil
                            store.installGraphTool()
                        case .installed:
                            store.runCodeReviewGraph()
                        case .unknown:
                            store.checkGraphToolInstalled()
                        }
                    }
                )
            }
            if !store.fetchOutput.isEmpty {
                OutputConsole(output: store.fetchOutput, running: store.fetchRunning,
                              onClose: { store.fetchOutput = "" })
            }
            if !store.setupOutput.isEmpty {
                OutputConsole(output: store.setupOutput, running: store.setupRunning,
                              onClose: { store.setupOutput = "" })
            }
            if !store.graphBuildOutput.isEmpty {
                OutputConsole(output: store.graphBuildOutput, running: store.graphBuildRunning,
                              onClose: { store.graphBuildOutput = "" })
            }
            if !store.graphInstallOutput.isEmpty {
                OutputConsole(output: store.graphInstallOutput, running: store.graphInstallRunning,
                              onClose: { store.graphInstallOutput = "" })
            }
        }
    }

    // MARK: - Localhost

    @ViewBuilder
    private var localhostSectionHeader: some View {
        HStack {
            Text("LOCALHOST")
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
            if store.scanningListeners {
                Spinner(size: Theme.FontSize.title, lineWidth: 1.5).frame(width: 16, height: 16)
            } else {
                let count = store.localListeners.count
                if count > 0 {
                    Text("\(count) running")
                        .font(.system(size: Theme.FontSize.tinyMd, weight: .medium))
                        .foregroundColor(Theme.green)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.green.opacity(0.12)))
                }
                Button(action: { store.scanLocalListeners() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(Theme.textMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Rescan local listeners")
                .accessibilityLabel("Rescan local listeners")
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }

    @ViewBuilder
    private var localhostSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.services.enumerated()), id: \.element.id) { i, svc in
                localhostRow(svc)
                if i < store.services.count - 1 {
                    Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func localhostRow(_ svc: ZService) -> some View {
        let port = store.localhostPorts[svc.repo]
        let baseURL = port.map { "http://localhost:\($0)" }
        let status = baseURL.flatMap { store.localhostStatuses[$0] } ?? .unknown
        let isEditingThisPort = editingPortRepo == svc.repo
        let assignedPorts = Set(store.localhostPorts.values)
        let suggestions = store.localListeners.filter {
            $0.port != port && !assignedPorts.contains($0.port)
        }

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: svc.icon)
                    .font(.system(size: Theme.FontSize.title, weight: .medium))
                    .foregroundColor(port != nil ? Theme.textPrimary : Theme.textMuted.opacity(0.4))
                    .frame(width: 18)

                Text(svc.name)
                    .font(.system(size: Theme.FontSize.title, weight: .medium))
                    .foregroundColor(port != nil ? Theme.textPrimary : Theme.textMuted.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isEditingThisPort {
                    TextField("e.g. 3001", text: $portDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: Theme.FontSize.small, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 72)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.blue.opacity(0.5), lineWidth: 1))
                        .onSubmit { savePort(for: svc.repo) }
                    Button("Save") { savePort(for: svc.repo) }
                        .buttonStyle(.plain)
                        .font(.system(size: Theme.FontSize.label, weight: .semibold))
                        .foregroundColor(portDraft.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? Theme.textMuted.opacity(0.35) : Theme.green)
                } else {
                    if let port {
                        Circle()
                            .fill(status == .up ? Theme.green : status == .down ? Theme.red : Theme.textMuted.opacity(0.3))
                            .frame(width: 7, height: 7)
                        Button(action: { startEditingPort(svc.repo, current: port) }) {
                            Text(":\(port)")
                                .font(.system(size: Theme.FontSize.label, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.blue)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.blue.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        Button(action: { openLocalhost(svc) }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: Theme.FontSize.small))
                                .foregroundColor(Theme.textMuted.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .help("Open localhost in browser")
                        .accessibilityLabel("Open localhost in browser")
                    } else {
                        Button(action: { startEditingPort(svc.repo, current: nil) }) {
                            Text("set port")
                                .font(.system(size: Theme.FontSize.label))
                                .foregroundColor(Theme.textMuted.opacity(0.35))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)

            // Suggestions row shown while editing
            if isEditingThisPort && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions.prefix(6)) { listener in
                            Button(action: {
                                portDraft = String(listener.port)
                            }) {
                                VStack(spacing: 1) {
                                    Text(":\(listener.port)")
                                        .font(.system(size: Theme.FontSize.label, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Theme.textPrimary)
                                    Text(listener.processName)
                                        .font(.system(size: Theme.FontSize.tiny, weight: .regular))
                                        .foregroundColor(Theme.textMuted)
                                }
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(portDraft == String(listener.port)
                                          ? Theme.blue.opacity(0.18)
                                          : Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(portDraft == String(listener.port)
                                            ? Theme.blue.opacity(0.4)
                                            : Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14).padding(.bottom, 8)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func startEditingPort(_ repo: String, current: Int?) {
        portDraft = current.map { String($0) } ?? ""
        editingPortRepo = repo
    }

    private func savePort(for repo: String) {
        let trimmed = portDraft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            store.setLocalhostPort(nil, for: repo)
        } else if let port = Int(trimmed), port > 0, port < 65536 {
            store.setLocalhostPort(port, for: repo)
            store.checkLocalhostHealth()
        }
        editingPortRepo = nil
        portDraft = ""
    }

    private func openLocalhost(_ svc: ZService) {
        guard let port = store.localhostPorts[svc.repo],
              let url = URL(string: "http://localhost:\(port)") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Dev tool helpers (same computed props as before)

    private var fetchSubtitle: String {
        if let d = store.lastFetchDate {
            let fmt = RelativeDateTimeFormatter()
            fmt.unitsStyle = .abbreviated
            let rel = fmt.localizedString(for: d, relativeTo: Date())
            return store.isFetchStale ? "\(rel) · needs sync" : "Last fetched \(rel)"
        }
        return "Fetch, pull & prune all repos"
    }

    private var setupIcon: String {
        if !store.newReposAvailable.isEmpty { return "icloud.and.arrow.down.fill" }
        if store.aiUpdateAvailable { return "arrow.down.circle.fill" }
        if store.setupExitCode == 0 || store.isWorkspaceSetUp { return "folder.fill" }
        return "square.and.arrow.down.on.square"
    }

    private var setupTitle: String {
        if store.setupRunning { return "Cloning \(store.setupCloned)/\(store.setupTotal)" }
        if store.aiInstructionsUpdating { return "Updating AI…" }
        if !store.newReposAvailable.isEmpty { return "Download New Repos" }
        if store.aiUpdateAvailable { return "Update AI Instructions" }
        if store.setupExitCode == 0 || store.isWorkspaceSetUp { return "Open Workspace" }
        return "Setup Workspace"
    }

    private var setupSubtitle: String {
        if store.setupRunning { return "Cloning repos…" }
        if store.aiInstructionsUpdating { return "Pulling \(AppConfig.current.workspace.aiInstructionsRepo ?? "AI instructions")" }
        if !store.newReposAvailable.isEmpty {
            let n = store.newReposAvailable.count
            return "\(n) new \(n == 1 ? "repo" : "repos") · access granted"
        }
        if store.aiUpdateAvailable { return "Pull available for AI instructions" }
        if store.setupExitCode == 0 || store.isWorkspaceSetUp { return "Workspace ready · open it" }
        return "Clone all repos"
    }

    private func setupAction() {
        if !store.newReposAvailable.isEmpty {
            store.downloadNewRepos()
        } else if store.aiUpdateAvailable {
            store.updateAIInstructions()
        } else if store.setupExitCode == 0 || store.isWorkspaceSetUp {
            store.openInEditor(store.workspaceRoot)
        } else {
            store.selectParentAndSetup()
        }
    }

    private var graphBuildTitle: String {
        if store.graphInstallRunning { return "Installing..." }
        if store.graphBuildRunning {
            return "Building \(store.graphBuildProgress)/\(store.graphBuildTotal)"
        }
        switch store.graphToolState {
        case .notInstalled: return "Install Graph"
        case .installed:    return "Review Graph"
        case .unknown:      return "Review Graph"
        }
    }

    private var graphButtonSubtitle: String {
        if store.graphInstallRunning { return "Installing..." }
        switch store.graphToolState {
        case .notInstalled: return "Not installed"
        case .installed:
            if store.graphBuildRunning { return "Building graphs across all repos…" }
            if let code = store.graphBuildExitCode {
                if code == 0 { return "All \(store.graphBuildTotal) repos built ✓" }
                let n = store.graphBuildFailures.count
                return "\(n) failed of \(store.graphBuildTotal)"
            }
            return "Pull + build graphs across all repos"
        case .unknown: return "Checking..."
        }
    }

    private var graphButtonColor: Color {
        store.graphToolState == .notInstalled ? Theme.orange : Theme.blue
    }

    private var graphStatusText: String? {
        if store.graphInstallRunning { return "Installing..." }
        if store.graphBuildRunning   { return "Running..." }
        if let code = store.graphInstallExitCode { return code == 0 ? "Installed ✓" : "Install failed ✗" }
        if let code = store.graphBuildExitCode {
            if code == 0 { return "Built ✓" }
            let n = store.graphBuildFailures.count
            return "\(n) failed ✗"
        }
        return nil
    }

    private var graphStatusColor: Color {
        if store.graphInstallExitCode == 0 && store.graphBuildExitCode == nil { return Theme.green }
        if store.graphInstallExitCode != nil && store.graphInstallExitCode != 0 { return Theme.red }
        if let code = store.graphBuildExitCode { return code == 0 ? Theme.green : Theme.red }
        return Theme.green
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func gridRow(_ items: [GridButtonData]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(items) { item in GridButton(data: item) }
        }
    }

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
}
