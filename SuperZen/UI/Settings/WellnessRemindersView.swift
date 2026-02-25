import SwiftUI

struct WellnessRemindersView: View {
  @AppStorage("postureEnabled") var postureEnabled = true
  @AppStorage("postureFrequency") var postureFrequency = 10
  @AppStorage("blinkEnabled") var blinkEnabled = true
  @AppStorage("blinkFrequency") var blinkFrequency = 5

  @AppStorage("dimScreenWellness") var dimScreen = true

  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      HStack(spacing: 20) {
        WellnessCard(
          title: "Posture Reminder",
          subtitle: "Helps maintain good posture by gently alerting you to sit upright.",
          icon: "chevron.up.circle.fill", color: .pink, enabled: $postureEnabled,
          freq: $postureFrequency)

        WellnessCard(
          title: "Blink Reminder",
          subtitle: "Prevents dry eyes by gently nudging you to blink at healthy intervals.",
          icon: "eye.fill", color: .blue, enabled: $blinkEnabled, freq: $blinkFrequency)
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("Common settings").font(.system(size: 13, weight: .bold)).foregroundColor(
          Theme.textPrimary)
        ZenCard {
          ZenRow(title: "Dim the screen when showing reminders") {
            Toggle("", isOn: $dimScreen).toggleStyle(.switch).tint(Theme.accent)
          }
          Divider().background(Color.white.opacity(0.05))
          ZenRow(title: "Reset timers after break") {
            Toggle("", isOn: .constant(true)).toggleStyle(.switch).tint(Theme.accent)
          }
        }
      }
    }
  }
}

struct WellnessCard: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color
  @Binding var enabled: Bool
  @Binding var freq: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text(title).font(.system(size: 14, weight: .bold))
          .foregroundColor(Theme.textPrimary)
        Spacer()
        Image(systemName: "play.circle")
          .foregroundColor(Theme.textSecondary)
      }
      Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary).lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)

      ZStack {
        RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.2))
        Image(systemName: icon).font(.system(size: 40)).foregroundColor(color)
      }.frame(height: 120)

      ZenRow(title: "Enabled") {
        Toggle("", isOn: $enabled).toggleStyle(.switch).tint(Theme.accent)
      }.padding(.horizontal, -16)

      ZenRow(title: "Show Every") {
        Menu {
          ForEach([1, 5, 10, 20], id: \.self) { minutes in
            Button("\(minutes) minutes") { freq = minutes }
          }
        } label: {
          ZenPickerPill(text: "\(freq) minutes")
        }
        .menuStyle(.borderlessButton)
      }.padding(.horizontal, -16)
    }
    .padding(16)
    .background(Theme.cardBG)
    .cornerRadius(12)
  }
}
