import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDebugMenu = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Text("M")
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading) {
                            Text("MelChat User")
                                .font(.title3.bold())
                            Text("@username")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 8)
                    }
                    .padding(.vertical, 8)
                }

                Section("Privacy") {
                    Toggle("Show Online Status", isOn: .constant(true))
                    Toggle("Read Receipts", isOn: .constant(true))
                }

                Section("Developer") {
                    Button {
                        showDebugMenu = true
                    } label: {
                        Label("Network Logs", systemImage: "network")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Text("Logout")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDebugMenu) {
                NetworkLoggerView()
            }
        }
    }
}
