import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "airplayaudio")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("欢迎使用 AirShout")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                StepView(
                    number: 1,
                    title: "选择 AirPlay 设备",
                    description: "点击「选择设备」按钮，从列表中选择要播放的 AirPlay 设备"
                )

                StepView(
                    number: 2,
                    title: "开始说话",
                    description: "点击「开始」按钮开始传输，再次点击「停止」结束传输"
                )

                StepView(
                    number: 3,
                    title: "实时反馈",
                    description: "波形图会实时显示麦克风音量，让你知道正在传输"
                )
            }
            .padding(.horizontal)

            Spacer()

            Button("开始使用") {
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}

struct StepView: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
