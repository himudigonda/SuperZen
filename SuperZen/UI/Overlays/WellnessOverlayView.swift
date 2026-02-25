import SwiftUI

struct WellnessOverlayView: View {
  let type: WellnessManager.NudgeType

  var body: some View {
    ZStack {
      // Dim the background
      Color.black.opacity(0.7).ignoresSafeArea()

      VStack(spacing: 30) {
        ZStack {
          Circle()
            .fill(type == .blink ? Theme.gradientBalanced : Theme.gradientCasual)
            .frame(width: 180, height: 180)
            .shadow(color: .black.opacity(0.5), radius: 20)

          Image(systemName: type == .blink ? "eye.fill" : "chevron.up.circle.fill")
            .font(.system(size: 80))
            .foregroundColor(.white)

          if type == .blink {
            Text("> <")
              .font(.system(size: 40, weight: .black))
              .foregroundColor(.white)
              .offset(y: 10)
          }
        }

        Text(type == .blink ? "Blink your eyes" : "Check your posture")
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
    }
  }
}
