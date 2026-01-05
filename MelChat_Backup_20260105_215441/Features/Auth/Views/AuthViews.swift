import SwiftUI
import AuthenticationServices

// MARK: - Login View
struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AuthViewModel()
    @State private var email = ""
    @FocusState private var isEmailFocused: Bool
    @State private var isLogoAnimating = false
    @State private var showContent = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Animated Background gradient
                    AnimatedGradientBackground()

                    ScrollView {
                        VStack(spacing: 0) {
                            // Top section - Logo & Welcome
                            VStack(spacing: 16) {
                                Spacer()
                                    .frame(height: isEmailFocused ? geometry.size.height * 0.02 : geometry.size.height * 0.08)
                                    .animation(.spring(response: 0.4), value: isEmailFocused)
                                    .id("top-spacer") // ID for scroll target
                                
                                // Animated Logo - Pikachu! ⚡️
                                ZStack {
                                    // Electric sparkles around Pikachu
                                    if !isEmailFocused {
                                        ForEach(0..<4, id: \.self) { index in
                                            Text("⚡️")
                                                .font(.system(size: 25))
                                                .offset(
                                                    x: cos(Double(index) * .pi / 2 + (isLogoAnimating ? .pi / 4 : 0)) * 70,
                                                    y: sin(Double(index) * .pi / 2 + (isLogoAnimating ? .pi / 4 : 0)) * 70
                                                )
                                                .opacity(showContent ? (isLogoAnimating ? 1.0 : 0.4) : 0)
                                                .scaleEffect(isLogoAnimating ? 1.3 : 0.7)
                                        }
                                    }
                                    
                                    // Real Pikachu image
                                    PikachuImageView(size: isEmailFocused ? 80 : 110)
                                        .scaleEffect(showContent ? 1.0 : 0.3)
                                        .opacity(showContent ? 1.0 : 0)
                                }
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isEmailFocused)

                                VStack(spacing: 6) {
                                    HStack(spacing: 4) {
                                        Text("MelChat")
                                            .font(.system(size: isEmailFocused ? 24 : 32, weight: .bold, design: .rounded))
                                        
                                        if !isEmailFocused {
                                            Text("⚡️")
                                                .font(.system(size: isEmailFocused ? 20 : 28))
                                        }
                                    }
                                    .offset(y: showContent ? 0 : 15)
                                    .opacity(showContent ? 1.0 : 0)
                                    .animation(.spring(response: 0.4), value: isEmailFocused)

                                    if !isEmailFocused {
                                        Text("Gotta Chat 'Em All!")
                                            .font(.subheadline)
                                            .foregroundStyle(
                                                LinearGradient(
                                                    colors: [.yellow, .orange],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .offset(y: showContent ? 0 : 15)
                                            .opacity(showContent ? 1.0 : 0)
                                            .transition(.opacity.combined(with: .scale))
                                    }
                                }
                                
                                // Feature pills - Pokémon themed! 🎮
                                if !isEmailFocused {
                                    HStack(spacing: 8) {
                                        PokemonFeaturePill(emoji: "⚡️", text: "Fast", color: .yellow)
                                        PokemonFeaturePill(emoji: "🔒", text: "Secure", color: .orange)
                                        PokemonFeaturePill(emoji: "🎯", text: "E2E", color: .red)
                                    }
                                    .opacity(showContent ? 1.0 : 0)
                                    .offset(y: showContent ? 0 : 15)
                                    .transition(.opacity.combined(with: .scale))
                                }
                                
                                // Welcome character - hide on keyboard
                                if !isEmailFocused {
                                    WelcomeCharacter()
                                        .scaleEffect(0.6)
                                        .opacity(showContent ? 1.0 : 0)
                                        .frame(height: 70)
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
                            
                            Spacer()
                                .frame(minHeight: geometry.size.height * 0.03, maxHeight: geometry.size.height * 0.06)

                            // Middle section - Form
                            VStack(spacing: 14) {
                                // Sign in with Apple
                                SignInWithAppleButton(
                                    onRequest: { request in
                                        request.requestedScopes = [.email, .fullName]
                                    },
                                    onCompletion: { result in
                                        switch result {
                                        case .success:
                                            // TODO: Handle Apple Sign In
                                            print("Apple Sign In Success")
                                        case .failure(let error):
                                            print("Apple Sign In Error: \(error)")
                                        }
                                    }
                                )
                                .signInWithAppleButtonStyle(.black)
                                .frame(height: 50)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
                                .offset(y: showContent ? 0 : 15)
                                .opacity(showContent ? 1.0 : 0)
                                
                                // Divider
                                HStack(spacing: 12) {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                    
                                    Text("or")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 4)
                                .opacity(showContent ? 1.0 : 0)
                                
                                // Email Input - compact
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("EMAIL ADDRESS")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .tracking(0.8)
                                        .padding(.leading, 2)

                                    HStack(spacing: 10) {
                                        Image(systemName: "envelope.fill")
                                            .font(.callout)
                                            .foregroundStyle(isEmailFocused ? .orange : .secondary)
                                            .frame(width: 18)
                                            .animation(.spring(response: 0.3), value: isEmailFocused)
                                        
                                        TextField("your@email.com", text: $email)
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
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.tertiarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(
                                                isEmailFocused ?
                                                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing) :
                                                    LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                                                lineWidth: isEmailFocused ? 2 : 1
                                            )
                                            .animation(.spring(response: 0.3), value: isEmailFocused)
                                    )
                                    .shadow(color: isEmailFocused ? .blue.opacity(0.15) : .black.opacity(0.04), radius: isEmailFocused ? 10 : 5, y: 2)
                                    .scaleEffect(isEmailFocused ? 1.01 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEmailFocused)
                                }
                                .offset(y: showContent ? 0 : 15)
                                .opacity(showContent ? 1.0 : 0)

                                // Continue Button - compact
                                ContinueButton(
                                    isEmpty: email.isEmpty,
                                    isLoading: viewModel.isLoading,
                                    action: {
                                        isEmailFocused = false
                                        HapticManager.shared.medium()
                                        Task { await viewModel.sendCode(email: email) }
                                    }
                                )
                                .frame(height: 48)
                                .offset(y: showContent ? 0 : 15)
                                .opacity(showContent ? 1.0 : 0)

                                if let error = viewModel.error {
                                    AuthErrorBanner(message: error)
                                        .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 28)

                            Spacer()
                                .frame(minHeight: geometry.size.height * 0.02, maxHeight: geometry.size.height * 0.04)
                            
                            // Bottom section - Footer
                            VStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                    Text("End-to-end encrypted")
                                        .font(.caption.weight(.medium))
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.slash.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text("Your privacy is our priority")
                                        .font(.caption.weight(.medium))
                                }
                            }
                            .foregroundStyle(.secondary)
                            .opacity(showContent ? 1.0 : 0)
                            
                            Spacer()
                                .frame(height: geometry.size.height * 0.03)
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationDestination(isPresented: $viewModel.showVerification) {
                VerificationView(email: email, viewModel: viewModel)
            }
            .onAppear {
                viewModel.appState = appState
                
                // Staggered animations
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showContent = true
                }
                isLogoAnimating = true
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
    @State private var shakeCode = 0
    @State private var showContent = false
    @Namespace private var animation

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AnimatedGradientBackground()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: isCodeFocused || isUsernameFocused ? 
                                   geometry.size.height * 0.05 : 
                                   geometry.size.height * 0.08)
                            .animation(.spring(response: 0.4), value: isCodeFocused)
                            .animation(.spring(response: 0.4), value: isUsernameFocused)

                        // Animated Icon
                        if !isCodeFocused && !isUsernameFocused {
                            ZStack {
                                // Pulsing background
                                Circle()
                                    .fill((showUsernameInput ? Color.green : Color.orange).opacity(0.2))
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(showContent ? 1.1 : 0.9)
                                    .opacity(showContent ? 0.5 : 0)
                                    .animation(
                                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                        value: showContent
                                    )
                                
                                Circle()
                                    .fill(
                                        showUsernameInput ?
                                            LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                            LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 90, height: 90)
                                    .shadow(color: (showUsernameInput ? Color.green : Color.orange).opacity(0.3), radius: 20, y: 10)
                                    .scaleEffect(showContent ? 1.0 : 0.5)

                                Image(systemName: showUsernameInput ? "person.badge.key.fill" : "envelope.badge.shield.half.filled")
                                    .font(.system(size: 45))
                                    .foregroundStyle(.white)
                                    .rotationEffect(.degrees(showContent ? 0 : 180))
                                    .scaleEffect(showContent ? 1.0 : 0.5)
                            }
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showUsernameInput)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)
                            .transition(.scale.combined(with: .opacity))
                        }

                    // Title with transition
                    VStack(spacing: 12) {
                        Text(showUsernameInput ? "Choose Username" : "Check Your Email")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .id(showUsernameInput ? "username" : "email")
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                        Text(showUsernameInput ? "Pick a unique username" : "Code sent to \(email)")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .id(showUsernameInput ? "username-sub" : "email-sub")
                            .transition(.opacity)
                    }
                    .opacity(showContent ? 1.0 : 0)

                    Spacer().frame(height: 32)

                    if !showUsernameInput {
                        // Code Input with shake animation
                        VStack(spacing: 24) {
                            VStack(spacing: 12) {
                                Text("VERIFICATION CODE")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .tracking(1)

                                TextField("000000", text: $code)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .tracking(8)
                                    .focused($isCodeFocused)
                                    .onChange(of: code) { _, newValue in
                                        // Limit to 6 digits
                                        if newValue.count > 6 {
                                            code = String(newValue.prefix(6))
                                        }
                                        
                                        // Auto-submit when 6 digits entered
                                        if newValue.count == 6 {
                                            isCodeFocused = false
                                            HapticManager.shared.success()
                                            
                                            // ⭐️ Try to verify without username first
                                            Task {
                                                let success = await viewModel.tryVerifyWithCode(email: email, code: code)
                                                
                                                // If not successful (new user), show username input
                                                if !success && viewModel.needsUsername {
                                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                        showUsernameInput = true
                                                    }
                                                }
                                                // If successful, user is already logged in!
                                            }
                                        }
                                    }
                                    .padding(.vertical, 24)
                                    .frame(maxWidth: 280)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.tertiarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(
                                                isCodeFocused ?
                                                    LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing) :
                                                    LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                                                lineWidth: isCodeFocused ? 2 : 1
                                            )
                                            .animation(.spring(response: 0.3), value: isCodeFocused)
                                    )
                                    .shadow(color: isCodeFocused ? .blue.opacity(0.2) : .black.opacity(0.05), radius: isCodeFocused ? 15 : 8, y: 8)
                                    .scaleEffect(isCodeFocused ? 1.02 : 1.0)
                                    .shake(times: shakeCode)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCodeFocused)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))

                            Button {
                                HapticManager.shared.light()
                                Task { await viewModel.sendCode(email: email) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Resend Code")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.orange.opacity(0.1))
                                )
                            }
                            .disabled(viewModel.isLoading)
                            .opacity(viewModel.isLoading ? 0.5 : 1.0)
                            .transition(.opacity)
                        }
                        .opacity(showContent ? 1.0 : 0)
                    } else {
                        // Username Input with focus animation
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
                                        .foregroundStyle(isUsernameFocused ? .green : .secondary)
                                        .frame(width: 24)
                                        .animation(.spring(response: 0.3), value: isUsernameFocused)
                                    
                                    TextField("username", text: $username)
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
                                        .fill(Color(.tertiarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            isUsernameFocused ?
                                                LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing) :
                                                LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                                            lineWidth: isUsernameFocused ? 2 : 1
                                        )
                                        .animation(.spring(response: 0.3), value: isUsernameFocused)
                                )
                                .shadow(color: isUsernameFocused ? .green.opacity(0.2) : .black.opacity(0.05), radius: isUsernameFocused ? 15 : 8, y: 4)
                                .scaleEffect(isUsernameFocused ? 1.02 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isUsernameFocused)
                            }
                            .frame(maxWidth: 320)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))

                            CompleteSetupButton(
                                isEmpty: username.isEmpty,
                                isLoading: viewModel.isLoading,
                                action: {
                                    isUsernameFocused = false
                                    HapticManager.shared.medium()
                                    Task {
                                        await viewModel.verify(
                                            email: email,
                                            code: code,
                                            username: username.isEmpty ? nil : username
                                        )
                                    }
                                }
                            )
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                        }
                    }

                    if let error = viewModel.error {
                        AuthErrorBanner(message: error)
                            .padding(.horizontal, 24)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .onAppear {
                                HapticManager.shared.error()
                            }
                    }

                        Spacer()
                            .frame(height: isCodeFocused || isUsernameFocused ? 
                                   geometry.size.height * 0.02 : 
                                   geometry.size.height * 0.05)
                            .animation(.spring(response: 0.4), value: isCodeFocused)
                            .animation(.spring(response: 0.4), value: isUsernameFocused)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showUsernameInput)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    showContent = true
                }
                
                // Auto-focus code input
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isCodeFocused = true
                }
            }
            .navigationTitle("Verification")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Helper Views

