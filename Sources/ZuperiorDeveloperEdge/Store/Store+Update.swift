import Foundation

extension Store {

    // Checks whether origin/main has commits not present in HEAD.
    // Runs: git fetch origin main, then git log HEAD..origin/main --oneline | wc -l
    // Sets updateAvailable = true when count > 0.
    // Throttled: skips the check if it ran within the last hour.
    func checkForUpdate() {
        let repoPath = workspaceRoot
        guard !repoPath.isEmpty else { return }

        // Throttle: once per hour, but only when the previous run succeeded.
        if let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date,
           Date().timeIntervalSince(last) < 3600 { return }

        // Reentrancy guard for the duration of this call.
        if updateChecking { return }
        updateChecking = true

        Task {
            defer { Task { @MainActor in self.updateChecking = false } }

            // Step A: fetch
            let fetch = Process()
            fetch.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            fetch.arguments = ["-C", repoPath, "fetch", "origin", "main", "--quiet"]
            fetch.environment = ProcessInfo.processInfo.environment
            fetch.standardOutput = FileHandle.nullDevice
            fetch.standardError  = FileHandle.nullDevice
            do { try fetch.run() } catch { return }
            fetch.waitUntilExit()
            guard fetch.terminationStatus == 0 else { return }

            // Step B: count commits on origin/main not in HEAD
            let log = Process()
            let pipe = Pipe()
            log.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            log.arguments = ["-C", repoPath, "log", "HEAD..origin/main", "--oneline"]
            log.environment = ProcessInfo.processInfo.environment
            log.standardOutput = pipe
            log.standardError  = FileHandle.nullDevice
            do { try log.run() } catch { return }
            log.waitUntilExit()
            guard log.terminationStatus == 0 else { return }

            let raw = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let count = raw.split(separator: "\n").filter { !$0.isEmpty }.count

            // Only persist the throttle timestamp on a successful check.
            UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")

            await MainActor.run {
                updateAvailable = count > 0
            }
        }
    }

    // Runs update.sh (bundled or from repo). Sets updateAvailable = false on success.
    func runUpdate() {
        let fm = FileManager.default
        let repoPath: String? = workspaceRoot.isEmpty ? nil : workspaceRoot
        let bundled = Bundle.main.path(forResource: "update", ofType: "sh")
        let repoScript = repoPath.map { $0 + "/scripts/update.sh" }

        let script: String
        if let bundled, fm.fileExists(atPath: bundled) {
            script = bundled
        } else if let repoScript, fm.fileExists(atPath: repoScript) {
            script = repoScript
        } else {
            return
        }

        Task {
            await MainActor.run { updateRunning = true }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            var args = [script]
            if let repoPath { args.append(repoPath) }
            proc.arguments = args
            proc.environment = ProcessInfo.processInfo.environment
            // Drain via /dev/null so a chatty `swift build` can't fill a 64 KB pipe buffer and deadlock.
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError  = FileHandle.nullDevice
            do { try proc.run() } catch {
                await MainActor.run { updateRunning = false }
                return
            }

            let deadline = DispatchTime.now() + 60
            DispatchQueue.global().asyncAfter(deadline: deadline) {
                if proc.isRunning { proc.terminate() }
            }
            proc.waitUntilExit()

            await MainActor.run {
                updateRunning = false
                if proc.terminationStatus == 0 {
                    updateAvailable = false
                }
            }
        }
    }
}
