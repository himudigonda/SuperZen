import SwiftUI

struct ContentView: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "eye.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 100, height: 100)
        .foregroundColor(.accentColor)

      VStack {
        Text("SuperZen")
          .font(.largeTitle)
          .fontWeight(.bold)

        Text(stateManager.status.description)
          .font(.title2)
          .foregroundColor(.secondary)
      }

      Divider()

      HStack(spacing: 40) {
        VStack {
          Text("Work")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(formatTime(stateManager.workTimeRemaining))
            .font(.title3)
            .bold()
        }

        VStack {
          Text("Break")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(Int(stateManager.breakTimeRemaining))s")
            .font(.title3)
            .bold()
        }
      }

      Button {
        stateManager.togglePause()
      } label: {
        Text(stateManager.status == .paused ? "Resume Session" : "Pause Session")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
    }
    .padding(40)
    .frame(minWidth: 400, minHeight: 400)
  }

  private func formatTime(_ seconds: TimeInterval) -> String {
    let mins = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", mins, secs)
  }
}

#Preview {
  ContentView()
    .environmentObject(StateManager())
}
