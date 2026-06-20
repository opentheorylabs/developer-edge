import SwiftUI

// MARK: - Enums

enum Env: String, CaseIterable {
    case dev, staging, prod

    var label: String {
        switch self {
        case .dev:     return "Dev"
        case .staging: return "Staging"
        case .prod:    return "Prod"
        }
    }

    var branch: String {
        switch self {
        case .dev:     return "development"
        case .staging: return "staging"
        case .prod:    return "production"
        }
    }

    var grafanaURL: String {
        switch self {
        case .dev:     return "https://grafana.dev.zuperior.dev"
        case .staging: return "https://grafana.stg.zuperior.dev"
        case .prod:    return "https://grafana.zuperior.com"
        }
    }
}

enum ServiceKind { case frontend, api }

enum ReachStatus { case unknown, up, down }

enum PipelineStatus { case unknown, running, success, failure }

enum GraphToolState { case unknown, notInstalled, installed }

// MARK: - Service

struct ZService: Identifiable {
    let id = UUID()
    let name: String
    let kind: ServiceKind
    let icon: String
    let repo: String
    let urls: [Env: String]
    var healthPath: String = "/"
}

let allServices: [ZService] = [
    // ── Frontends ──────────────────────────────────────────────────────────
    ZService(name: "Trading Terminal", kind: .frontend, icon: "chart.line.uptrend.xyaxis",
             repo: "td-frontend-terminal-website", urls: [
        .dev:     "https://trade.dev.zuperior.dev",
        .staging: "https://trade.stg.zuperior.dev",
        .prod:    "https://trade.zuperior.com",
    ], healthPath: "/api/health"),
    ZService(name: "Back Office", kind: .frontend, icon: "gauge.with.dots.needle.50percent",
             repo: "td-frontend-back-office", urls: [
        .dev:     "https://back-office.dev.zuperior.dev",
        .staging: "https://back-office.stg.zuperior.dev",
        .prod:    "https://back-office.zuperior.com",
    ]),
    ZService(name: "CRM Dashboard", kind: .frontend, icon: "person.2.fill",
             repo: "td-frontend-crm-website", urls: [
        .dev:     "https://dashboard.dev.zuperior.dev",
        .staging: "https://dashboard.stg.zuperior.dev",
        .prod:    "https://dashboard.zuperior.com",
    ], healthPath: "/api/health"),
    ZService(name: "IB Portal", kind: .frontend, icon: "building.2.fill",
             repo: "td-frontend-ib-website", urls: [
        .dev:     "https://partner.dev.zuperior.dev",
        .staging: "https://partner.stg.zuperior.dev",
        .prod:    "https://partner.zuperior.com",
    ], healthPath: "/api/health"),
    ZService(name: "Demo Terminal", kind: .frontend, icon: "play.rectangle.fill",
             repo: "td-frontend-demo-terminal", urls: [
        .dev:     "https://demo.dev.zuperior.dev",
        .staging: "https://demo.stg.zuperior.dev",
        .prod:    "https://demo.zuperior.com",
    ], healthPath: "/api/health"),
    ZService(name: "Landing", kind: .frontend, icon: "globe",
             repo: "td-frontend-landing-website", urls: [
        .dev:     "https://dev.zuperior.dev",
        .staging: "https://stg.zuperior.dev",
        .prod:    "https://www.zuperior.com",
    ], healthPath: "/api/health"),
    // ── APIs ───────────────────────────────────────────────────────────────
    ZService(name: "Terminal API", kind: .api, icon: "terminal.fill",
             repo: "td-backend-terminal-service", urls: [
        .dev:     "https://terminal.api.dev.zuperior.dev",
        .staging: "https://terminal.api.stg.zuperior.dev",
        .prod:    "https://terminal.api.zuperior.com",
    ], healthPath: "/health"),
    ZService(name: "Back Office API", kind: .api, icon: "server.rack",
             repo: "td-backend-back-office-service", urls: [
        .dev:     "https://backoffice.api.dev.zuperior.dev",
        .staging: "https://back-office.api.stg.zuperior.dev",
        .prod:    "https://back-office.api.zuperior.com",
    ], healthPath: "/health"),
    ZService(name: "CRM API", kind: .api, icon: "person.crop.circle.fill",
             repo: "td-backend-crm-service", urls: [
        .dev:     "https://crm.api.dev.zuperior.dev",
        .staging: "https://crm.api.stg.zuperior.dev",
        .prod:    "https://crm.api.zuperior.com",
    ], healthPath: "/health"),
    ZService(name: "Partner API", kind: .api, icon: "link.circle.fill",
             repo: "td-backend-ib-service", urls: [
        .dev:     "https://partner.api.dev.zuperior.dev",
        .staging: "https://partner.api.stg.zuperior.dev",
        .prod:    "https://partner.api.zuperior.com",
    ], healthPath: "/health"),
]

