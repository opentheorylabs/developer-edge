import Foundation

extension Store {
    func checkAll() {
        guard !checking else { return }
        checking = true
        discoverServicesIfNeeded()

        var checks: [(displayURL: String, checkURL: String)] = []
        for svc in services {
            for (_, urlStr) in svc.urls {
                let checkURL = urlStr.hasSuffix("/") ? urlStr + svc.healthPath.dropFirst() : urlStr + svc.healthPath
                checks.append((displayURL: urlStr, checkURL: checkURL))
            }
        }

        let group = DispatchGroup()
        var result: [String: ReachStatus] = [:]
        let lock = NSLock()

        for pair in checks {
            guard let url = URL(string: pair.checkURL) else { continue }
            group.enter()
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            session.dataTask(with: req) { _, resp, _ in
                lock.lock()
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                result[pair.displayURL] = (code >= 200 && code < 500) ? .up : .down
                lock.unlock()
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            self?.reachability = result
            self?.lastCheck = Date()
            self?.checking = false
        }
    }

    func status(for url: String) -> ReachStatus { reachability[url] ?? .unknown }
    func pipeline(for repo: String) -> PipelineStatus { pipelineStatuses[repo] ?? .unknown }
}
