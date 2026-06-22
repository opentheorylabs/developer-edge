import Foundation
import AppKit
import Defaults

extension Store {

    // MARK: - Fetch orgs & user

    /// Fetches the authenticated user's personal account + all orgs they belong to.
    func fetchOnboardingOrgs() {
        guard !orgsFetching, !githubToken.isEmpty else { return }
        orgsFetching = true
        onboardingOrgs = []

        let token = githubToken
        Task.detached { [weak self] in
            guard let self else { return }

            // 1. Fetch user
            var user: OnboardingOrg? = nil
            if let data = try? await self.ghGET("https://api.github.com/user", token: token),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let login = json["login"] as? String,
               let id = json["id"] as? Int {
                user = OnboardingOrg(id: id, login: login, isUser: true)
            }

            // 2. Fetch orgs
            var orgs: [OnboardingOrg] = []
            if let data = try? await self.ghGET("https://api.github.com/user/orgs?per_page=100", token: token),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                orgs = arr.compactMap { obj -> OnboardingOrg? in
                    guard let login = obj["login"] as? String, let id = obj["id"] as? Int else { return nil }
                    return OnboardingOrg(id: id, login: login, isUser: false)
                }
            }

            var result: [OnboardingOrg] = []
            if let user { result.append(user) }
            result.append(contentsOf: orgs)

            await MainActor.run {
                self.onboardingOrgs = result
                self.orgsFetching = false
            }
        }
    }

    // MARK: - Fetch repos for an org/user

    /// Fetches all repos for the given org login (or user if isUser=true).
    func fetchOnboardingRepos(for org: OnboardingOrg) {
        guard !orgReposFetching.contains(org.login), !githubToken.isEmpty else { return }
        orgReposFetching.insert(org.login)

        let token = githubToken
        let root = workspaceRoot
        let login = org.login
        let isUser = org.isUser

        Task.detached { [weak self] in
            guard let self else { return }

            let baseURL = isUser
                ? "https://api.github.com/user/repos?per_page=100&sort=full_name&affiliation=owner"
                : "https://api.github.com/orgs/\(login)/repos?per_page=100&sort=full_name&type=all"

            var repos: [OnboardingRepo] = []
            var nextURL: String? = baseURL

            while let urlStr = nextURL, let url = URL(string: urlStr) {
                nextURL = nil
                guard let data = try? await self.ghGETWithLink(url, token: token) else { break }
                if let arr = try? JSONSerialization.jsonObject(with: data.body) as? [[String: Any]] {
                    let batch = arr.compactMap { obj -> OnboardingRepo? in
                        guard let id = obj["id"] as? Int,
                              let name = obj["name"] as? String,
                              let fullName = obj["full_name"] as? String,
                              let sshUrl = obj["ssh_url"] as? String,
                              let cloneUrl = obj["clone_url"] as? String,
                              let isPrivate = obj["private"] as? Bool else { return nil }
                        let desc = obj["description"] as? String
                        // repos land at root/<org>/<repo> — check that path
                        let cloned = !root.isEmpty &&
                            FileManager.default.fileExists(atPath: root + "/" + login + "/" + name + "/.git")
                        return OnboardingRepo(id: id, fullName: fullName, name: name,
                                             description: desc, isPrivate: isPrivate,
                                             sshUrl: sshUrl, httpsUrl: cloneUrl,
                                             alreadyCloned: cloned)
                    }
                    repos.append(contentsOf: batch)
                }
                nextURL = data.nextLink
            }

            await MainActor.run { [repos] in
                self.orgRepos[login] = repos
                self.orgReposFetching.remove(login)
            }
        }
    }

    // MARK: - Clone selected repos

    /// Clones all repos in `repos` whose `alreadyCloned` is false into the workspace root.
    /// Uses SSH URLs from the repo list; falls back to HTTPS.
    func cloneSelectedRepos(_ repos: [OnboardingRepo], into root: String) {
        guard onboardingClone == nil || onboardingClone?.finished == true else { return }

        let pending = repos.filter { !$0.alreadyCloned }
        guard !pending.isEmpty else {
            onboardingClone = OnboardingCloneState(total: 0, completed: 0, log: [], finished: true)
            return
        }

        onboardingClone = OnboardingCloneState(total: pending.count, completed: 0, log: [], finished: false)

        // Persist workspace root
        workspaceRoot = root
        Defaults[.workspaceRoot] = root

        Task.detached { [weak self] in
            guard let self else { return }

            for repo in pending {
                let parts = repo.fullName.split(separator: "/", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let orgLogin = String(parts[0])
                let repoName = String(parts[1])
                let orgDir = root + "/" + orgLogin
                let dest = orgDir + "/" + repoName
                try? FileManager.default.createDirectory(atPath: orgDir, withIntermediateDirectories: true)
                let cloneURL = repo.sshUrl
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                proc.arguments = ["git", "clone", "--quiet", cloneURL, dest]
                proc.environment = ProcessEnv.git()
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                var ok = false
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    ok = proc.terminationStatus == 0
                } catch { ok = false }

                await MainActor.run { [ok] in
                    self.onboardingClone?.log.append((repo: repo.fullName, success: ok))
                    self.onboardingClone?.completed += 1
                }
            }

            await MainActor.run {
                self.onboardingClone?.finished = true
                self.scanRepos()
            }
        }
    }

    // MARK: - Folder picker

    /// Shows an NSOpenPanel and returns the chosen path, or nil if cancelled.
    @MainActor
    func pickWorkspaceFolder() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Choose workspace folder"
        panel.prompt = "Use Folder"
        NSApp.activate(ignoringOtherApps: true)
        panel.level = .modalPanel
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return url.path
    }

    // MARK: - Private HTTP helpers

    private func ghGET(_ urlStr: String, token: String) async throws -> Data {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private struct PageResult {
        var body: Data
        var nextLink: String?
    }

    private func ghGETWithLink(_ url: URL, token: String) async throws -> PageResult {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: req)
        var nextLink: String? = nil
        if let link = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Link") {
            nextLink = Self.parseNextLinkStr(link)
        }
        return PageResult(body: data, nextLink: nextLink)
    }

    private static func parseNextLinkStr(_ header: String) -> String? {
        for part in header.components(separatedBy: ",") {
            let segs = part.components(separatedBy: ";")
            guard let urlSeg = segs.first,
                  segs.dropFirst().contains(where: { $0.contains("rel=\"next\"") }) else { continue }
            let raw = urlSeg.trimmingCharacters(in: CharacterSet(charactersIn: " <>"))
            return raw.isEmpty ? nil : raw
        }
        return nil
    }
}
