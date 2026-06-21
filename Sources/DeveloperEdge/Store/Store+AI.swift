import Foundation
import AppKit

extension Store {

    // MARK: - AI server status

    func checkAIServer() {
        guard let urlStr = AppConfig.current.ai?.server?.url,
              let base = URL(string: urlStr),
              !aiServerChecking else { return }
        aiServerChecking = true
        aiServerStatus = .checking
        let url = base.appendingPathComponent("v1/models")
        let start = Date()
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        session.dataTask(with: req) { [weak self] data, resp, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.aiServerChecking = false
                let ms = Date().timeIntervalSince(start) * 1000
                guard let data,
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["data"] as? [[String: Any]],
                      let modelId = models.first?["id"] as? String else {
                    self.aiServerStatus = .offline
                    self.aiServerModel = nil
                    return
                }
                self.aiServerStatus = .online
                self.aiServerModel = modelId
                self.aiServerLatency = ms
            }
        }.resume()
    }

    // MARK: - Context copy

    func copyWorkspaceContext() {
        let root = workspaceRoot.isEmpty ? NSHomeDirectory() : workspaceRoot
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var parts: [String] = []

            let name = URL(fileURLWithPath: root).lastPathComponent
            parts.append("# Context: \(name)")

            if !self.currentBranch.isEmpty {
                var line = "Branch: \(self.currentBranch)"
                if let id = self.currentBranchTicketId { line += " (ticket: \(id))" }
                parts.append(line)
            }

            // Recent git log
            let logProc = Process()
            logProc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            logProc.arguments = ["log", "--oneline", "-10"]
            logProc.currentDirectoryURL = URL(fileURLWithPath: root)
            logProc.environment = ProcessEnv.git()
            let logPipe = Pipe()
            logProc.standardOutput = logPipe
            logProc.standardError = Pipe()
            if (try? logProc.run()) != nil {
                logProc.waitUntilExit()
                let log = String(data: logPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !log.isEmpty { parts.append("\nRecent commits:\n\(log)") }
            }

            // AI instructions — prefer CLAUDE.md, fall back to AGENTS.md
            let claudeMd = (try? String(contentsOfFile: root + "/CLAUDE.md", encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let content = claudeMd, !content.isEmpty {
                parts.append("\n## CLAUDE.md\n\(content)")
            } else if let content = (try? String(contentsOfFile: root + "/AGENTS.md", encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
                parts.append("\n## AGENTS.md\n\(content)")
            }

            let text = parts.joined(separator: "\n")
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                self.contextCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.contextCopied = false
                }
            }
        }
    }

    // MARK: - PR prompt copy

    func copyPRPrompt() {
        let branch = currentBranch
        let ticketId = currentBranchTicketId

        var ticketLine = ""
        if let id = ticketId {
            if AppConfig.current.linear != nil {
                let issue = linearIssues.first { $0.identifier == id }
                ticketLine = issue.map { "\nTicket: \(id) — \($0.title)" } ?? "\nTicket: \(id)"
            } else if let issue = jiraTickets.first(where: { $0.key == id }) {
                ticketLine = "\nTicket: \(id) — \(issue.summary)"
            } else {
                ticketLine = "\nTicket: \(id)"
            }
        }

        let prompt = """
        Write a pull request description for this change.

        Branch: \(branch)\(ticketLine)

        Format:
        ## Summary
        - <what changed and why>

        ## Test plan
        - [ ] <how to verify>

        Keep it concise and technical.
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        prPromptCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.prPromptCopied = false
        }
    }
}
