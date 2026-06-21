import SwiftUI
import Pow

// MARK: - Provider helpers

private var jiraBase: String {
    AppConfig.current.jira.map { "https://\($0.host)" } ?? ""
}
private var jiraBoard: String { "\(jiraBase)/jira/your-work" }
private var usingLinear: Bool { AppConfig.current.linear != nil }

struct QuickActionsPanel: View {
    @ObservedObject var store: Store
    var onOpenSettings: () -> Void = {}
    @State private var filter: String = "In Progress"

    private let filters: [(label: String, category: String, color: Color)] = [
        ("Todo",        "To Do",       Theme.textMuted),
        ("In Progress", "In Progress", Theme.blue),
        ("Done",        "Done",        Theme.green),
    ]

    var body: some View {
        if usingLinear {
            linearBody
        } else {
            jiraBody
        }
    }

    // MARK: - Linear

    private var linearBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                linearHeader
                linearTicketsBody.padding(.bottom, 14)
            }
        }
        .onAppear {
            if store.linearIssues.isEmpty { store.fetchLinearIssues() }
        }
    }

    private var linearHeader: some View {
        HStack {
            Text("MY ISSUES")
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
            if store.linearFetching {
                Spinner(size: Theme.FontSize.title, lineWidth: 1.5).frame(width: 16, height: 16)
            } else {
                if let d = store.linearLastFetch {
                    Text(RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()))
                        .font(.system(size: Theme.FontSize.tinyMd))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
                Button(action: { store.fetchLinearIssues() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(Theme.textMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Refresh Linear issues")
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }

    @ViewBuilder
    private var linearTicketsBody: some View {
        if store.linearApiKey.isEmpty {
            EmptyStateView(icon: "key.horizontal",
                           title: "Linear API key required",
                           subtitle: "Add your Linear API key in Settings to see your issues.",
                           actionTitle: "Add API Key",
                           action: onOpenSettings)
        } else if store.linearFetching && store.linearIssues.isEmpty {
            LoadingStateView(message: "Loading issues…")
        } else if let err = store.linearFetchError {
            ErrorStateView(message: err, retry: { store.fetchLinearIssues() })
        } else if store.linearIssues.isEmpty {
            EmptyStateView(icon: "checklist",
                           title: "No open issues",
                           subtitle: "Nothing assigned to you")
        } else {
            let filtered = store.linearIssues.filter { $0.statusCategory == filter }
            let label = filters.first { $0.category == filter }?.label ?? filter
            filterTabs.padding(.bottom, 4)
            if filtered.isEmpty {
                EmptyStateView(icon: "tray", title: "Nothing \(label.lowercased())", subtitle: nil)
            } else {
                issueList(filtered)
            }
        }
    }

    @ViewBuilder
    private func issueList(_ issues: [LinearIssue]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(issues.enumerated()), id: \.element.id) { i, issue in
                linearIssueRow(issue)
                    .transition(.movingParts.move(edge: .top).combined(with: .opacity))
                if i < issues.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1).padding(.horizontal, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func linearIssueRow(_ issue: LinearIssue) -> some View {
        Button(action: { if let u = URL(string: issue.url) { NSWorkspace.shared.open(u) } }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: linearPriorityIcon(issue.priority))
                    .font(.system(size: Theme.FontSize.small, weight: .semibold))
                    .foregroundColor(linearPriorityColor(issue.priority))
                    .frame(width: 14, alignment: .center)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(issue.title)
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(issue.identifier)
                            .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                        Text(issue.stateName)
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func linearPriorityIcon(_ priority: Int) -> String {
        switch priority {
        case 1: return "exclamationmark.2"
        case 2: return "arrow.up"
        case 3: return "minus"
        case 4: return "arrow.down"
        default: return "circle"
        }
    }

    private func linearPriorityColor(_ priority: Int) -> Color {
        switch priority {
        case 1: return Theme.red
        case 2: return Theme.orange
        case 3: return Theme.blue
        default: return Theme.textMuted.opacity(0.4)
        }
    }

    // MARK: - Jira

    private var jiraBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Jira")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    GridButton(data: GridButtonData(
                        icon: "square.grid.2x2", color: Theme.orange,
                        title: "Sprint Board", subtitle: "Active sprint",
                        url: jiraBoard))
                    GridButton(data: GridButtonData(
                        icon: "person.crop.circle", color: Theme.orange,
                        title: "Assigned to Me", subtitle: "Open tickets",
                        url: assignedToMeURL))
                }
                .padding(.horizontal, 14).padding(.bottom, 4)

                jiraTicketsHeader
                if !store.jiraTickets.isEmpty { filterTabs.padding(.bottom, 4) }
                jiraTicketsBody.padding(.bottom, 14)
            }
        }
        .onAppear {
            if store.jiraTickets.isEmpty { store.fetchJiraTickets() }
        }
    }

    private var jiraTicketsHeader: some View {
        HStack {
            Text("SPRINT TICKETS")
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
            if store.jiraFetching {
                Spinner(size: Theme.FontSize.title, lineWidth: 1.5).frame(width: 16, height: 16)
            } else {
                if let d = store.jiraLastFetch {
                    Text(RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date()))
                        .font(.system(size: Theme.FontSize.tinyMd))
                        .foregroundColor(Theme.textMuted.opacity(0.5))
                }
                Button(action: { store.fetchJiraTickets() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: Theme.FontSize.caption, weight: .medium))
                        .foregroundColor(Theme.textMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Refresh Jira tickets")
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }

    @ViewBuilder
    private var jiraTicketsBody: some View {
        if store.jiraApiToken.isEmpty {
            EmptyStateView(icon: "key.horizontal",
                           title: "Jira token required",
                           subtitle: "Connect Jira in Settings to see your sprint tickets.",
                           actionTitle: "Add Jira Token",
                           action: onOpenSettings)
        } else if store.jiraFetching && store.jiraTickets.isEmpty {
            LoadingStateView(message: "Loading tickets…")
        } else if let err = store.jiraFetchError {
            ErrorStateView(message: err, retry: { store.fetchJiraTickets() })
        } else if store.jiraTickets.isEmpty {
            EmptyStateView(icon: "checklist",
                           title: "No open tickets",
                           subtitle: "Nothing assigned to you in the current sprint")
        } else {
            let filtered = jiraTickets(filter)
            let label = filters.first { $0.category == filter }?.label ?? filter
            if filtered.isEmpty {
                EmptyStateView(icon: "tray", title: "Nothing \(label.lowercased())", subtitle: nil)
            } else {
                jiraTicketList(filtered)
            }
        }
    }

    private func jiraTickets(_ category: String) -> [JiraTicket] {
        store.jiraTickets.filter { $0.statusCategory == category }
    }

    @ViewBuilder
    private func jiraTicketList(_ tickets: [JiraTicket]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tickets.enumerated()), id: \.element.id) { i, ticket in
                jiraTicketRow(ticket)
                    .transition(.movingParts.move(edge: .top).combined(with: .opacity))
                if i < tickets.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1).padding(.horizontal, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func jiraTicketRow(_ ticket: JiraTicket) -> some View {
        let url = "\(jiraBase)/browse/\(ticket.key)"
        let icon = issueTypeIcon(ticket.issueType)
        let highPriority = ticket.priority == "Highest" || ticket.priority == "High" || ticket.priority == "Critical"
        Button(action: { if let u = URL(string: url) { NSWorkspace.shared.open(u) } }) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon.symbol)
                    .font(.system(size: Theme.FontSize.small, weight: .semibold))
                    .foregroundColor(icon.color)
                    .frame(width: 14, alignment: .center)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.summary)
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ticket.key)
                        .font(.system(size: Theme.FontSize.caption, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if highPriority {
                    Image(systemName: "arrow.up")
                        .font(.system(size: Theme.FontSize.tinyMd, weight: .bold))
                        .foregroundColor(priorityColor(ticket.priority))
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared filter tabs

    private var filterTabs: some View {
        HStack(spacing: 6) {
            ForEach(filters, id: \.category) { f in
                let count = usingLinear
                    ? store.linearIssues.filter { $0.statusCategory == f.category }.count
                    : store.jiraTickets.filter  { $0.statusCategory == f.category }.count
                let on = filter == f.category
                Button(action: { withAnimation(.easeInOut(duration: 0.12)) { filter = f.category } }) {
                    HStack(spacing: 5) {
                        Text(f.label)
                            .font(.system(size: Theme.FontSize.small, weight: on ? .semibold : .medium))
                            .foregroundColor(on ? .white : Theme.textMuted)
                        Text("\(count)")
                            .font(.system(size: Theme.FontSize.tinyMd, weight: .semibold))
                            .foregroundColor(on ? .white.opacity(0.9) : Theme.textMuted.opacity(0.5))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(on ? Color.white.opacity(0.2) : Color.white.opacity(0.06)))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(on ? f.color : Color.white.opacity(0.05)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Jira helpers

    private func issueTypeIcon(_ type: String?) -> (symbol: String, color: Color) {
        switch type {
        case "Bug":                        return ("ladybug.fill",          Theme.red)
        case "Story":                      return ("bookmark.fill",         Theme.green)
        case "Task":                       return ("checkmark.square.fill", Theme.blue)
        case "Spike", "Epic":              return ("bolt.fill",             Theme.purple)
        case "Sub-task", "Subtask":        return ("square.on.square.fill", Theme.blue)
        default:                           return ("doc.text.fill",         Theme.textMuted)
        }
    }

    private func priorityColor(_ priority: String?) -> Color {
        switch priority {
        case "Highest", "Critical": return Theme.red
        case "High":                return Theme.orange
        default:                    return Theme.textMuted.opacity(0.3)
        }
    }

    private var assignedToMeURL: String {
        "\(jiraBase)/issues/?jql=assignee%3DcurrentUser()%20AND%20statusCategory%20!%3DDone%20ORDER%20BY%20updated%20DESC"
    }

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }
}
