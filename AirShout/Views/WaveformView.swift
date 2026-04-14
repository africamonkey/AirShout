import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let barCount: Int = 30

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    level: levelForBar(at: index),
                    isHighlighted: isBarHighlighted(at: index)
                )
            }
        }
        .padding(.horizontal)
    }

    private func levelForBar(at index: Int) -> Float {
        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)
        let falloff = 1.0 - (Float(distanceFromCenter) / Float(centerIndex))
        return audioLevel * falloff
    }

    private func isBarHighlighted(at index: Int) -> Bool {
        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)
        return Float(distanceFromCenter) / Float(centerIndex) < 0.5
    }
}

struct WaveformBar: View {
    let level: Float
    let isHighlighted: Bool

    private let barGradient = LinearGradient(
        colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
        startPoint: .bottom,
        endPoint: .top
    )

    private let inactiveStyle = Color.gray.opacity(0.3)

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 3)
                .foregroundStyle(isHighlighted ? AnyShapeStyle(barGradient) : AnyShapeStyle(inactiveStyle))
                .frame(height: geometry.size.height * CGFloat(max(0.05, level)))
                .shadow(
                    color: isHighlighted ? .purple.opacity(0.5) : .clear,
                    radius: 4
                )
                .animation(.easeInOut(duration: 0.05), value: level)
        }
    }
}

#Preview {
    WaveformView(audioLevel: 0.7)
        .frame(height: 60)
}