// Animated Gradient Background - Pokémon themed! ⚡️
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.yellow.opacity(animateGradient ? 0.12 : 0.05),
                Color.orange.opacity(animateGradient ? 0.08 : 0.03),
                Color.red.opacity(animateGradient ? 0.05 : 0.02)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Pokémon Feature Pill
struct PokemonFeaturePill: View {
    let emoji: String
    let text: String
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 16))
                .scaleEffect(isAnimating ? 1.2 : 1.0)
            
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: color.opacity(0.4), radius: 6, y: 3)
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...0.5))
            ) {
                isAnimating = true
            }
        }
    }
}

// Error Banner with animation
struct AuthErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
            Text(message)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.red)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ContinueButton: View {
    let isEmpty: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                    Text("Sending...")
                } else {
                    Text("Continue")
                    Text("⚡️")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isEmpty || isLoading {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: isEmpty ? .clear : .orange.opacity(0.4), radius: 12, y: 6)
            .scaleEffect(isEmpty || isLoading ? 1.0 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEmpty)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
        }
        .disabled(isEmpty || isLoading)
        .buttonStyle(BounceButtonStyle())
    }
}

struct CompleteSetupButton: View {
    let isEmpty: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                    Text("Verifying...")
                } else {
                    Text("Complete Setup")
                    Image(systemName: "checkmark")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isEmpty || isLoading {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.3))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
            }
            .foregroundStyle(.white)
            .shadow(color: isEmpty ? .clear : .green.opacity(0.3), radius: 12, y: 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEmpty)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLoading)
        }
        .disabled(isEmpty || isLoading)
        .buttonStyle(BounceButtonStyle())
    }
}

// Bounce Button Style for better interaction
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
