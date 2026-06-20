import SwiftUI
import Pow

private let jiraBase  = "https://zuperior-platform.atlassian.net"
private let jiraBoard = "\(jiraBase)/jira/software/projects/ZT/boards/34"

struct QuickActionsPanel: View {
    @ObservedObject var store: Store
    var onOpenSettings: () -> Void = {}
    @State private var filter: String = "In Progress"

    private let filters: [(label: String, category: String, color: Color)] = [
        ("ToDo",        "To Do",       Theme.textMuted),
        ("In Progress", "In Progress", Theme.blue),
        ("Completed",   "Done",        Theme.green),
    ]

    private func tickets(_ category: String) -> [JiraTicket] {
        store.jiraTickets.filter { $0.statusCategory == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Quick links ───────────────────────────────────────────
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

                // ── Tickets ───────────────────────────────────────────────
                ticketsSectionHeader
                if !store.jiraTickets.isEmpty { filterTabs.padding(.bottom, 4) }
                ticketsBody
                    .padding(.bottom, 14)
            }
        }
        .onAppear {
            if store.jiraTickets.isEmpty { store.fetchJiraTickets() }
        }
    }

    // MARK: - Filter tabs

    private var filterTabs: some View {
        HStack(spacing: 6) {
            ForEach(filters, id: \.category) { f in
                let on = filter == f.category
                let count = tickets(f.category).count
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

    // MARK: - Tickets header

    private var ticketsSectionHeader: some View {
        HStack {
            Text("SPRINT TICKETS")
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
            if store.jiraFetching {
                Spinner(size: Theme.FontSize.title, lineWidth: 1.5).frame(width: 16, height: 16)
            } else {
                if let lastFetchLabel {
                    Text(lastFetchLabel)
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
                .accessibilityLabel("Refresh Jira tickets")
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
    }

    // MARK: - Tickets body

    @ViewBuilder
    private var ticketsBody: some View {
        if store.jiraApiToken.isEmpty {
            EmptyStateView(icon: "key.horizontal",
                           title: "Jira token required",
                           subtitle: "Connect Jira to see your sprint tickets.",
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
            let filtered = tickets(filter)
            let label = filters.first { $0.category == filter }?.label ?? filter
            if filtered.isEmpty {
                EmptyStateView(icon: "tray",
                               title: "Nothing in \(label)",
                               subtitle: nil)
            } else {
                ticketList(filtered)
            }
        }
    }

    // MARK: - Ticket list

    @ViewBuilder
    private func ticketList(_ tickets: [JiraTicket]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(tickets.enumerated()), id: \.element.id) { i, ticket in
                ticketRow(ticket)
                    .transition(.movingParts.move(edge: .top).combined(with: .opacity))
                if i < tickets.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1).padding(.horizontal, 14)
                }
            }
        }
    }

    @ViewBuilder
    private func ticketRow(_ ticket: JiraTicket) -> some View {
        let url = "\(jiraBase)/browse/\(ticket.key)"
        let icon = issueTypeIcon(ticket.issueType)
        let highPriority = ticket.priority == "Highest" || ticket.priority == "High" || ticket.priority == "Critical"
        Button(action: { NSWorkspace.shared.open(URL(string: url)!) }) {
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
                        .truncationMode(.tail)
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

    // MARK: - Issue type icon (Jira style)

    private func issueTypeIcon(_ type: String?) -> (symbol: String, color: Color) {
        switch type {
        case "Bug":            return ("ladybug.fill",         Theme.red)
        case "Story":          return ("bookmark.fill",        Theme.green)
        case "Task":           return ("checkmark.square.fill", Theme.blue)
        case "Spike":          return ("bolt.fill",            Theme.purple)
        case "Epic":           return ("bolt.fill",            Theme.purple)
        case "Sub-task", "Subtask":
                               return ("square.on.square.fill", Theme.blue)
        default:               return ("doc.text.fill",        Theme.textMuted)
        }
    }

    // MARK: - Helpers

    private var lastFetchLabel: String? {
        guard let d = store.jiraLastFetch else { return nil }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: d, relativeTo: Date())
    }

    private func priorityColor(_ priority: String?) -> Color {
        switch priority {
        case "Highest", "Critical": return Theme.red
        case "High":                return Theme.orange
        case "Medium":              return Theme.blue
        default:                    return Theme.textMuted.opacity(0.3)
        }
    }

    private var assignedToMeURL: String {
        guard !store.jiraAccountId.isEmpty else {
            return "\(jiraBase)/issues/?jql=project%3DZT%20AND%20assignee%3DcurrentUser()%20AND%20statusCategory%20!%3DDone%20ORDER%20BY%20updated%20DESC"
        }
        let enc = store.jiraAccountId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? store.jiraAccountId
        return "\(jiraBoard)?assignee=\(enc)"
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
