import Foundation

extension Store {
    func checkGraphToolInstalled() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", "which code-review-graph"]
            proc.environment = ProcessEnv.python()
            proc.standardOutput = Pipe()
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let installed = proc.terminationStatus == 0
            DispatchQueue.main.async { self?.graphToolState = installed ? .installed : .notInstalled }
        }
    }

    func installGraphTool() {
        guard !graphInstallRunning else { return }
        graphInstallRunning = true
        graphInstallOutput = ""
        graphInstallExitCode = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", "pipx install code-review-graph 2>/dev/null || pip install --user code-review-graph"]
            proc.environment = ProcessEnv.base()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let raw = String(data: handle.availableData, encoding: .utf8) ?? ""
                let clean = raw.replacingOccurrences(of: #"\x1B\[[0-9;]*[mK]"#, with: "", options: .regularExpression)
                guard !clean.isEmpty else { return }
                DispatchQueue.main.async { self.graphInstallOutput += clean }
            }
            do { try proc.run() } catch {
                DispatchQueue.main.async {
                    self.graphInstallOutput = "Error: \(error.localizedDescription)"
                    self.graphInstallExitCode = -1
                    self.graphInstallRunning = false
                }
                return
            }
            proc.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self.graphInstallExitCode = proc.terminationStatus
                self.graphInstallRunning = false
                if proc.terminationStatus == 0 { self.graphToolState = .installed }
            }
        }
    }

    func graphLastBuild(at repoPath: String) -> Date? {
        let dbPath = repoPath + "/.code-review-graph/graph.db"
        return (try? FileManager.default.attributesOfItem(atPath: dbPath))?[.modificationDate] as? Date
    }

    func isGraphStale(at repoPath: String) -> Bool {
        guard let d = graphLastBuild(at: repoPath) else { return false }
        return Date().timeIntervalSince(d) > 7 * 86400
    }

    /// Runs `git pull && code-review-graph build` across every repo in the workspace,
    /// streaming combined output and tracking aggregate success/failure (like fetch-all).
    func runCodeReviewGraph() {
        guard !graphBuildRunning else { return }
        if repos.isEmpty { scanRepos() }
        let targets = repos
        guard !targets.isEmpty else {
            graphBuildOutput = "No repos found in workspace.\n"
            graphBuildExitCode = -1
            return
        }
        graphBuildRunning = true
        graphBuildOutput = ""
        graphBuildExitCode = nil
        graphBuildProgress = 0
        graphBuildTotal = targets.count
        graphBuildFailures = []
        selectedGraphRepo = nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var env = ProcessEnv.python()
            env["GIT_TERMINAL_PROMPT"] = "0"

            var failed: [String] = []
            for repo in targets {
                self.appendGraph("\n━━━━ \(repo.name) ━━━━\n")
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = ["-c", "git pull --ff-only --quiet && code-review-graph build"]
                proc.currentDirectoryURL = URL(fileURLWithPath: repo.path)
                proc.environment = env
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = pipe
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let raw = String(data: handle.availableData, encoding: .utf8) ?? ""
                    let clean = raw.replacingOccurrences(of: #"\x1B\[[0-9;]*[mK]"#, with: "", options: .regularExpression)
                    guard !clean.isEmpty else { return }
                    DispatchQueue.main.async { self.graphBuildOutput += clean }
                }
                do { try proc.run() } catch {
                    self.appendGraph("✗ \(error.localizedDescription)\n")
                    failed.append(repo.name)
                    DispatchQueue.main.async { self.graphBuildProgress += 1 }
                    continue
                }
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                if proc.terminationStatus != 0 {
                    self.appendGraph("✗ build failed (exit \(proc.terminationStatus))\n")
                    failed.append(repo.name)
                } else {
                    self.appendGraph("✓ built\n")
                }
                DispatchQueue.main.async { self.graphBuildProgress += 1 }
            }

            let failureList = failed
            DispatchQueue.main.async {
                self.graphBuildFailures = failureList
                self.graphBuildExitCode = failureList.isEmpty ? 0 : Int32(failureList.count)
                self.graphBuildRunning = false
                if !failureList.isEmpty {
                    self.graphBuildOutput += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                    self.graphBuildOutput += "Failed: \(failureList.joined(separator: ", "))\n"
                } else {
                    self.graphBuildOutput += "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
                    self.graphBuildOutput += "All \(targets.count) repos built.\n"
                }
            }
        }
    }

    private func appendGraph(_ s: String) {
        DispatchQueue.main.async { self.graphBuildOutput += s }
    }
}
