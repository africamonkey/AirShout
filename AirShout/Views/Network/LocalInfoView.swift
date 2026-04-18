import SwiftUI

struct LocalInfoView: View {
    @Binding var localIP: String
    @Binding var localPort: String
    @Binding var isListening: Bool

    var onStartListening: () -> Void
    var onStopListening: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本机信息")
                .font(.headline)
                .padding(.bottom, 4)

            HStack {
                Text("IP:")
                    .foregroundColor(.secondary)
                Text(localIP)
                    .fontWeight(.medium)
            }

            HStack {
                Text("端口:")
                    .foregroundColor(.secondary)
                TextField("端口", text: $localPort)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .disabled(isListening)
            }

            Button(action: {
                if isListening {
                    onStopListening()
                } else {
                    onStartListening()
                }
            }) {
                HStack {
                    Image(systemName: isListening ? "stop.fill" : "play.fill")
                    Text(isListening ? "停止监听" : "开始监听")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isListening ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(localPort.isEmpty)
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