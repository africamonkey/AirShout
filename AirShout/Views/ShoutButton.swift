import SwiftUI
import UIKit

struct ShoutButton: View {
    let isPressed: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            Circle()
                .fill(isPressed ? Color.red : Color.accentColor)
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 3)
                .frame(width: 110, height: 110)

            Text(isPressed ? "松开发送" : "按住说话")
                .font(.headline)
                .foregroundColor(.white)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        impactGenerator.impactOccurred()
                        onPress()
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        onRelease()
                    }
                }
        )
    }
}

#Preview {
    ShoutButton(isPressed: false) {
        print("Pressed")
    } onRelease: {
        print("Released")
    }
}
