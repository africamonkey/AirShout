import SwiftUI

enum WaveformStyle: String, CaseIterable, Codable {
    case classic = "classic"
    case pulse = "pulse"
    case wave = "wave"

    var displayName: String {
        switch self {
        case .classic: return "经典条形"
        case .pulse: return "圆形脉冲"
        case .wave: return "波浪线"
        }
    }
}

struct WaveformView: View {
    let audioLevel: Float
    var style: WaveformStyle = .classic
    let barCount: Int = 30

    private var centerIndex: Int { barCount / 2 }

    private let maxRadius: CGFloat = 100
    private let barLengthMultiplier: CGFloat = 0.4

    var body: some View {
        switch style {
        case .classic:
            classicWaveform
        case .pulse:
            pulseWaveform
        case .wave:
            waveWaveform
        }
    }

    private var classicWaveform: some View {
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

    private var pulseWaveform: some View {
        ZStack {
            ForEach(0..<barCount, id: \.self) { index in
                PulseBar(
                    index: index,
                    total: barCount,
                    level: audioLevel,
                    maxRadius: maxRadius,
                    barLengthMultiplier: barLengthMultiplier
                )
            }
        }
        .animation(.easeInOut(duration: 0.05), value: audioLevel)
    }

    private var waveWaveform: some View {
        WaveLineView(audioLevel: audioLevel, barCount: barCount)
            .animation(.easeInOut(duration: 0.05), value: audioLevel)
    }

    private func levelForBar(at index: Int) -> Float {
        let distanceFromCenter = abs(index - centerIndex)
        let falloff = 1.0 - (Float(distanceFromCenter) / Float(centerIndex))
        return audioLevel * falloff
    }

    private func isBarHighlighted(at index: Int) -> Bool {
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

struct PulseBar: View {
    let index: Int
    let total: Int
    let level: Float
    let maxRadius: CGFloat
    let barLengthMultiplier: CGFloat

    private var angle: Double {
        Double(index) / Double(total) * 2 * .pi - .pi / 2
    }

    private var barLength: CGFloat {
        CGFloat(max(0.1, level)) * maxRadius * barLengthMultiplier
    }

    var body: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 4, height: barLength)
                .offset(y: -maxRadius / 2 + barLength / 2)
                .rotationEffect(.radians(angle))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WaveLineView: View {
    let audioLevel: Float
    let barCount: Int

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                let stepX = width / CGFloat(barCount - 1)

                path.move(to: CGPoint(x: 0, y: midY))

                for i in 0..<barCount {
                    let x = CGFloat(i) * stepX
                    let amplitude = CGFloat(audioLevel) * midY * 0.8
                    let frequency = sin(Double(i) / Double(barCount) * .pi * 2)
                    let y = midY - amplitude * CGFloat(frequency)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.blue.opacity(0.9), .purple.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

#Preview {
    WaveformView(audioLevel: 0.7)
        .frame(height: 60)
}