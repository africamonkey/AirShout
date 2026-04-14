import SwiftUI
import UIKit

struct ShoutButton: View {
    let isActive: Bool
    let onTap: () -> Void

    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private let activeGradient = LinearGradient(
        colors: [.red, .red.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private let inactiveGradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? activeGradient : inactiveGradient)
                .frame(width: 120, height: 120)
                .shadow(
                    color: isActive ? .red.opacity(0.4) : .purple.opacity(0.4),
                    radius: 15,
                    x: 0,
                    y: 8
                )

            Circle()
                .stroke(Color.white.opacity(0.4), lineWidth: 3)
                .frame(width: 110, height: 110)

            Text(isActive ? "停止" : "开始")
                .font(.headline)
                .fontWeight(.semibold)
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