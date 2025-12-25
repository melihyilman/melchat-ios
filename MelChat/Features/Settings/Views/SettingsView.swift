import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showDebugMenu = false
    @State private var showEditProfile = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack(spacing: 16) {
                            // Avatar
                            ZStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 70, height: 70)
                                        .clipShape(Circle())
                                } else {
                                    AvatarView(
                                        name: viewModel.displayName.isEmpty ? viewModel.username : viewModel.displayName,
                                        size: 70
                                    )
                                }
                                
                                // Camera badge
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                    )
                                    .offset(x: 25, y: 25)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(viewModel.displayName.isEmpty ? "Set Display Name" : viewModel.displayName)
                                    .font(.title3.bold())
                                    .foregroundStyle(.primary)
                                
                                Text("@\(viewModel.username.isEmpty ? "username" : viewModel.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if !viewModel.email.isEmpty {
                                    Text(viewModel.email)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                // Privacy Settings
                Section {
                    Toggle(isOn: $viewModel.showOnlineStatus) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Online Status")
                                .font(.body)
                            Text("Others can see when you're online")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.blue)
                    
                    Toggle(isOn: $viewModel.showReadReceipts) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Read Receipts")
                                .font(.body)
                            Text("Send and receive read receipts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.blue)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Changing these settings affects all chats")
                        .font(.caption)
                }

                // Security
                Section("Security") {
                    NavigationLink {
                        EncryptionInfoView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Encryption Keys")
                                Text("View your encryption status")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Developer Tools
                Section("Developer") {
                    Button {
                        showDebugMenu = true
                    } label: {
                        Label("Network Logs", systemImage: "network")
                    }
                    
                    Button {
                        // Copy user ID to clipboard
                        if let userId = appState.currentUserId {
                            UIPasteboard.general.string = userId.uuidString
                            HapticManager.shared.success()
                        }
                    } label: {
                        Label("Copy User ID", systemImage: "doc.on.doc")
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (MVP)")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Encryption")
                        Spacer()
                        Text("Signal Protocol")
                            .foregroundStyle(.secondary)
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        HapticManager.shared.medium()
                        appState.logout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDebugMenu) {
                NetworkLoggerView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
            .task {
                await viewModel.loadProfile()
            }
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var editedDisplayName: String = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Avatar
                    HStack {
                        Spacer()
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            ZStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else {
                                    AvatarView(
                                        name: editedDisplayName.isEmpty ? viewModel.username : editedDisplayName,
                                        size: 100
                                    )
                                }
                                
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .foregroundStyle(.white)
                                    )
                                    .offset(x: 35, y: 35)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                Section {
                    TextField("Display Name", text: $editedDisplayName)
                        .textContentType(.name)
                    
                    HStack {
                        Text("Username")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("@\(viewModel.username)")
                    }
                } header: {
                    Text("Profile Info")
                } footer: {
                    Text("Username cannot be changed")
                        .font(.caption)
                }
                
                Section {
                    Button {
                        Task {
                            viewModel.displayName = editedDisplayName
                            await viewModel.updateProfile()
                            HapticManager.shared.success()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isLoading || editedDisplayName.isEmpty)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(selectedImage: $selectedImage)
            }
            .onAppear {
                editedDisplayName = viewModel.displayName
            }
        }
    }
}

// MARK: - Encryption Info View
struct EncryptionInfoView: View {
    @State private var hasKeys = false
    @State private var keyInfo: String = "Checking..."
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: hasKeys ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(hasKeys ? .green : .red)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            
            Section("Encryption Status") {
                HStack {
                    Text("Protocol")
                    Spacer()
                    Text("Signal Protocol")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Key Exchange")
                    Spacer()
                    Text("Curve25519")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Encryption")
                    Spacer()
                    Text("AES-GCM-256")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    Text(hasKeys ? "Active" : "No Keys")
                        .foregroundStyle(hasKeys ? .green : .red)
                        .font(.headline)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🔐 End-to-End Encrypted")
                        .font(.headline)
                    
                    Text("Your messages are protected with Signal Protocol. Only you and the recipient can read them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            if !hasKeys {
                Section {
                    Button {
                        Task {
                            do {
                                try EncryptionManager.shared.generateKeys()
                                hasKeys = true
                                HapticManager.shared.success()
                            } catch {
                                HapticManager.shared.error()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Generate Encryption Keys")
                                .font(.headline)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Encryption")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            hasKeys = EncryptionManager.shared.hasKeys()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

