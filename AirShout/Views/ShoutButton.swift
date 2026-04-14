import SwiftUI
import UIKit

struct ShoutButton: View {
    let isActive: Bool
    let onTap: () -> Void

    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color.red : Color.accentColor)
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 110, height: 110)

            Text(isActive ? "停止" : "开始")
                .font(.headline)
                .foregroundColor(.white)
        }
        .scaleEffect(isActive ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isActive)
        .gesture(
            TapGesture()
                .onEnded {
                    if isActive {
                        notificationGenerator.notificationOccurred(.warning)
                    } else {
                        impactGenerator.impactOccurred()
                    }
                    onTap()
                }
        )
    }
}

#Preview {
    ShoutButton(isActive: false) {
        print("Tapped")
    }
}
