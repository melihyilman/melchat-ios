import SwiftUI
import AuthenticationServices

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()
    @State private var email = ""
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 40) {
                        Spacer().frame(height: 80)

                        // Logo & Title
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.gradient)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)

                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                            }

                            VStack(spacing: 8) {
                                Text("MelChat")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))

                                Text("Privacy-First Messaging")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer().frame(height: 40)

                        // Sign In Options
                        VStack(spacing: 20) {
                            // Apple Sign In (Coming Soon)
                            Button {
                                // TODO: Implement Apple Sign In
                            } label: {
                                HStack {
                                    Image(systemName: "apple.logo")
                                        .font(.title3.bold())

                                    Text("Continue with Apple")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                            }
                            .disabled(true)
                            .opacity(0.6)

                            // Divider
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)

                                Text("or")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)

                            // Email Input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Email Address")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)

                                HStack(spacing: 12) {
                                    Image(systemName: "envelope.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)

                                    TextField("your@email.com", text: $email)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .textContentType(.emailAddress)
                                        .submitLabel(.continue)
                                        .focused($isEmailFocused)
                                        .onSubmit {
                                            if !email.isEmpty {
                                                Task { await viewModel.sendCode(email: email) }
                                            }
                                        }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isEmailFocused ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }

                            // Continue Button
                            Button {
                                isEmailFocused = false
                                Task { await viewModel.sendCode(email: email) }
                            } label: {
                                HStack {
                                    Text(viewModel.isLoading ? "Sending..." : "Continue")
                                        .font(.headline)

                                    if !viewModel.isLoading {
                                        Image(systemName: "arrow.right")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(email.isEmpty ? Color.gray.gradient : Color.blue.gradient)
                                )
                                .foregroundStyle(.white)
                                .shadow(color: email.isEmpty ? .clear : .blue.opacity(0.3), radius: 10, y: 5)
                            }
                            .disabled(email.isEmpty || viewModel.isLoading)

                            if let error = viewModel.error {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(error)
                                }
                                .font(.callout)
                                .foregroundStyle(.red)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                )
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer().frame(height: 60)

                        // Footer
                        Text("End-to-end encrypted messaging\nYour privacy is our priority")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 32)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationDestination(isPresented: $viewModel.showVerification) {
                VerificationView(email: email, viewModel: viewModel)
            }
            .onAppear {
                viewModel.appState = appState
            }
            .onTapGesture {
                isEmailFocused = false
            }
        }
    }
}

// MARK: - Verification View
struct VerificationView: View {
    let email: String
    @ObservedObject var viewModel: AuthViewModel
    @State private var code = ""
    @State private var username = ""
    @State private var showUsernameInput = false
    @FocusState private var isCodeFocused: Bool
    @FocusState private var isUsernameFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Icon
                    ZStack {
                        Circle()
                            .fill(showUsernameInput ? Color.green.gradient : Color.blue.gradient)
                            .frame(width: 90, height: 90)
                            .shadow(color: (showUsernameInput ? Color.green : Color.blue).opacity(0.3), radius: 20, y: 10)

                        Image(systemName: showUsernameInput ? "person.badge.key.fill" : "envelope.badge.shield.half.filled")
                            .font(.system(size: 45))
                            .foregroundStyle(.white)
                    }

                    // Title
                    VStack(spacing: 12) {
                        Text(showUsernameInput ? "Choose Username" : "Check Your Email")
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text(showUsernameInput ? "Pick a unique username" : "Code sent to \(email)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer().frame(height: 32)

                    if !showUsernameInput {
                        // Code Input
                        VStack(spacing: 24) {
                            VStack(spacing: 12) {
                                Text("VERIFICATION CODE")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(1)

                                TextField("000000", text: $code)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .tracking(8)
                                    .padding(.vertical, 20)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.systemBackground))
                                            .shadow(color: .black.opacity(0.05), radius: 15, y: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(isCodeFocused ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                    .frame(maxWidth: 280)
                                    .focused($isCodeFocused)
                                    .onChange(of: code) { _, newValue in
                                        if newValue.count > 6 {
                                            code = String(newValue.prefix(6))
                                        }
                                        if newValue.count == 6 {
                                            isCodeFocused = false
                                            showUsernameInput = true
                                        }
                                    }
                            }

                            Button {
                                Task { await viewModel.sendCode(email: email) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Resend Code")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            .disabled(viewModel.isLoading)
                        }
                    } else {
                        // Username Input
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("USERNAME")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(1)
                                    .padding(.leading, 4)

                                HStack(spacing: 12) {
                                    Image(systemName: "at")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)

                                    TextField("username", text: $username)
                                        .textFieldStyle(.plain)
                                        .autocapitalization(.none)
                                        .textContentType(.username)
                                        .submitLabel(.done)
                                        .focused($isUsernameFocused)
                                        .onSubmit {
                                            if !username.isEmpty {
                                                Task {
                                                    await viewModel.verify(
                                                        email: email,
                                                        code: code,
                                                        username: username.isEmpty ? nil : username
                                                    )
                                                }
                                            }
                                        }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(isUsernameFocused ? Color.green : Color.clear, lineWidth: 2)
                                )
                            }
                            .frame(maxWidth: 320)

                            Button {
                                isUsernameFocused = false
                                Task {
                                    await viewModel.verify(
                                        email: email,
                                        code: code,
                                        username: username.isEmpty ? nil : username
                                    )
                                }
                            } label: {
                                HStack {
                                    Text(viewModel.isLoading ? "Verifying..." : "Complete Setup")
                                        .font(.headline)

                                    if !viewModel.isLoading {
                                        Image(systemName: "checkmark")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(username.isEmpty ? Color.gray.gradient : Color.green.gradient)
                                )
                                .foregroundStyle(.white)
                                .shadow(color: username.isEmpty ? .clear : .green.opacity(0.3), radius: 10, y: 5)
                            }
                            .disabled(username.isEmpty || viewModel.isLoading)
                            .padding(.horizontal, 24)
                        }
                    }

                    if let error = viewModel.error {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error)
                        }
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                        .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 100)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            isCodeFocused = true
        }
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        isCodeFocused = false
                        isUsernameFocused = false
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
            }
        }
        .onTapGesture {
            isCodeFocused = false
            isUsernameFocused = false
        }
    }
}

// MARK: - Preview
#Preview("Login") {
    LoginView()
        .environmentObject(AppState())
}

#Preview("Verification") {
    NavigationStack {
        VerificationView(
            email: "test@example.com",
            viewModel: AuthViewModel()
        )
    }
}
