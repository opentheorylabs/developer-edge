import Foundation

extension Store {
    func fetchPipelineStatuses(env: Env) {
        guard !githubToken.isEmpty, !pipelineChecking else { return }
        pipelineChecking = true

        let branch = env.branch
        let token = githubToken
        let allRepos = services.map(\.repo)
        let repos = pinnedRepos.isEmpty ? allRepos : allRepos.filter { pinnedRepos.contains($0) }
        let group = DispatchGroup()
        var result: [String: PipelineStatus] = [:]
        var runURLs: [String: String] = [:]
        let lock = NSLock()

        let encodedBranch = branch.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? branch
        for repo in repos {
            guard let url = URL(string: "https://api.github.com/repos/\(AppConfig.current.github.org)/\(repo)/actions/runs?per_page=1&branch=\(encodedBranch)") else { continue }
            group.enter()
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            session.dataTask(with: req) { data, resp, _ in
                defer { group.leave() }
                guard let data, (resp as? HTTPURLResponse)?.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let runs = json["workflow_runs"] as? [[String: Any]],
                      let run = runs.first else {
                    lock.lock(); result[repo] = .unknown; lock.unlock()
                    return
                }
                let status = run["status"] as? String ?? ""
                let conclusion = run["conclusion"] as? String ?? ""
                let ps: PipelineStatus
                if status == "in_progress" || status == "queued" || status == "waiting" {
                    ps = .running
                } else if conclusion == "success" {
                    ps = .success
                } else if conclusion == "failure" || conclusion == "timed_out" || conclusion == "action_required" {
                    ps = .failure
                } else {
                    ps = .unknown
                }
                lock.lock()
                result[repo] = ps
                if let runURL = run["html_url"] as? String { runURLs[repo] = runURL }
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.pipelineStatuses.merge(result) { _, new in new }
            self.pipelineRunURLs.merge(runURLs) { _, new in new }
            self.pipelineChecking = false
        }
    }
}
