import SwiftUI

struct NudgeOverlay: View {
  @EnvironmentObject var stateManager: StateManager

  var body: some View {
    VStack(spacing: 20) {
      Text("Break Starting Soon...")
        .font(.system(size: 48, weight: .bold, design: .rounded))
        .foregroundColor(.white)
      Text("Get ready to relax")
        .font(.title2)
        .foregroundColor(.white.opacity(0.8))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.opacity(0.6))
  }
}
