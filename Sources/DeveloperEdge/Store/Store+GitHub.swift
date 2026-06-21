import Foundation

extension Store {
    func fetchOpenPRs() {
        guard !githubToken.isEmpty, !prsFetching else { return }
        prsFetching = true

        let token = githubToken
        let orgScope = AppConfig.current.github.org.isEmpty ? "" : "+org%3A\(AppConfig.current.github.org)"
        let queries = [
            "authored": "is%3Apr+is%3Aopen\(orgScope)+author%3A%40me",
            "review":   "is%3Apr+is%3Aopen\(orgScope)+review-requested%3A%40me",
        ]
        let group = DispatchGroup()
        var authored: [PRItem] = []
        var review: [PRItem] = []
        let lock = NSLock()

        for (key, q) in queries {
            guard let url = URL(string: "https://api.github.com/search/issues?q=\(q)&sort=updated&per_page=50") else { continue }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            req.timeoutInterval = 8
            group.enter()
            session.dataTask(with: req) { data, resp, _ in
                defer { group.leave() }
                guard let data,
                      (resp as? HTTPURLResponse)?.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]] else { return }
                let fmt = ISO8601DateFormatter()
                let parsed: [PRItem] = items.compactMap { item in
                    guard let id = item["number"] as? Int,
                          let title = item["title"] as? String,
                          let htmlUrl = item["html_url"] as? String,
                          let repoUrl = item["repository_url"] as? String,
                          let user = item["user"] as? [String: Any],
                          let author = user["login"] as? String,
                          let updatedStr = item["updated_at"] as? String,
                          let updatedAt = fmt.date(from: updatedStr) else { return nil }
                    let repo = repoUrl.components(separatedBy: "/").last ?? repoUrl
                    let draft = (item["draft"] as? Bool) ?? false
                    return PRItem(id: id, number: id, title: title, repo: repo,
                                  author: author, draft: draft, updatedAt: updatedAt, htmlUrl: htmlUrl)
                }
                lock.lock()
                if key == "authored" { authored = parsed } else { review = parsed }
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.myPRs = authored
            self.reviewRequests = review
            self.prsLastFetch = Date()
            self.prsFetching = false
            self.prsNeedsRefresh = false
            // Mark stale again in 60s so the next popover open triggers a refresh.
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                self?.prsNeedsRefresh = true
            }
        }
    }
}
