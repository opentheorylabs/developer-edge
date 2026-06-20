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
    /// A bare folder named "Zuperior" no longer qualifies on name alone · it must
    /// contain a workspace marker or a td-* repo, otherwise a stray photo album
    /// at ~/Photos/Zuperior/ would be silently adopted and reorganized.
    private func looksLikeWorkspace(_ path: String) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: path + "/Frontend")
            || fm.fileExists(atPath: path + "/Backend")
            || fm.fileExists(atPath: path + "/td-ai-instructions") { return true }
        if let entries = try? fm.contentsOfDirectory(atPath: path),
           entries.contains(where: { $0.hasPrefix("td-") }) { return true }
        return false
    }

    /// Moves any td-* git repos already on disk (flat at root or in the wrong
    /// subfolder) into the correct subfolder for their prefix.
    private func reorganizeExisting(root: String) {
        let fm = FileManager.default
        let searchDirs = [root, root + "/Frontend", root + "/Backend", root + "/Mobile", root + "/DevOps"]
        var moved = 0
        for dir in searchDirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasPrefix("td-") {
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

            var status = 0
            let repos = self.fetchOrgRepoNames(token: token, status: &status)
                .filter { $0.hasPrefix("td-") && !$0.hasSuffix("-archive") }
                .sorted()
            guard !repos.isEmpty else {
                let msg: String
                switch status {
                case 401: msg = "GitHub rejected the token (401). Re-check your PAT in Settings."
                case 403: msg = "GitHub returned 403. Your token likely needs SSO authorization for the zuperior-platform org (Settings → token → Configure SSO)."
                case 200: msg = "No td-* repos visible to this token. Make sure it has repo + read:org access to zuperior-platform."
                default:  msg = "Could not reach GitHub (status \(status)). Check your network and token."
                }
                self.appendSetup("\n" + msg + "\n")
                DispatchQueue.main.async { self.setupExitCode = -1; self.setupRunning = false }
                return
            }
            DispatchQueue.main.async { self.setupTotal = repos.count }

            let fm = FileManager.default
            for sub in ["Frontend", "Backend", "Mobile", "DevOps"] {
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
                    ["git", "clone", "--quiet", "git@github.com:zuperior-platform/\(name).git", dest]
                )
                self.appendSetup(ok ? "  ✓ cloned\n" : "  ✗ clone failed\n")
                if !ok { cloneFailures += 1 }
                DispatchQueue.main.async { self.setupCloned += 1 }
            }
            if cloneFailures > 0 {
                self.appendSetup("\n⚠ \(cloneFailures) clone\(cloneFailures == 1 ? "" : "s") failed. These use SSH (git@github.com) · make sure your SSH key is added to GitHub and authorized for the org. Test with: ssh -T git@github.com\n")
            }

            // Link AGENTS.md / CLAUDE.md for every cloned repo
            let linkScript = root + "/td-ai-instructions/scripts/link.sh"
            if fm.fileExists(atPath: linkScript) {
                self.appendSetup("\nLinking AI instructions…\n")
                for name in repos where name != "td-ai-instructions" {
                    let dest = self.destPath(root: root, repo: name)
                    guard fm.fileExists(atPath: dest) else { continue }
                    _ = self.runProcess(["bash", linkScript, name], cwd: dest)
                }
                self.appendSetup("Done.\n")
            } else {
                self.appendSetup("\n(td-ai-instructions not found · skipped AI linking)\n")
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
            let names = self.fetchOrgRepoNames(token: token, status: &status).filter { $0.hasPrefix("td-") && !$0.hasSuffix("-archive") }
            let fm = FileManager.default
            let missing = names.filter { !fm.fileExists(atPath: self.destPath(root: root, repo: $0)) }
            DispatchQueue.main.async { self.newReposAvailable = missing.sorted() }
        }
    }

    // MARK: - AI instructions update

    private var aiInstructionsPath: String { workspaceRoot + "/td-ai-instructions" }

    /// Checks whether the local td-ai-instructions repo is behind its upstream.
    func checkAIInstructionsUpdate() {
        guard FileManager.default.fileExists(atPath: aiInstructionsPath + "/.git") else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let dir = self.aiInstructionsPath
            _ = self.runProcess(["git", "-C", dir, "fetch", "--quiet"])
            let local  = self.gitOutput(["git", "-C", dir, "rev-parse", "@"])
            let remote = self.gitOutput(["git", "-C", dir, "rev-parse", "@{u}"])
            let behind = !local.isEmpty && !remote.isEmpty && local != remote
            DispatchQueue.main.async { self.aiUpdateAvailable = behind }
        }
    }

    /// Pulls td-ai-instructions and re-links AGENTS.md across all known repos.
    func updateAIInstructions() {
        guard !aiInstructionsUpdating else { return }
        aiInstructionsUpdating = true
        setupOutput = ""
        setupExitCode = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let dir = self.aiInstructionsPath
            self.appendSetup("Updating td-ai-instructions…\n")
            let pulled = self.runProcess(["git", "-C", dir, "pull", "--quiet"])
            self.appendSetup(pulled ? "  ✓ pulled\n" : "  ✗ pull failed\n")

            let linkScript = dir + "/scripts/link.sh"
            if FileManager.default.fileExists(atPath: linkScript) {
                self.appendSetup("\nRe-linking AI instructions…\n")
                for repo in self.repos where repo.name != "td-ai-instructions" {
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
        if repo.hasPrefix("td-frontend-") { return root + "/Frontend/" + repo }
        if repo.hasPrefix("td-backend-")  { return root + "/Backend/" + repo }
        if repo.hasPrefix("td-mobile-")   { return root + "/Mobile/" + repo }
        if repo.hasPrefix("td-devops")    { return root + "/DevOps/" + repo }  // td-devops and td-devops-*
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
        var next: URL? = URL(string: "https://api.github.com/orgs/zuperior-platform/repos?per_page=100&type=all&sort=full_name")
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
