import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "AppName"
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("AppImage")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(16)

            Text("欢迎使用 \(appName)")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                StepView(
                    number: 1,
                    title: "AirPlay 设备喊话",
                    description: "选择 AirPlay 或蓝牙设备，将声音无线传输到电视、音响等设备"
                )

                StepView(
                    number: 2,
                    title: "发现附近设备",
                    description: "自动搜索同样运行了 \(appName) 的 iOS 设备，将声音传输到对方设备"
                )

                StepView(
                    number: 3,
                    title: "手动 IP 连接",
                    description: "输入对方 iOS 设备的 IP 地址，在对方设备上点击「开始接收」后，将声音传输到对方设备"
                )

                StepView(
                    number: 4,
                    title: "按下说话",
                    description: "按下按钮开始传输，再次按下停止，波形图实时反馈音量"
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
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
