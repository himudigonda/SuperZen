import SwiftUI

struct ContentView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "eye.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 100, height: 100)
        .foregroundColor(statusColor)

      VStack(spacing: 8) {
        Text("SuperZen")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text(stateManager.status.description)
          .font(.title2)
          .foregroundColor(statusColor)
          .contentTransition(.opacity)
          .animation(.easeInOut, value: stateManager.status)

        if case .paused(let reason) = stateManager.status {
          Text("Smart Pause active because you are \(reason.rawValue)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      VStack {
        Text(formatTime(stateManager.timeRemaining))
          .font(.system(size: 64, weight: .bold, design: .rounded))
          .monospacedDigit()
      }

      Divider()

      Button {
        stateManager.togglePause()
      } label: {
        Text(stateManager.status.isPaused ? "Resume Session" : "Pause Session")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding(40)
    .frame(minWidth: 400, minHeight: 400)
  }

  private var statusColor: Color {
    switch stateManager.status {
    case .active: return .accentColor
    case .nudge: return .orange
    case .onBreak: return .green
    case .paused: return .secondary
    case .idle: return .gray
    }
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let positiveSeconds = max(0, seconds)
    let mins = Int(positiveSeconds) / 60
    let secs = Int(positiveSeconds) % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
