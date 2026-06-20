import Foundation
import Defaults

extension Store {
    func autoDetectJiraEmail() {
        guard jiraEmail.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", "git config user.email"]
            // Use HOME as cwd (always exists) so this works even before a workspace is set up.
            proc.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
            proc.environment = ProcessEnv.base()
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            proc.waitUntilExit()
            let email = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            // Only trust it if it's a Zuperior address · the Jira account is @zuperior.com.
            // A personal git email would just break auth, so leave it blank for the user.
            guard email.hasSuffix("@zuperior.com") else { return }
            DispatchQueue.main.async {
                self.jiraEmail = email
                Defaults[.jiraEmail] = email
            }
        }
    }

    /// Pulls the user's profile from Jira (`/myself`): display name (for greetings)
    /// and account ID (so the user never has to enter it). Runs when a token is set
    /// and either is still missing.
    func fetchJiraDisplayName() {
        guard !jiraApiToken.isEmpty, userName.isEmpty || jiraAccountId.isEmpty else { return }
        let credential = jiraEmail.isEmpty ? jiraApiToken : "\(jiraEmail):\(jiraApiToken)"
        guard let credData = credential.data(using: .utf8),
              let url = URL(string: "https://zuperior-platform.atlassian.net/rest/api/3/myself") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Basic \(credData.base64EncodedString())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpShouldHandleCookies = false
        req.timeoutInterval = 10

        session.dataTask(with: req) { [weak self] data, resp, _ in
            guard let self,
                  let data, (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            let name = (json["displayName"] as? String) ?? ""
            let accountId = (json["accountId"] as? String) ?? ""
            DispatchQueue.main.async {
                if !name.isEmpty { self.userName = name; Defaults[.userName] = name }
                if !accountId.isEmpty { self.jiraAccountId = accountId; Defaults[.jiraAccountId] = accountId }
            }
        }.resume()
    }

    func fetchJiraTickets() {
        guard !jiraApiToken.isEmpty, !jiraFetching else { return }
        jiraFetching = true
        jiraFetchError = nil

        let credential = jiraEmail.isEmpty ? jiraApiToken : "\(jiraEmail):\(jiraApiToken)"
        guard let credData = credential.data(using: .utf8) else { return }
        let auth = "Basic \(credData.base64EncodedString())"

        // Use GET, not POST. Atlassian's edge applies an XSRF check to state-changing
        // methods (POST/PUT) on this host that fires non-deterministically for non-curl
        // clients and is not reliably defeated by X-Atlassian-Token. GET is never XSRF-checked.
        var comps = URLComponents(string: "https://zuperior-platform.atlassian.net/rest/api/3/search/jql")!
        comps.queryItems = [
            URLQueryItem(name: "jql", value: "project = ZT AND assignee = currentUser() AND sprint in openSprints() ORDER BY status ASC"),
            URLQueryItem(name: "maxResults", value: "100"),
            URLQueryItem(name: "fields", value: "summary,status,assignee,priority,issuetype"),
        ]
        guard let url = comps.url else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(auth, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpShouldHandleCookies = false
        req.timeoutInterval = 10

        session.dataTask(with: req) { [weak self] data, resp, error in
            DispatchQueue.main.async {
                guard let self else { return }
                defer { self.jiraFetching = false }
                if let error { self.jiraFetchError = error.localizedDescription; return }
                let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
                guard let data else {
                    self.jiraFetchError = "No response (HTTP \(statusCode))"
                    return
                }
                if statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "(empty)"
                    let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                        .flatMap { ($0["errorMessages"] as? [String])?.first ?? $0["message"] as? String }
                        ?? body
                    self.jiraFetchError = "HTTP \(statusCode): \(msg)"
                    return
                }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let issues = json["issues"] as? [[String: Any]] else {
                    self.jiraFetchError = "Unexpected response format"
                    return
                }
                self.jiraTickets = issues.compactMap { issue in
                    guard let key = issue["key"] as? String,
                          let fields = issue["fields"] as? [String: Any],
                          let summary = fields["summary"] as? String,
                          let statusObj = fields["status"] as? [String: Any],
                          let statusName = statusObj["name"] as? String,
                          let statusCat = (statusObj["statusCategory"] as? [String: Any])?["name"] as? String
                    else { return nil }
                    let assignee  = (fields["assignee"]  as? [String: Any])?["displayName"] as? String
                    let priority  = (fields["priority"]  as? [String: Any])?["name"] as? String
                    let issueType = (fields["issuetype"] as? [String: Any])?["name"] as? String
                    return JiraTicket(id: key, key: key, summary: summary,
                                     status: statusName, statusCategory: statusCat,
                                     assignee: assignee, priority: priority, issueType: issueType)
                }
                self.jiraLastFetch = Date()
                self.jiraNeedsRefresh = false
                // Mark stale again in 60s so the next popover open triggers a refresh.
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                    self?.jiraNeedsRefresh = true
                }
            }
        }.resume()
    }
}
