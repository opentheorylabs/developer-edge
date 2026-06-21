import Foundation

extension Store {
    /// Reads the current git branch from the workspace root and extracts
    /// any ticket ID embedded in the branch name (e.g. ENG-123, TD-456).
    func readCurrentBranch() {
        let root = workspaceRoot.isEmpty ? NSHomeDirectory() : workspaceRoot
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            proc.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
            proc.currentDirectoryURL = URL(fileURLWithPath: root)
            proc.environment = ProcessEnv.git()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            guard (try? proc.run()) != nil else { return }
            proc.waitUntilExit()
            let branch = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !branch.isEmpty, branch != "HEAD" else { return }
            let ticketId = Self.extractTicketId(from: branch)
            DispatchQueue.main.async {
                self?.currentBranch = branch
                self?.currentBranchTicketId = ticketId
            }
        }
    }

    /// Extracts the first Jira/Linear-style ticket ID from a branch name.
    /// Matches patterns like ENG-123, TD-456, PROJ-789.
    static func extractTicketId(from branch: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"[A-Z]{1,10}-[0-9]+"#),
              let match = regex.firstMatch(in: branch, range: NSRange(branch.startIndex..., in: branch)),
              let range = Range(match.range, in: branch) else { return nil }
        return String(branch[range])
    }
}
