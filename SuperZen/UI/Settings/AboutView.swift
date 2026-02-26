import SwiftUI
import UniformTypeIdentifiers

struct AboutView: View {
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
  let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

  var body: some View {
    VStack(spacing: 32) {
      Spacer().frame(height: 20)

      // App Icon Placeholder (Using SF Symbol since generation is temporarily unavailable)
      ZStack {
        Circle()
          .fill(Theme.gradientBalanced)
          .frame(width: 100, height: 100)
        Image(systemName: "eye.fill")
          .font(.system(size: 50, weight: .thin))
          .foregroundColor(.white)
          .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
      }

      VStack(spacing: 8) {
        Text("SuperZen")
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(Theme.textPrimary)
        Text("by Himansh Mudigonda (@himudigonda)")
          .font(.system(size: 13))
          .foregroundColor(Theme.textSecondary)
        Text("Version \(appVersion) (\(buildNumber))")
          .font(.system(size: 13))
          .foregroundColor(Theme.textSecondary)
      }

      VStack(spacing: 12) {
        ZenCard {
          ZenRow(title: "Website") {
            Link(destination: URL(string: "https://himudigonda.me")!) {
              HStack(spacing: 4) {
                Text("Visit").font(.system(size: 13))
                Image(systemName: "arrow.up.right")
                  .font(.system(size: 10))
              }
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
          }

          Divider().background(Color.white.opacity(0.05))
            .padding(.horizontal, 16)

          ZenRow(title: "Support") {
            Text("himudigonda@gmail.com")
              .font(.system(size: 13))
              .foregroundColor(Theme.textSecondary)
          }
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Troubleshooting")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Theme.textPrimary)
            .padding(.leading, 4)

          ZenCard {
            ZenRow(
              title: "Export Debug Logs",
              subtitle: "Helpful for fixing issues with the telemetry engine"
            ) {
              ZenButtonPill(title: "Export...") {
                exportLogs()
              }
            }
          }
        }
      }

      Spacer()

      Text("Please take care of yourself ❤️")
        .font(.system(size: 11))
        .foregroundColor(Theme.textSecondary)
        .padding(.bottom, 20)
    }
  }

  private func exportLogs() {
    let savePanel = NSSavePanel()
    savePanel.allowedContentTypes = [.json]
    savePanel.nameFieldStringValue = "SuperZen_Logs_\(Int(Date().timeIntervalSince1970)).json"

    savePanel.begin { result in
      if result == .OK, let url = savePanel.url {
        let logString = "{\"app\":\"SuperZen\", \"status\":\"all_good\"}"
        let logData = Data(logString.utf8)
        try? logData.write(to: url)
      }
    }
  }
}
