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

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 2)
                .fill(isHighlighted ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(height: geometry.size.height * CGFloat(max(0.05, level)))
                .animation(.easeInOut(duration: 0.05), value: level)
        }
    }
}

#Preview {
    WaveformView(audioLevel: 0.7)
        .frame(height: 60)
}
