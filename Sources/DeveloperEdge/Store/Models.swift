import SwiftUI

// MARK: - Enums

enum Env: String, CaseIterable {
    case dev, staging, prod

    /// Matching environment entry from the loaded config, if any.
    private var cfg: AppConfig.Environment? {
        AppConfig.current.environments.first { $0.id == rawValue }
    }

    var label: String { cfg?.label ?? rawValue.capitalized }
    var branch: String { cfg?.branch ?? rawValue }
    var grafanaURL: String? { cfg?.grafanaURL }
}

enum ServiceKind { case frontend, api }

enum ReachStatus { case unknown, up, down }

enum PipelineStatus { case unknown, running, success, failure }

enum GraphToolState { case unknown, notInstalled, installed }

// MARK: - Service

struct ZService: Identifiable {
    var id: String { repo }
    let name: String
    let kind: ServiceKind
    let icon: String
    let repo: String
    let urls: [Env: String]
    var healthPath: String = "/"
}

/// Services from the loaded config, mapped to the runtime type.
var allServices: [ZService] {
    AppConfig.current.services.map { s in
        let urls = Dictionary(uniqueKeysWithValues:
            s.urls.compactMap { key, value in Env(rawValue: key).map { ($0, value) } })
        return ZService(name: s.name,
                        kind: s.kind == "api" ? .api : .frontend,
                        icon: s.icon, repo: s.repo,
                        urls: urls, healthPath: s.healthPath)
    }
}

// MARK: - Cluster

struct Cluster: Identifiable {
    var id: String { name }
    let name: String          // display label
    let env: String
    let credentialCommand: String   // shell command to fetch kube credentials
}

/// Clusters from the loaded config. The credential command is run in a shell,
/// so gcloud / AWS EKS / raw kubectl / Azure all work.
var clusters: [Cluster] {
    AppConfig.current.clusters.map {
        Cluster(name: $0.label, env: $0.env, credentialCommand: $0.credentialCommand)
    }
}

// MARK: - QuickLinkDef

struct QuickLinkDef {
    let id: String
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let url: String
    let mandatory: Bool
}

/// Quick links from the loaded config.
var allQuickLinks: [QuickLinkDef] {
    AppConfig.current.quickLinks.map {
        QuickLinkDef(id: $0.id, icon: $0.icon, color: Color(hex: $0.colorHex),
                     title: $0.title, subtitle: $0.subtitle, url: $0.url, mandatory: $0.mandatory)
    }
}

// MARK: - PRItem

struct PRItem: Identifiable {
    let id: Int
    let number: Int
    let title: String
    let repo: String
    let author: String
    let draft: Bool
    let updatedAt: Date
    let htmlUrl: String
}

// MARK: - RepoInfo

struct RepoInfo: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let hasLink: Bool         // CLAUDE.md symlink present in repo
    let hasInstructions: Bool // repos/<name>.md exists in td-ai-instructions
}

// MARK: - JiraTicket

struct JiraTicket: Identifiable {
    let id: String
    let key: String
    let summary: String
    let status: String
    let statusCategory: String  // "To Do" | "In Progress" | "Done"
    let assignee: String?
    let priority: String?       // "Highest" | "High" | "Medium" | "Low" | "Lowest"
    let issueType: String?
}

// MARK: - LinearIssue

struct LinearIssue: Identifiable {
    let id: String
    let identifier: String      // e.g. "ENG-123"
    let title: String
    let stateName: String
    let stateType: String       // "triage" | "backlog" | "unstarted" | "started" | "completed" | "cancelled"
    let priority: Int           // 0=none 1=urgent 2=high 3=medium 4=low
    let priorityLabel: String
    let url: String
    let teamName: String?

    var statusCategory: String {
        switch stateType {
        case "started":              return "In Progress"
        case "completed":            return "Done"
        default:                     return "To Do"
        }
    }
}

// MARK: - LocalListener

struct LocalListener: Identifiable {
    let id = UUID()
    let port: Int
    let processName: String
}

// MARK: - TerminalApp

struct TerminalApp: Identifiable {
    let id: String        // stable key persisted in settings
    let name: String      // display name + `open -a` target
    let icon: String
    let appPath: String   // for installed-detection

    var isInstalled: Bool { FileManager.default.fileExists(atPath: appPath) }
}

let allTerminals: [TerminalApp] = [
    TerminalApp(id: "terminal",  name: "Terminal",           icon: "terminal.fill",
                appPath: "/System/Applications/Utilities/Terminal.app"),
    TerminalApp(id: "iterm",     name: "iTerm",              icon: "terminal.fill",
                appPath: "/Applications/iTerm.app"),
    TerminalApp(id: "ghostty",   name: "Ghostty",            icon: "terminal.fill",
                appPath: "/Applications/Ghostty.app"),
    TerminalApp(id: "warp",      name: "Warp",               icon: "terminal.fill",
                appPath: "/Applications/Warp.app"),
    TerminalApp(id: "alacritty", name: "Alacritty",          icon: "terminal.fill",
                appPath: "/Applications/Alacritty.app"),
    TerminalApp(id: "kitty",     name: "kitty",              icon: "terminal.fill",
                appPath: "/Applications/kitty.app"),
    TerminalApp(id: "hyper",     name: "Hyper",              icon: "terminal.fill",
                appPath: "/Applications/Hyper.app"),
    TerminalApp(id: "vscode",    name: "Visual Studio Code", icon: "chevron.left.forwardslash.chevron.right",
                appPath: "/Applications/Visual Studio Code.app"),
]

var defaultWorkspaceRoot: String { AppConfig.current.workspace.expandedRoot }
