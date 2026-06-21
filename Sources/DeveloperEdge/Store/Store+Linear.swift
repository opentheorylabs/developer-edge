import Foundation
import Defaults

extension Store {
    func fetchLinearIssues() {
        guard !linearApiKey.isEmpty, !linearFetching else { return }
        linearFetching = true
        linearFetchError = nil

        guard let url = URL(string: "https://api.linear.app/graphql") else {
            linearFetching = false; return
        }

        let gql = "query($filter: IssueFilter) { viewer { assignedIssues(orderBy: updatedAt, filter: $filter) { nodes { id identifier title state { name type } priority priorityLabel url team { name } } } } }"

        var variables: [String: Any] = [:]
        if let teamId = AppConfig.current.linear?.teamId, !teamId.isEmpty {
            variables["filter"] = ["team": ["key": ["eq": teamId]]]
        }

        let body: [String: Any] = ["query": gql, "variables": variables]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            linearFetching = false; return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(linearApiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData
        req.timeoutInterval = 10

        session.dataTask(with: req) { [weak self] data, resp, error in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.linearFetching = false }
                if let error {
                    self.linearFetchError = error.localizedDescription; return
                }
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                guard let data else {
                    self.linearFetchError = "No response (HTTP \(status))"; return
                }
                if status != 200 {
                    let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                        .flatMap { ($0["errors"] as? [[String: Any]])?.first?["message"] as? String }
                        ?? "HTTP \(status)"
                    self.linearFetchError = msg; return
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataObj = json["data"] as? [String: Any],
                      let viewer = dataObj["viewer"] as? [String: Any],
                      let assigned = viewer["assignedIssues"] as? [String: Any],
                      let nodes = assigned["nodes"] as? [[String: Any]] else {
                    self.linearFetchError = "Unexpected response format"; return
                }
                self.linearIssues = nodes.compactMap { node in
                    guard let id = node["id"] as? String,
                          let identifier = node["identifier"] as? String,
                          let title = node["title"] as? String,
                          let stateObj = node["state"] as? [String: Any],
                          let stateName = stateObj["name"] as? String,
                          let stateType = stateObj["type"] as? String,
                          let url = node["url"] as? String
                    else { return nil }
                    // Skip completed and cancelled — not actionable
                    if stateType == "completed" || stateType == "cancelled" { return nil }
                    let priority = node["priority"] as? Int ?? 0
                    let priorityLabel = node["priorityLabel"] as? String ?? "No priority"
                    let teamName = (node["team"] as? [String: Any])?["name"] as? String
                    return LinearIssue(id: id, identifier: identifier, title: title,
                                       stateName: stateName, stateType: stateType,
                                       priority: priority, priorityLabel: priorityLabel,
                                       url: url, teamName: teamName)
                }
                self.linearLastFetch = Date()
                self.linearNeedsRefresh = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                    self?.linearNeedsRefresh = true
                }
            }
        }.resume()
    }
}
