import Foundation
import SwiftUI

// MARK: - AppConfig
//
// The single source of truth for everything team-specific: branding, GitHub
// org + repo conventions, Jira host, services, environments, clusters, quick
// links, Slack channels, and celebrations.
//
// Loaded once at launch (see `AppConfig.load`) from the first config file found:
//   1. $DEVELOPER_EDGE_CONFIG            (explicit path · testing)
//   2. <workspaceRoot>/developer-edge.json   (team-committed)
//   3. ~/.config/developer-edge/config.json  (per-user)
//   4. bundled developer-edge.example.json   (fallback)
//   5. AppConfig.fallback                     (compiled-in defaults)
//
// Secrets (GitHub / Jira tokens) are NEVER read from here · they live in the
// keychain / Defaults. Every section except `branding` and `github` is optional
// and its feature degrades gracefully when omitted.

struct AppConfig: Codable {
    var branding: Branding
    var github: GitHub
    var jira: Jira?
    var workspace: Workspace
    var environments: [Environment]
    var services: [Service]
    var clusters: [ClusterDef]
    var quickLinks: [QuickLink]
    var slackChannels: [SlackChannel]
    var celebrations: Celebrations?

    // MARK: Sections

    struct Branding: Codable {
        var appName: String
        var accentColorHex: String          // e.g. "#76B900"
        var showBetaBadge: Bool
        var feedbackURL: String?            // "report a bug" target

        init(appName: String = "Developer Edge",
             accentColorHex: String = "#76B900",
             showBetaBadge: Bool = false,
             feedbackURL: String? = nil) {
            self.appName = appName
            self.accentColorHex = accentColorHex
            self.showBetaBadge = showBetaBadge
            self.feedbackURL = feedbackURL
        }
    }

    struct GitHub: Codable {
        var org: String
        var repoPrefix: String?             // filter, e.g. "td-" · nil = all repos
        var excludeSuffix: String?          // e.g. "-archive"
        var cloneScheme: CloneScheme        // ssh | https
        /// Maps a repo-name prefix to a workspace subfolder, e.g. "td-frontend-": "Frontend".
        var subfolderRules: [String: String]

        enum CloneScheme: String, Codable { case ssh, https }

        init(org: String,
             repoPrefix: String? = nil,
             excludeSuffix: String? = "-archive",
             cloneScheme: CloneScheme = .ssh,
             subfolderRules: [String: String] = [:]) {
            self.org = org
            self.repoPrefix = repoPrefix
            self.excludeSuffix = excludeSuffix
            self.cloneScheme = cloneScheme
            self.subfolderRules = subfolderRules
        }

        /// Builds the clone URL for a repo per the configured scheme.
        func cloneURL(repo: String) -> String {
            switch cloneScheme {
            case .ssh:   return "git@github.com:\(org)/\(repo).git"
            case .https: return "https://github.com/\(org)/\(repo).git"
            }
        }

        /// True if a repo passes the configured prefix + exclude-suffix filter.
        func matches(_ repo: String) -> Bool {
            if let p = repoPrefix, !p.isEmpty, !repo.hasPrefix(p) { return false }
            if let s = excludeSuffix, !s.isEmpty, repo.hasSuffix(s) { return false }
            return true
        }

        /// True when a non-empty repo prefix is configured (so prefix-based
        /// heuristics like workspace detection are meaningful).
        var hasPrefix: Bool { (repoPrefix?.isEmpty == false) }

        /// Subfolder a repo belongs in, by longest matching rule key. nil = flat.
        func subfolder(for repo: String) -> String? {
            subfolderRules
                .sorted { $0.key.count > $1.key.count }
                .first { repo.hasPrefix($0.key) }?.value
        }
    }

    struct Jira: Codable {
        var host: String                    // "your-org.atlassian.net"
        var jql: String?                    // optional override for the ticket query
    }

    struct Workspace: Codable {
        /// Default root; "~" is expanded. Empty = prompt on first run.
        var defaultRoot: String
        var subfolders: [String]
        /// Optional repo whose scripts/link.sh links AI instructions across repos.
        var aiInstructionsRepo: String?

        init(defaultRoot: String = "~/Developer",
             subfolders: [String] = ["Frontend", "Backend", "Mobile", "DevOps"],
             aiInstructionsRepo: String? = nil) {
            self.defaultRoot = defaultRoot
            self.subfolders = subfolders
            self.aiInstructionsRepo = aiInstructionsRepo
        }

        var expandedRoot: String { (defaultRoot as NSString).expandingTildeInPath }
    }

    struct Environment: Codable, Identifiable {
        var id: String                      // "dev" | "staging" | "prod"
        var label: String
        var branch: String
        var grafanaURL: String?
    }

    struct Service: Codable, Identifiable {
        var id: String { repo }
        var name: String
        var kind: String                    // "frontend" | "api"
        var icon: String                    // SF Symbol
        var repo: String
        var urls: [String: String]          // env id -> URL
        var healthPath: String

