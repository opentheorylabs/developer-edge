import SwiftUI

// Reusable content-state views · loading / empty / error · styled consistently
// across tabs (inspired by aschuch/StatefulViewController, adapted for SwiftUI).

/// Lightweight custom spinner. Avoids NSProgressIndicator, which renders dark/oversized
/// on the dark panel; this gives full control over color and size.
struct Spinner: View {
    var color: Color = Theme.textMuted
    var size: CGFloat = 16
    var lineWidth: CGFloat = 2

    @State private var spinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.72)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

/// Centered loading state with the shared spinner and an optional caption.
struct LoadingStateView: View {
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Spinner(color: Theme.textMuted, size: 20)
            if let message {
                Text(message)
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
    }
}

/// Centered empty state: icon + title + optional subtitle.
struct EmptyStateView: View {
    var icon: String = "tray"
    var iconColor: Color = Theme.textMuted.opacity(0.5)
    var title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(iconColor)
            Text(title)
                .font(.system(size: Theme.FontSize.heading, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: Theme.FontSize.title, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
        .padding(.horizontal, 28)
    }
}

/// Centered error state with an optional Retry action.
struct ErrorStateView: View {
    var message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .light))
                .foregroundColor(Theme.red.opacity(0.8))
            Text(message)
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(action: retry) {
                    Text("Retry")
                        .font(.system(size: Theme.FontSize.small, weight: .medium))
                        .foregroundColor(Theme.blue)
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.blue.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
        .padding(.horizontal, 28)
    }
}
