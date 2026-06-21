import AppKit
import Defaults

extension Store {
    func runGitFetchAll() {
        guard !fetchRunning else { return }

        // Fresh install: no workspace yet. Running a process against a missing
        // directory throws and shows a confusing "Failed"; guide the user instead.
        guard isWorkspaceSetUp else {
            fetchOutput = "No workspace yet.\nRun \"Setup Workspace\" first to clone the repos, then come back here."
            fetchExitCode = nil
            return
        }

        fetchRunning = true
        fetchOutput = ""
        fetchExitCode = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let scriptURL = Bundle.main.url(forResource: "git_fetch_all", withExtension: "sh") else {
                DispatchQueue.main.async {
                    self.fetchOutput = "Error: git_fetch_all.sh not found in app bundle"
                    self.fetchExitCode = -1
                    self.fetchRunning = false
                }
                return
            }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [scriptURL.path]
            proc.currentDirectoryURL = URL(fileURLWithPath: self.workspaceRoot)

            proc.environment = ProcessEnv.git()

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let raw = String(data: handle.availableData, encoding: .utf8) ?? ""
                let clean = raw.replacingOccurrences(of: #"\x1B\[[0-9;]*[mK]"#, with: "", options: .regularExpression)
                guard !clean.isEmpty else { return }
                DispatchQueue.main.async { self.fetchOutput += clean }
            }
            do { try proc.run() } catch {
                DispatchQueue.main.async {
                    self.fetchOutput = "Error: \(error.localizedDescription)"
                    self.fetchExitCode = -1
                    self.fetchRunning = false
                }
                return
            }
            proc.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self.fetchExitCode = proc.terminationStatus
                self.fetchRunning = false
                if proc.terminationStatus == 0 {
                    let now = Date()
                    self.lastFetchDate = now
                    Defaults[.lastFetchDate] = now
                }
            }
        }
    }

    var installedTerminals: [TerminalApp] {
        let found = allTerminals.filter(\.isInstalled)
        return found.isEmpty ? [allTerminals[0]] : found  // Terminal.app is always present
    }

    /// Opens the given directory in the user's chosen terminal (falls back to Terminal.app).
    func openInTerminal(_ path: String) {
        let term = installedTerminals.first { $0.id == defaultTerminal } ?? installedTerminals[0]
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-a", term.name, path]
        try? proc.run()
    }

    /// Opens the given directory in the user's preferred editor.
    /// Tries Cursor → VS Code → Finder, picking whichever is installed.
    func openInEditor(_ path: String) {
        let fm = FileManager.default
        let editors = [
            "/Applications/Visual Studio Code - Insiders.app",
            "/Applications/Visual Studio Code.app",
            "/Applications/Cursor.app",
            "/Applications/Sublime Text.app",
        ]
        if let app = editors.first(where: { fm.fileExists(atPath: $0) }) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", app, path]
            try? proc.run()
            return
        }
        // Fallback: reveal in Finder if no editor is installed.
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func openLens() {
        guard !lensRunning else { return }
        lensRunning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let cmds = clusters.map(\.credentialCommand).joined(separator: " && ")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", cmds]
            proc.environment = ProcessEnv.base()
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            DispatchQueue.main.async {
                self?.lensRunning = false
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Lens.app"))
            }
        }
    }

    func selectWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select your repos workspace folder"
        panel.prompt = "Select"
        if !workspaceRoot.isEmpty,
           FileManager.default.fileExists(atPath: workspaceRoot) {
            panel.directoryURL = URL(fileURLWithPath: workspaceRoot)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.level = .modalPanel
        if panel.runModal() == .OK, let url = panel.url {
            workspaceRoot = url.path
            Defaults[.workspaceRoot] = url.path
            repos = []
            repoPickerShown = false
        }
    }

    func scanRepos() {
        let fm = FileManager.default
        let root = workspaceRoot
        let aiRepo = AppConfig.current.workspace.aiInstructionsRepo
        let aiRoot = aiRepo.map { root + "/" + $0 }
        var found: [RepoInfo] = []
        let searchRoots = [root] + AppConfig.current.workspace.subfolders.map { root + "/" + $0 }
        for searchRoot in searchRoots {
            guard let entries = try? fm.contentsOfDirectory(atPath: searchRoot) else { continue }
            for entry in entries.sorted() {
                let full = searchRoot + "/" + entry
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: full, isDirectory: &isDir), isDir.boolValue else { continue }
                guard fm.fileExists(atPath: full + "/.git") else { continue }
                guard entry != aiRepo else { continue }
                let hasLink = fm.fileExists(atPath: full + "/CLAUDE.md")
                    || fm.fileExists(atPath: full + "/AGENTS.md")
                let hasInstructions = aiRoot.map { fm.fileExists(atPath: $0 + "/repos/\(entry).md") } ?? false
                found.append(RepoInfo(name: entry, path: full, hasLink: hasLink, hasInstructions: hasInstructions))
            }
        }
        DispatchQueue.main.async { self.repos = found }
    }

    func setupAIInstructions(_ repo: RepoInfo) {
        guard !aiSetupRunning else { return }
        aiSetupRunning = true
        aiSetupOutput = ""
        aiSetupExitCode = nil
        selectedRepo = repo

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let aiRepo = AppConfig.current.workspace.aiInstructionsRepo ?? ""
            let linkScript = self.workspaceRoot + "/" + aiRepo + "/scripts/link.sh"
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [linkScript, repo.name]
            proc.currentDirectoryURL = URL(fileURLWithPath: repo.path)
            proc.environment = ProcessEnv.base()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let raw = String(data: handle.availableData, encoding: .utf8) ?? ""
                guard !raw.isEmpty else { return }
                DispatchQueue.main.async { self.aiSetupOutput += raw }
            }
            do { try proc.run() } catch {
                DispatchQueue.main.async {
                    self.aiSetupOutput = "Error: \(error.localizedDescription)"
                    self.aiSetupExitCode = -1
                    self.aiSetupRunning = false
                }
                return
            }
            proc.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self.aiSetupExitCode = proc.terminationStatus
                self.aiSetupRunning = false
                self.scanRepos()
            }
        }
    }
}
