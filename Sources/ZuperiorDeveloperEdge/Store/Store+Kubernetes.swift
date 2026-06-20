import Foundation

extension Store {
    func refreshKubeconfig() {
        guard !kubeRefreshing else { return }
        kubeRefreshing = true
        kubeError = nil
        kubeSuccessCount = 0

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let cmds = clusters.map { c in
                "/opt/homebrew/bin/gcloud container clusters get-credentials \(c.name) --project \(c.project) --region \(c.region) --internal-ip"
            }.joined(separator: " && ")

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", cmds]
            proc.environment = ProcessEnv.base()
            let errPipe = Pipe()
            proc.standardOutput = Pipe()
            proc.standardError = errPipe
            do { try proc.run() } catch {
                DispatchQueue.main.async {
                    self.kubeError = error.localizedDescription
                    self.kubeRefreshing = false
                }
                return
            }
            proc.waitUntilExit()
            let errOutput = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                if proc.terminationStatus == 0 {
                    self.kubeSuccessCount = clusters.count
                    self.kubeLastRefresh = Date()
                } else {
                    self.kubeError = errOutput.isEmpty ? "gcloud failed (exit \(proc.terminationStatus))" : errOutput
                }
                self.kubeRefreshing = false
            }
        }
    }
}