// MARK: - Cluster

struct Cluster {
    let name: String
    let project: String
    let region: String
    let env: String
}

let clusters: [Cluster] = [
    Cluster(name: "zuperior-cluster",            project: "zuperior-development", region: "europe-west1",  env: "Development"),
    Cluster(name: "zuperior-cluster-staging",    project: "zuperior-staging",     region: "europe-north2", env: "Staging"),
    Cluster(name: "zuperior-cluster-production", project: "zuperior-production",  region: "europe-north2", env: "Production"),
]

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

let allQuickLinks: [QuickLinkDef] = [
    QuickLinkDef(id: "drive",      icon: "folder.fill",          color: Color(red: 0.98, green: 0.75, blue: 0.18),
                 title: "Google Drive",  subtitle: "Project files",
                 url: "https://drive.google.com/drive/u/0/folders/1unKOylXKGwY7-vbv-NM8EA3_dWLgwth9",
                 mandatory: true),
    QuickLinkDef(id: "figma",      icon: "pencil.and.outline",   color: Color(red: 0.65, green: 0.42, blue: 1.0),
                 title: "Figma",         subtitle: "Design files",
                 url: "https://www.figma.com/files/team/1621735770510355921/all-projects?fuid=1621735768883088798",
                 mandatory: false),
    QuickLinkDef(id: "cloudflare", icon: "shield.lefthalf.filled", color: Color(red: 0.91, green: 0.49, blue: 0.22),
                 title: "Cloudflare",    subtitle: "DNS & domains",
                 url: "https://dash.cloudflare.com/6e59ea89cb4708b962030ccffccf6eae/zuperior.com/dns/records",
                 mandatory: false),
]

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

// MARK: - LocalListener

struct LocalListener: Identifiable {
    let id = UUID()
    let port: Int
    let processName: String
}

// MARK: - SlackChannelDef

struct SlackChannelDef: Identifiable {
    let id: String          // channel slug, e.g. "trading-core"
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
}

let allSlackChannels: [SlackChannelDef] = [
    SlackChannelDef(id: "trading-pr",     icon: "arrow.triangle.pull",               color: Color(red: 0.36, green: 0.65, blue: 0.97),
                    title: "#trading-pr",     subtitle: "Pull requests"),
    SlackChannelDef(id: "trading-core",   icon: "bubble.left.and.bubble.right.fill", color: Color(red: 0.35, green: 0.73, blue: 0.42),
                    title: "#trading-core",   subtitle: "Core platform"),
    SlackChannelDef(id: "trading-qa",     icon: "checkmark.shield.fill",              color: Color(red: 0.36, green: 0.65, blue: 0.97),
                    title: "#trading-qa",     subtitle: "QA & releases"),
    SlackChannelDef(id: "trading-devops", icon: "gearshape.2.fill",                  color: Color(red: 0.91, green: 0.49, blue: 0.22),
                    title: "#trading-devops", subtitle: "Infra & deploys"),
    SlackChannelDef(id: "trading-dev",    icon: "chevron.left.forwardslash.chevron.right", color: Color(red: 0.65, green: 0.42, blue: 1.0),
                    title: "#trading-dev",    subtitle: "Dev discussions"),
    SlackChannelDef(id: "trading-design", icon: "paintbrush.fill",                   color: Color(red: 0.98, green: 0.42, blue: 0.58),
                    title: "#trading-design", subtitle: "Design & UI"),
]

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

let defaultWorkspaceRoot = NSHomeDirectory() + "/Developer/Projects/Zuperior"
