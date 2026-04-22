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

            Text(String(format: String(localized: "onboarding.welcome"), arguments: [appName]))
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 24) {
                StepView(
                    number: 1,
                    title: String(localized: "onboarding.step.1.title"),
                    description: String(localized: "onboarding.step.1.desc")
                )

                StepView(
                    number: 2,
                    title: String(localized: "onboarding.step.2.title"),
                    description: String(format: String(localized: "onboarding.step.2.desc"), arguments: [appName])
                )

                StepView(
                    number: 3,
                    title: String(localized: "onboarding.step.3.title"),
                    description: String(localized: "onboarding.step.3.desc")
                )

                StepView(
                    number: 4,
                    title: String(localized: "onboarding.step.4.title"),
                    description: String(localized: "onboarding.step.4.desc")
                )
            }
            .padding(.horizontal)

            Spacer()

            Button(String(localized: "onboarding.start")) {
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