        init(name: String, kind: String, icon: String, repo: String,
             urls: [String: String] = [:], healthPath: String = "/") {
            self.name = name; self.kind = kind; self.icon = icon
            self.repo = repo; self.urls = urls; self.healthPath = healthPath
        }
    }

    /// A cluster the user can refresh credentials for. The command is run in a
    /// shell, so this works for gcloud, AWS EKS, raw kubectl contexts, Azure, etc.
    struct ClusterDef: Codable, Identifiable {
        var id: String { label }
        var label: String
        var env: String
        var credentialCommand: String       // e.g. "gcloud container clusters get-credentials ..."
    }

    struct QuickLink: Codable, Identifiable {
        var id: String
        var icon: String
        var colorHex: String
        var title: String
        var subtitle: String
        var url: String
        var mandatory: Bool
    }

    struct SlackChannel: Codable, Identifiable {
        var id: String
        var icon: String
        var colorHex: String
        var title: String
        var subtitle: String
    }

    struct Celebrations: Codable {
        var enabled: Bool
        var locale: String?                 // e.g. "en_IN" for regional holidays
        var rosterPath: String?             // path to celebrations.json (birthdays/anniversaries)

        init(enabled: Bool = false, locale: String? = nil, rosterPath: String? = nil) {
            self.enabled = enabled
            self.locale = locale
            self.rosterPath = rosterPath
        }
    }
}

// MARK: - Decoding with defaults
//
// Swift's synthesized Codable requires every non-optional key to be present.
// We decode defensively so a minimal config (just branding + github) works.

extension AppConfig {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        branding      = try c.decodeIfPresent(Branding.self,        forKey: .branding)      ?? Branding()
        github        = try c.decode(GitHub.self,                   forKey: .github)
        jira          = try c.decodeIfPresent(Jira.self,            forKey: .jira)
        workspace     = try c.decodeIfPresent(Workspace.self,       forKey: .workspace)     ?? Workspace()
        environments  = try c.decodeIfPresent([Environment].self,   forKey: .environments)  ?? []
        services      = try c.decodeIfPresent([Service].self,       forKey: .services)      ?? []
        clusters      = try c.decodeIfPresent([ClusterDef].self,    forKey: .clusters)      ?? []
        quickLinks    = try c.decodeIfPresent([QuickLink].self,     forKey: .quickLinks)    ?? []
        slackChannels = try c.decodeIfPresent([SlackChannel].self,  forKey: .slackChannels) ?? []
        celebrations  = try c.decodeIfPresent(Celebrations.self,    forKey: .celebrations)
    }
}

// MARK: - Loading

extension AppConfig {
    /// The resolved config for this launch. Set once by `bootstrap`.
    private(set) static var current: AppConfig = .fallback

    /// Resolves and caches the config. Pass the configured workspace root so the
    /// team-committed `<root>/developer-edge.json` can be discovered.
    @discardableResult
    static func bootstrap(workspaceRoot: String?) -> AppConfig {
        current = load(workspaceRoot: workspaceRoot)
        return current
    }

    static func load(workspaceRoot: String?) -> AppConfig {
        let fm = FileManager.default
        var candidates: [String] = []
        if let env = ProcessInfo.processInfo.environment["DEVELOPER_EDGE_CONFIG"] {
            candidates.append(env)
        }
        if let root = workspaceRoot, !root.isEmpty {
            candidates.append(root + "/developer-edge.json")
        }
        candidates.append(NSHomeDirectory() + "/.config/developer-edge/config.json")
        if let bundled = Bundle.main.path(forResource: "developer-edge.example", ofType: "json") {
            candidates.append(bundled)
        }

        for path in candidates {
            guard fm.fileExists(atPath: path),
                  let data = fm.contents(atPath: path) else { continue }
            do {
                return try JSONDecoder().decode(AppConfig.self, from: data)
            } catch {
                NSLog("Developer Edge: failed to parse config at \(path): \(error)")
                // Keep trying lower-priority candidates rather than crash.
            }
        }
        return .fallback
    }

    /// Compiled-in minimal default so the app always launches, even with no file.
    static let fallback = AppConfig(
        branding: Branding(),
        github: GitHub(org: ""),
        jira: nil,
        workspace: Workspace(),
        environments: [
            Environment(id: "dev",     label: "Dev",     branch: "development", grafanaURL: nil),
            Environment(id: "staging", label: "Staging", branch: "staging",     grafanaURL: nil),
            Environment(id: "prod",    label: "Prod",    branch: "production",   grafanaURL: nil),
        ],
        services: [],
        clusters: [],
        quickLinks: [],
        slackChannels: [],
        celebrations: nil
    )
}

// MARK: - Color(hex:)

extension Color {
    /// Parses "#RRGGBB" / "RRGGBB" (and #RGB). Falls back to the accent green.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else {
            self = Color(red: 118/255, green: 185/255, blue: 0); return
        }
        self = Color(
            red:   Double((v & 0xFF0000) >> 16) / 255,
            green: Double((v & 0x00FF00) >> 8)  / 255,
            blue:  Double( v & 0x0000FF)        / 255
        )
    }
}
