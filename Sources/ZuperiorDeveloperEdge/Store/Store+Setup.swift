import AppKit
import Defaults

extension Store {
    /// Picks a parent folder (default ~/Developer/Projects) then bootstraps the
    /// whole Zuperior workspace inside it.
    func selectParentAndSetup() {
        guard !setupRunning else { return }
        guard !githubToken.isEmpty else {
            setupOutput = "Set your GitHub token in Settings first · it's needed to list the org's repos.\n"
            setupExitCode = -1
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Pick your workspace folder, or a parent to create Zuperior/ in"
        panel.message = "An existing folder with repos will be scanned and reorganized."
        panel.prompt = "Use Folder"
        let defaultParent = NSHomeDirectory() + "/Developer/Projects"
        if FileManager.default.fileExists(atPath: defaultParent) {
            panel.directoryURL = URL(fileURLWithPath: defaultParent)
        }
        // The menu-bar window resigns key when the panel opens; activate so the
        // open panel reliably comes to the front for the user.
        NSApp.activate(ignoringOtherApps: true)
        panel.level = .modalPanel
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // If they picked a folder that already holds repos, adopt it as the root;
        // otherwise create a fresh Zuperior/ inside the chosen parent.
        let picked = url.path
        let root = looksLikeWorkspace(picked) ? picked : picked + "/Zuperior"
        setupWorkspace(root: root)
    }

    /// Heuristic: does this folder already look like a (possibly messy) workspace?
    /// It must contain a configured subfolder, the AI-instructions repo, or a repo
    /// matching the configured prefix · so a stray unrelated folder isn't adopted.
    private func looksLikeWorkspace(_ path: String) -> Bool {
        let fm = FileManager.default
        for sub in AppConfig.current.workspace.subfolders where fm.fileExists(atPath: path + "/" + sub) {
            return true
        }
        if let ai = AppConfig.current.workspace.aiInstructionsRepo,
           fm.fileExists(atPath: path + "/" + ai) { return true }
        if AppConfig.current.github.hasPrefix,
           let entries = try? fm.contentsOfDirectory(atPath: path),
           entries.contains(where: { AppConfig.current.github.matches($0) }) { return true }
        return false
    }

    /// Moves any matching git repos already on disk (flat at root or in the wrong
    /// subfolder) into the correct subfolder per the configured rules.
    private func reorganizeExisting(root: String) {
        let fm = FileManager.default
        let searchDirs = [root] + AppConfig.current.workspace.subfolders.map { root + "/" + $0 }
        var moved = 0
        for dir in searchDirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where AppConfig.current.github.subfolder(for: entry) != nil {
                let current = dir + "/" + entry
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: current, isDirectory: &isDir), isDir.boolValue,
                      fm.fileExists(atPath: current + "/.git") else { continue }
                let correct = self.destPath(root: root, repo: entry)
                guard current != correct, !fm.fileExists(atPath: correct) else { continue }
                try? fm.createDirectory(atPath: (correct as NSString).deletingLastPathComponent,
                                        withIntermediateDirectories: true)
                do {
                    try fm.moveItem(atPath: current, toPath: correct)
                    self.appendSetup("↪ moved \(entry) into \((correct as NSString).deletingLastPathComponent.components(separatedBy: "/").last ?? "")/\n")
                    moved += 1
                } catch { /* leave in place on failure */ }
            }
        }
        if moved > 0 { self.appendSetup("Reorganized \(moved) existing \(moved == 1 ? "repo" : "repos").\n\n") }
    }

    /// Clones any missing td-* repos into an already-configured workspace
    /// (no folder picker). Used by the "Download new repos" button.
    func downloadNewRepos() {
        setupWorkspace(root: workspaceRoot)
    }

    /// Creates Zuperior/{Frontend,Backend,Mobile,DevOps}, clones every td-* repo
    /// the account can see (over SSH) into the right subfolder, then links AGENTS.md.
    /// Idempotent · existing repos are skipped.
    func setupWorkspace(root: String) {
        guard !setupRunning else { return }
        setupRunning = true
        setupOutput = "Listing repos from GitHub…\n"   // immediate feedback so the console shows at once
        setupExitCode = nil
        setupCloned = 0
        setupTotal = 0

        let token = githubToken
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let org = AppConfig.current.github.org
            var status = 0
            let repos = self.fetchOrgRepoNames(token: token, status: &status)
                .filter { AppConfig.current.github.matches($0) }
                .sorted()
            guard !repos.isEmpty else {
                let msg: String
                switch status {
                case 401: msg = "GitHub rejected the token (401). Re-check your PAT in Settings."
                case 403: msg = "GitHub returned 403. Your token likely needs SSO authorization for the \(org) org (Settings → token → Configure SSO)."
                case 200: msg = "No matching repos visible to this token. Make sure it has repo + read:org access to \(org)."
                default:  msg = "Could not reach GitHub (status \(status)). Check your network and token."
                }
                self.appendSetup("\n" + msg + "\n")
                DispatchQueue.main.async { self.setupExitCode = -1; self.setupRunning = false }
                return
            }
            DispatchQueue.main.async { self.setupTotal = repos.count }

            let fm = FileManager.default
            for sub in AppConfig.current.workspace.subfolders {
                try? fm.createDirectory(atPath: root + "/" + sub, withIntermediateDirectories: true)
            }
            self.appendSetup("Workspace: \(root)\nFound \(repos.count) repos\n\n")

            // Adopt an existing folder: move any repos already on disk into their
            // correct subfolder before cloning the rest.
            self.reorganizeExisting(root: root)

            var cloneFailures = 0
            for name in repos {
                let dest = self.destPath(root: root, repo: name)
                if fm.fileExists(atPath: dest) {
                    self.appendSetup("• \(name) · already cloned, skipped\n")
                    DispatchQueue.main.async { self.setupCloned += 1 }
                    continue
                }
                self.appendSetup("⬇ \(name)\n")
                let ok = self.runProcess(
                    ["git", "clone", "--quiet", AppConfig.current.github.cloneURL(repo: name), dest]
                )
                self.appendSetup(ok ? "  ✓ cloned\n" : "  ✗ clone failed\n")
                if !ok { cloneFailures += 1 }
                DispatchQueue.main.async { self.setupCloned += 1 }
            }
            if cloneFailures > 0 {
                self.appendSetup("\n⚠ \(cloneFailures) clone\(cloneFailures == 1 ? "" : "s") failed. These use SSH (git@github.com) · make sure your SSH key is added to GitHub and authorized for the org. Test with: ssh -T git@github.com\n")
            }

            // Link AI-instruction files for every cloned repo (optional feature).
            let aiRepo = AppConfig.current.workspace.aiInstructionsRepo
            let linkScript = aiRepo.map { root + "/" + $0 + "/scripts/link.sh" }
            if let aiRepo, let linkScript, fm.fileExists(atPath: linkScript) {
                self.appendSetup("\nLinking AI instructions…\n")
                for name in repos where name != aiRepo {
                    let dest = self.destPath(root: root, repo: name)
                    guard fm.fileExists(atPath: dest) else { continue }
                    _ = self.runProcess(["bash", linkScript, name], cwd: dest)
                }
                self.appendSetup("Done.\n")
            } else if aiRepo != nil {
                self.appendSetup("\n(\(aiRepo!) not found · skipped AI linking)\n")
            }

            DispatchQueue.main.async {
                self.workspaceRoot = root
                Defaults[.workspaceRoot] = root
                self.setupExitCode = 0
                self.setupRunning = false
                self.newReposAvailable = []
                self.scanRepos()
            }
        }
    }

    // MARK: - New repo access

    /// Compares the org's td-* repos against what's cloned locally; surfaces any
    /// the user now has access to but hasn't downloaded yet.
    func checkForNewRepos() {
        guard !githubToken.isEmpty, isWorkspaceSetUp, !setupRunning else { return }
        let token = githubToken
        let root = workspaceRoot
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var status = 0
            let names = self.fetchOrgRepoNames(token: token, status: &status).filter { AppConfig.current.github.matches($0) }
            let fm = FileManager.default
            let missing = names.filter { !fm.fileExists(atPath: self.destPath(root: root, repo: $0)) }
            DispatchQueue.main.async { self.newReposAvailable = missing.sorted() }
        }
    }

    // MARK: - AI instructions update

    /// Path to the configured AI-instructions repo, or nil if the feature is off.
    private var aiInstructionsPath: String? {
        AppConfig.current.workspace.aiInstructionsRepo.map { workspaceRoot + "/" + $0 }
    }

    /// Checks whether the local AI-instructions repo is behind its upstream.
    func checkAIInstructionsUpdate() {
        guard let aiInstructionsPath,
              FileManager.default.fileExists(atPath: aiInstructionsPath + "/.git") else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self, let dir = self.aiInstructionsPath else { return }
            _ = self.runProcess(["git", "-C", dir, "fetch", "--quiet"])
            let local  = self.gitOutput(["git", "-C", dir, "rev-parse", "@"])
            let remote = self.gitOutput(["git", "-C", dir, "rev-parse", "@{u}"])
            let behind = !local.isEmpty && !remote.isEmpty && local != remote
            DispatchQueue.main.async { self.aiUpdateAvailable = behind }
        }
    }

    /// Pulls the AI-instructions repo and re-links instruction files across repos.
    func updateAIInstructions() {
        guard !aiInstructionsUpdating, let dir = aiInstructionsPath,
              let aiRepo = AppConfig.current.workspace.aiInstructionsRepo else { return }
        aiInstructionsUpdating = true
        setupOutput = ""
        setupExitCode = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            self.appendSetup("Updating \(aiRepo)…\n")
            let pulled = self.runProcess(["git", "-C", dir, "pull", "--quiet"])
            self.appendSetup(pulled ? "  ✓ pulled\n" : "  ✗ pull failed\n")

            let linkScript = dir + "/scripts/link.sh"
            if FileManager.default.fileExists(atPath: linkScript) {
                self.appendSetup("\nRe-linking AI instructions…\n")
                for repo in self.repos where repo.name != aiRepo {
                    _ = self.runProcess(["bash", linkScript, repo.name], cwd: repo.path)
                }
                self.appendSetup("Done.\n")
            }
            DispatchQueue.main.async {
                self.aiInstructionsUpdating = false
                self.aiUpdateAvailable = false
                self.scanRepos()
            }
        }
    }

    // MARK: - Helpers

    /// Runs a process and returns its trimmed stdout (used for small git queries).
    private func gitOutput(_ args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = args
        proc.environment = ProcessEnv.base()
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return "" }
        proc.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func destPath(root: String, repo: String) -> String {
        if let sub = AppConfig.current.github.subfolder(for: repo) {
            return root + "/" + sub + "/" + repo
        }
        return root + "/" + repo
    }

    private func appendSetup(_ s: String) {
        DispatchQueue.main.async { self.setupOutput += s }
    }

    /// Lists every repo in the org the token can see, following pagination.
    /// `status` reports the HTTP status of the first page (0 if the request failed).
    private func fetchOrgRepoNames(token: String, status: inout Int) -> [String] {
        var names: [String] = []
        var firstStatus = 0
        var isFirst = true
        var next: URL? = URL(string: "https://api.github.com/orgs/\(AppConfig.current.github.org)/repos?per_page=100&type=all&sort=full_name")
        while let url = next {
            next = nil
            let sem = DispatchSemaphore(value: 0)
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            req.timeoutInterval = 15
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                defer { sem.signal() }
                if isFirst { firstStatus = (resp as? HTTPURLResponse)?.statusCode ?? 0; isFirst = false }
                if let data, let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    names.append(contentsOf: arr.compactMap { $0["name"] as? String })
                }
                if let link = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Link") {
                    next = Self.parseNextLink(link)
                }
            }.resume()
            sem.wait()
        }
        status = firstStatus
        return names
    }

    /// Pulls the `rel="next"` URL out of a GitHub `Link` header.
    private static func parseNextLink(_ header: String) -> URL? {
        for part in header.components(separatedBy: ",") {
            let segs = part.components(separatedBy: ";")
            guard let urlSeg = segs.first,
                  segs.dropFirst().contains(where: { $0.contains("rel=\"next\"") }) else { continue }
            let raw = urlSeg.trimmingCharacters(in: CharacterSet(charactersIn: " <>"))
            return URL(string: raw)
        }
        return nil
    }

    @discardableResult
    private func runProcess(_ args: [String], cwd: String? = nil) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = args
        if let cwd { proc.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        proc.environment = ProcessEnv.git()
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let s = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !s.isEmpty else { return }
            self?.appendSetup(s)
        }
        do { try proc.run() } catch { return false }
        proc.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        return proc.terminationStatus == 0
    }
}
