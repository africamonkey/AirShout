import SwiftUI

struct ConnectionListView: View {
    @Binding var savedConnections: [SavedConnection]
    @Binding var selectedConnection: SavedConnection?
    @Binding var showAddConnection: Bool

    var onSelect: (SavedConnection) -> Void
    var onDelete: (IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已保存的连接")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showAddConnection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 4)

            if savedConnections.isEmpty {
                Text("暂无保存的连接")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(savedConnections) { connection in
                        ConnectionItemView(
                            connection: connection,
                            isSelected: selectedConnection?.id == connection.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedConnection = connection
                            onSelect(connection)
                        }
                    }
                    .onDelete(perform: onDelete)
                }
                .listStyle(.plain)
            }
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

struct ConnectionItemView: View {
    let connection: SavedConnection
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(connection.ip):\(connection.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddConnectionSheet: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var ip: String = ""
    @State private var port: String = ""

    var onSave: (String, String, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("连接信息") {
                    TextField("名称", text: $name)
                    TextField("IP地址", text: $ip)
                        .keyboardType(.decimalPad)
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("添加连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name, ip, port)
                        isPresented = false
                    }
                    .disabled(name.isEmpty || ip.isEmpty || port.isEmpty)
                }
            }
        }
    }
}