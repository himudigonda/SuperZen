import SwiftUI

struct AboutView: View {
  let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.7"
  let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "9"

  var body: some View {
    VStack(spacing: 32) {
      Spacer().frame(height: 20)

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

          ZenRowDivider()

          ZenRow(title: "GitHub") {
            Link(destination: URL(string: "https://github.com/himudigonda")!) {
              HStack(spacing: 4) {
                Text("@himudigonda").font(.system(size: 13))
                Image(systemName: "arrow.up.right")
                  .font(.system(size: 10))
              }
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
          }

          ZenRowDivider()

          ZenRow(title: "LinkedIn") {
            Link(destination: URL(string: "https://linkedin.com/in/himudigonda")!) {
              HStack(spacing: 4) {
                Text("Connect").font(.system(size: 13))
                Image(systemName: "arrow.up.right")
                  .font(.system(size: 10))
              }
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
          }

          ZenRowDivider()

          ZenRow(title: "Support") {
            Text("himudigonda@gmail.com")
              .font(.system(size: 13))
              .foregroundColor(Theme.textSecondary)
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

}
