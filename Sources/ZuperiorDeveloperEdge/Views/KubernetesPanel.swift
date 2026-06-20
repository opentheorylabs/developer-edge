import SwiftUI

struct KubernetesPanel: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(clusters.enumerated()), id: \.element.name) { idx, cluster in
                    clusterRow(cluster)
                    if idx < clusters.count - 1 {
                        Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, 14)
                    }
                }
            }

            Rectangle().fill(Theme.divider).frame(height: 1).padding(.top, 8)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    if let err = store.kubeError {
                        Label(String(err.prefix(70)), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.red)
                            .lineLimit(2)
                    } else if let d = store.kubeLastRefresh {
                        Label("\(store.kubeSuccessCount)/\(clusters.count) clusters · \(timeStr(d))", systemImage: "checkmark.circle.fill")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.green)
                    } else {
                        Text("Not refreshed yet")
                            .font(.system(size: Theme.FontSize.caption))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                Spacer()
                if store.kubeRefreshing {
                    ProgressView().scaleEffect(0.55).frame(width: 22, height: 16).padding(.trailing, 4)
                } else {
                    Button(action: { store.refreshKubeconfig() }) {
                        Label("Refresh All", systemImage: "arrow.clockwise")
                            .font(.system(size: Theme.FontSize.small))
                            .foregroundColor(Theme.purple)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Theme.purple.opacity(0.10)))
                            .overlay(Capsule().stroke(Theme.purple.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Rectangle().fill(Theme.divider).frame(height: 1)

            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.textMuted.opacity(0.6))
                Text("Runs: gcloud container clusters get-credentials --internal-ip")
                    .font(.system(size: Theme.FontSize.tinyMd))
                    .foregroundColor(Theme.textMuted.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
        }
    }

    @ViewBuilder
    func clusterRow(_ c: Cluster) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(clusterColor(c.env).opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: Theme.FontSize.heading))
                    .foregroundColor(clusterColor(c.env))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(c.name)
                    .font(.system(size: Theme.FontSize.title, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                Text("\(c.env) · \(c.region)")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()

            Text(c.project)
                .font(.system(size: Theme.FontSize.tiny, weight: .medium))
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Theme.badge))
        }
        .frame(height: 50)
        .padding(.horizontal, 14)
    }

    func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }
}
