import SwiftUI

struct NetworkView: View {
    @StateObject private var viewModel = NetworkViewModel()

    private var buttonBackgroundColor: Color {
        let canStart = viewModel.selectedConnection != nil && viewModel.connectionStatus != .connecting
        if viewModel.isTransmitting {
            return .red
        } else if canStart {
            return .blue
        } else {
            return .gray
        }
    }

    var body: some View {
        NavigationStack {
            Text("手动输入 IP 地址连接")
                .font(.headline)
            Text("（专业版）")
                .font(.footnote)
            VStack(spacing: 16) {
                LocalInfoView(
                    localIP: $viewModel.localIP,
                    localPort: $viewModel.localPort,
                    isListening: $viewModel.isListening,
                    onStartListening: { viewModel.startListening() },
                    onStopListening: { viewModel.stopListening() }
                )

                ConnectionListView(
                    savedConnections: $viewModel.savedConnections,
                    selectedConnection: $viewModel.selectedConnection,
                    showAddConnection: $viewModel.showAddConnection,
                    onSelect: { _ in },
                    onDelete: { viewModel.removeConnection(at: $0) }
                )

                Spacer()

                VStack(spacing: 16) {
                    WaveformView(audioLevel: viewModel.audioLevel)
                        .frame(height: 60)

                    ConnectionStatusView(status: viewModel.connectionStatus)
                        .padding(.bottom, 8)

                    HStack(spacing: 16) {
                        Button(action: {
                            if viewModel.isTransmitting {
                                viewModel.stopTransmission()
                            } else {
                                viewModel.startTransmission()
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.isTransmitting ? "stop.fill" : "play.fill")
                                Text(viewModel.isTransmitting ? "停止发送" : "开始发送")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(buttonBackgroundColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!viewModel.isTransmitting && viewModel.selectedConnection == nil)
                        .disabled(viewModel.connectionStatus == .connecting)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .sheet(isPresented: $viewModel.showAddConnection) {
                AddConnectionSheet(
                    isPresented: $viewModel.showAddConnection,
                    onSave: { name, ip, port in
                        viewModel.addConnection(name: name, ip: ip, port: port)
                    }
                )
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
