import SwiftUI
import AppKit
import Defaults

final class Store: ObservableObject {

    // MARK: - Health
    @Published var reachability: [String: ReachStatus] = [:]
    @Published var checking = false
    @Published var lastCheck: Date?

    // MARK: - Kubernetes
    @Published var kubeRefreshing = false
    @Published var kubeLastRefresh: Date?
    @Published var kubeError: String?
    @Published var kubeSuccessCount = 0

    // MARK: - Git fetch / Lens
    @Published var fetchRunning = false
    @Published var fetchOutput: String = ""
    @Published var fetchExitCode: Int32? = nil
    @Published var lastFetchDate: Date? = Defaults[.lastFetchDate]
    @Published var lensRunning = false

    var isFetchStale: Bool {
        guard let d = lastFetchDate else { return true }
        return Date().timeIntervalSince(d) > 86400
    }

    // MARK: - Settings
    @Published var workspaceRoot: String    = Defaults[.workspaceRoot]
    @Published var defaultTerminal: String  = Defaults[.defaultTerminal]
    @Published var jiraEmail: String        = Defaults[.jiraEmail]
    @Published var jiraApiToken: String     = Defaults[.jiraApiToken]
    @Published var jiraAccountId: String    = Defaults[.jiraAccountId]
    @Published var userName: String         = Defaults[.userName]
    @Published var githubToken: String      = Defaults[.githubToken]

    /// First name derived from the Jira display name, used in greetings.
    var firstName: String? {
        let first = userName.split(separator: " ").first.map(String.init)
        return (first?.isEmpty == false) ? first : nil
    }

    @Published var enabledQuickLinks: Set<String> = Defaults[.enabledQuickLinks]

    @Published var enabledSlackChannels: Set<String> = Defaults[.enabledSlackChannels]

    // MARK: - Pipelines
    @Published var pipelineStatuses: [String: PipelineStatus] = [:]
    @Published var pipelineRunURLs: [String: String] = [:]   // repo → latest run html_url
    @Published var pipelineChecking = false

    // MARK: - Localhost
    @Published var localhostPorts: [String: Int] = Defaults[.localhostPorts]
    @Published var localhostStatuses: [String: ReachStatus] = [:]
    var localhostChecking = false

    @Published var localListeners: [LocalListener] = []
    @Published var scanningListeners = false

    // MARK: - GitHub PRs
    @Published var myPRs: [PRItem] = []
    @Published var reviewRequests: [PRItem] = []
    @Published var prsFetching = false
    @Published var prsLastFetch: Date?
    /// Set by a 60s timer after each successful PR fetch · drives auto-refresh on next popover open.
    @Published var prsNeedsRefresh = true

    // MARK: - Repos / AI Instructions
    @Published var repos: [RepoInfo] = []
    @Published var repoPickerShown = false
    @Published var selectedRepo: RepoInfo? = nil
    @Published var aiSetupRunning = false
    @Published var aiSetupOutput = ""
    @Published var aiSetupExitCode: Int32? = nil

    // MARK: - Code Review Graph
    @Published var graphToolState: GraphToolState = .unknown
    @Published var graphInstallRunning = false
    @Published var graphInstallOutput = ""
    @Published var graphInstallExitCode: Int32? = nil
    @Published var graphPickerShown = false
    @Published var selectedGraphRepo: RepoInfo? = nil
    @Published var graphBuildRunning = false
    @Published var graphBuildOutput = ""
    @Published var graphBuildExitCode: Int32? = nil
    @Published var graphBuildProgress = 0   // repos completed
    @Published var graphBuildTotal = 0      // repos in this batch
    @Published var graphBuildFailures: [String] = []

    // MARK: - Workspace setup (clone all repos)
    @Published var setupRunning = false
    @Published var setupOutput = ""
    @Published var setupExitCode: Int32? = nil
    @Published var setupCloned = 0
    @Published var setupTotal = 0
    @Published var aiUpdateAvailable = false
    @Published var aiInstructionsUpdating = false
    @Published var newReposAvailable: [String] = []   // org td-* repos not yet cloned locally

    /// The workspace is considered set up if the cloned structure exists on disk
    /// (checked synchronously so the Setup button never flashes before the async scan).
    var isWorkspaceSetUp: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: workspaceRoot + "/Frontend")
            || fm.fileExists(atPath: workspaceRoot + "/Backend")
            || !repos.isEmpty
    }

    // MARK: - Session (bumped each time the popover opens)
    @Published var popoverSession = UUID()

    // MARK: - Updates
    @Published var updateAvailable = false
    @Published var updateRunning = false
    @Published var updateChecking = false

    // MARK: - Jira
    @Published var jiraTickets: [JiraTicket] = []
    @Published var jiraFetching = false
    @Published var jiraFetchError: String? = nil
    @Published var jiraLastFetch: Date?
    /// Set by a 60s timer after each successful Jira fetch · drives auto-refresh on next popover open.
    @Published var jiraNeedsRefresh = true

    // MARK: - Shared URLSession
    let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 4
        c.timeoutIntervalForResource = 4
        return URLSession(configuration: c)
    }()
}
