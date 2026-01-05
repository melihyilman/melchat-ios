import SwiftUI

// MARK: - Waveform View (Recording)

struct RecordingWaveformView: View {
    @Binding var isRecording: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 40)
    @State private var currentIndex = 0
    
    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<40, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3)
                    .frame(height: amplitudes[index] * 40)
                    .animation(.easeInOut(duration: 0.2), value: amplitudes[index])
            }
        }
        .frame(height: 50)
        .onAppear {
            if isRecording {
                startAnimating()
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startAnimating()
            }
        }
    }
    
    private func startAnimating() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard isRecording else {
                timer.invalidate()
                return
            }
            
            // Simulate audio amplitude (replace with real audio metering)
            let randomAmplitude = CGFloat.random(in: 0.2...1.0)
            amplitudes[currentIndex] = randomAmplitude
            currentIndex = (currentIndex + 1) % amplitudes.count
        }
    }
}

// MARK: - Waveform View (Playback)

struct PlaybackWaveformView: View {
    let duration: TimeInterval
    @Binding var progress: Double
    
    private let barCount = 40
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let height = waveformHeight(for: index)
                    let isPlayed = Double(index) / Double(barCount) < progress
                    
                    Capsule()
                        .fill(
                            isPlayed ?
                                LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top) :
                                LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .bottom, endPoint: .top)
                        )
                        .frame(width: 3, height: height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 40)
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        // Generate semi-random but consistent waveform
        let base = sin(Double(index) * 0.3) * 0.5 + 0.5
        let variation = sin(Double(index) * 1.5) * 0.3
        return CGFloat(base + variation) * 40
    }
}

// MARK: - Voice Message Recording View

struct VoiceRecordingView: View {
    @ObservedObject var recorder: VoiceRecorder
    @Binding var isPresented: Bool
    let onSend: (URL) -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    recorder.cancelRecording()
                    isPresented = false
                }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Recording card
                VStack(spacing: 20) {
                    // Title
                    HStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .opacity(recorder.isRecording ? 1 : 0)
                            .scaleEffect(scale)
                        
                        Text(recorder.isRecording ? "Recording..." : "Voice Message")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    // Waveform
                    RecordingWaveformView(isRecording: $recorder.isRecording)
                        .padding(.vertical)
                    
                    // Duration
                    Text(recorder.formattedDuration(recorder.recordingDuration))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    
                    // Actions
                    HStack(spacing: 32) {
                        // Cancel
                        Button {
                            recorder.cancelRecording()
                            isPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red.gradient)
                                .clipShape(Circle())
                                .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
                        }
                        
                        // Send
                        Button {
                            if let url = recorder.stopRecording() {
                                onSend(url)
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue.gradient)
                                .clipShape(Circle())
                                .shadow(color: .blue.opacity(0.4), radius: 10, y: 5)
                        }
                        .disabled(!recorder.isRecording || recorder.recordingDuration < 1)
                        .opacity(recorder.recordingDuration >= 1 ? 1 : 0.5)
                    }
                    .padding(.top)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                )
                .padding(.horizontal)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            Task {
                _ = await recorder.startRecording()
                
                // Pulse animation for recording dot
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.3
                }
            }
        }
    }
}

// MARK: - Voice Message Bubble

struct VoiceMessageBubble: View {
    let message: Message
    @StateObject private var recorder = VoiceRecorder()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromCurrentUser { Spacer(minLength: 60) }
            
            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Voice message content
                HStack(spacing: 12) {
                    // Play/Pause button
                    Button {
                        if recorder.isPlaying {
                            recorder.pausePlayback()
                        } else if let url = message.mediaURL {
                            recorder.playAudio(from: url)
                        }
                    } label: {
                        Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(message.isFromCurrentUser ? .white : .blue)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(message.isFromCurrentUser ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                            )
                    }
                    
                    // Waveform
                    PlaybackWaveformView(
                        duration: message.duration ?? 0,
                        progress: $recorder.playbackProgress
                    )
                    .frame(width: 150)
                    
                    // Duration
                    Text(recorder.formattedDuration(message.duration ?? 0))
                        .font(.caption)
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : .secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            message.isFromCurrentUser ?
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .shadow(
                    color: message.isFromCurrentUser ? Color.blue.opacity(0.2) : Color.black.opacity(0.05),
                    radius: 8,
                    y: 4
                )
                
                // Timestamp
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if message.isFromCurrentUser {
                        Image(systemName: "checkmark.checkmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            if !message.isFromCurrentUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}

// MARK: - Previews

#Preview("Recording View") {
    VoiceRecordingView(
        recorder: VoiceRecorder(),
        isPresented: .constant(true),
        onSend: { _ in }
    )
}

#Preview("Voice Message Bubble") {
    VoiceMessageBubble(
        message: Message(
            content: "[Voice Message]",
            senderId: UUID(),
            recipientId: UUID(),
            chatId: UUID(),
            contentType: .voiceMessage,
            status: .delivered,
            isFromCurrentUser: true
        )
    )
}
