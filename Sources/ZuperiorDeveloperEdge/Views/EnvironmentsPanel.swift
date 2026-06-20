import SwiftUI

struct EnvironmentsPanel: View {
    @ObservedObject var store: Store
    @State private var activeEnv: Env = .dev

    private var frontends: [ZService] { allServices.filter { $0.kind == .frontend } }
    private var apis: [ZService]      { allServices.filter { $0.kind == .api } }

    private func envColor(_ env: Env) -> Color {
        switch env {
        case .dev:     return Theme.green
        case .staging: return Theme.orange
        case .prod:    return Theme.blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            envSwitcher
            Rectangle().fill(Theme.divider).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Quick Actions")
                    envQuickActions(env: activeEnv)
                        .padding(.horizontal, 14).padding(.bottom, 4)

                    sectionHeader("Frontends")
                    tableColumnHeader
                    rows(frontends, env: activeEnv)

                    sectionHeader("APIs")
                    tableColumnHeader
                    rows(apis, env: activeEnv)
                }
                .padding(.top, 2)
                .padding(.bottom, 6)
            }
        }
        .onAppear { store.fetchPipelineStatuses(env: activeEnv) }
        .onChange(of: activeEnv) { env in store.fetchPipelineStatuses(env: env) }
    }

    // MARK: - Env switcher

    private var envSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(Env.allCases, id: \.rawValue) { env in
                let on = activeEnv == env
                let color = envColor(env)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { activeEnv = env }
                }) {
                    Text(env.label)
                        .font(.system(size: Theme.FontSize.body, weight: on ? .semibold : .medium))
                        .foregroundColor(on ? color : Theme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(on ? color.opacity(0.15) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: Theme.FontSize.caption, weight: .semibold)).tracking(0.8)
                .foregroundColor(Theme.textMuted)
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var tableColumnHeader: some View {
        HStack(spacing: 0) {
            Spacer()
            Text("HEALTH")
                .font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
                .foregroundColor(Theme.textMuted.opacity(0.4))
                .frame(width: 48, alignment: .leading)
                .padding(.leading, 10)
            if !store.githubToken.isEmpty {
                Text("CI")
                    .font(.system(size: 8.5, weight: .semibold)).tracking(0.5)
                    .foregroundColor(Theme.textMuted.opacity(0.4))
                    .frame(width: 62, alignment: .leading)
                    .padding(.leading, 10)
            }
            Spacer().frame(width: 14)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 3)
    }

    @ViewBuilder
    private func envQuickActions(env: Env) -> some View {
        if let grafana = env.grafanaURL, !grafana.isEmpty {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                GridButton(data: GridButtonData(
                    icon: "chart.xyaxis.line", color: Theme.orange,
                    title: "Open Grafana", subtitle: "\(env.label) Metrics",
                    url: grafana
                ))
            }
        }
    }

    @ViewBuilder
    private func rows(_ services: [ZService], env: Env) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(services.enumerated()), id: \.element.id) { i, svc in
                ServiceTableRow(svc: svc, env: env, store: store)
                if i < services.count - 1 {
                    Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
                }
            }
        }
    }
}
