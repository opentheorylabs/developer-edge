import Foundation
import Defaults

extension Store {
    func checkLocalhostHealth() {
        guard !localhostChecking else { return }
        let configured = allServices.compactMap { svc -> (String, String)? in
            guard let port = localhostPorts[svc.repo] else { return nil }
            let base = "http://localhost:\(port)"
            return (base, base + svc.healthPath)
        }
        guard !configured.isEmpty else { return }
        localhostChecking = true

        let group = DispatchGroup()
        var result: [String: ReachStatus] = [:]
        let lock = NSLock()

        for (base, urlStr) in configured {
            guard let url = URL(string: urlStr) else { continue }
            group.enter()
            var req = URLRequest(url: url)
            req.timeoutInterval = 2
            session.dataTask(with: req) { _, resp, _ in
                lock.lock()
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                result[base] = (code >= 200 && code < 500) ? .up : .down
                lock.unlock()
                group.leave()
            }.resume()
        }

        group.notify(queue: .main) { [weak self] in
            self?.localhostStatuses = result
            self?.localhostChecking = false
        }
    }

    func scanLocalListeners() {
        guard !scanningListeners else { return }
        scanningListeners = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", "lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            var listeners: [LocalListener] = []
            var seen = Set<Int>()
            for line in output.components(separatedBy: "\n").dropFirst() {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 2 else { continue }
                let command = String(parts[0])
                let namePart = parts.last.map(String.init) ?? ""
                let addr = namePart == "(LISTEN)" ? (parts.dropLast().last.map(String.init) ?? "") : namePart
                guard let colonRange = addr.range(of: ":", options: .backwards) else { continue }
                let portStr = String(addr[colonRange.upperBound...])
                guard let port = Int(portStr), port > 1023, !seen.contains(port) else { continue }
                seen.insert(port)
                listeners.append(LocalListener(port: port, processName: command))
            }

            let sorted = listeners.sorted { $0.port < $1.port }
            DispatchQueue.main.async { [weak self] in
                self?.localListeners = sorted
                self?.scanningListeners = false
            }
        }
    }

    func setLocalhostPort(_ port: Int?, for repo: String) {
        var updated = localhostPorts
        if let port { updated[repo] = port } else { updated.removeValue(forKey: repo) }
        localhostPorts = updated
        Defaults[.localhostPorts] = updated
    }
}
