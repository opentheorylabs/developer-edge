import Foundation
import Defaults

extension Defaults.Keys {
    // MARK: - Settings
    static let workspaceRoot = Key<String>("workspaceRoot", default: defaultWorkspaceRoot)
    static let defaultTerminal = Key<String>("defaultTerminal", default: "terminal")
    static let jiraEmail = Key<String>("jiraEmail", default: "")
    static let jiraAccountId = Key<String>("jiraAccountId", default: "")
    static let userName = Key<String>("userName", default: "")

    // MARK: - Legacy token keys (migration only — DO NOT write)
    // These exist solely for Keychain.migratingRead to find old UserDefaults values
    // and move them to the Keychain on first launch. Never write tokens here.
    static let githubToken  = Key<String>("githubToken",  default: "")
    static let jiraApiToken = Key<String>("jiraApiToken", default: "")
    static let linearApiKey = Key<String>("linearApiKey", default: "")
    static let onboardingComplete = Key<Bool>("onboardingComplete", default: false)

    // MARK: - Quick links
    static let enabledQuickLinks = Key<Set<String>>(
        "enabledQuickLinks",
        default: Set(allQuickLinks.filter(\.mandatory).map(\.id))
    )

    // MARK: - CI repo filter
    static let pinnedRepos = Key<Set<String>>("pinnedRepos", default: Set<String>())

    // MARK: - Localhost
    static let localhostPorts = Key<[String: Int]>("localhostPorts", default: [:])

    // MARK: - Git fetch
    static let lastFetchDate = Key<Date?>("lastFetchDate")

    // MARK: - Login item
    static let didRegisterLoginItem = Key<Bool>("didRegisterLoginItem", default: false)

    // MARK: - Footer message
    static let footerLaunchCount = Key<Int>("footerLaunchCount", default: 0)
    static let footerLastMorningGreetDate = Key<Date?>("footerLastMorningGreetDate")

    // MARK: - Repo path (written by make-app.sh)
    static let repoPath = Key<String?>("repoPath")
}
