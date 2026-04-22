import SwiftUI

struct LocalInfoView: View {
    @Binding var localIP: String
    @Binding var localPort: String
    @Binding var isListening: Bool

    var onStartListening: () -> Void
    var onStopListening: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("本机IP:")
                        .foregroundColor(.secondary)
                    Text(localIP)
                        .fontWeight(.medium)
                }

                HStack(spacing: 4) {
                    Text("接收端口:")
                        .foregroundColor(.secondary)
                    TextField("端口", text: $localPort)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(isListening)
                }
            }

            Spacer()

            Button(action: {
                if isListening {
                    onStopListening()
                } else {
                    onStartListening()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isListening ? "stop.fill" : "play.fill")
                    Text(isListening ? "停止接收" : "开始接收")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isListening ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(localPort.isEmpty)
            .padding(.top, 4)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}
