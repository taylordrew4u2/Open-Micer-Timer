//
//  ContentView.swift
//  Open Micer Timer
//
//  Created by Taylor Drew on 12/4/25.
//

import AVFoundation
import MediaPlayer
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @AppStorage("hasSeenTimerTutorial") private var hasSeenTimerTutorial = false
    @AppStorage("timerLengthSeconds") private var timerLengthSeconds = 5 * 60
    @AppStorage("finalMinuteModeEnabled") private var finalMinuteModeEnabled = true
    @AppStorage("showStageRemoteHint") private var showStageRemoteHint = true

    @State private var remainingSeconds = 5 * 60
    @State private var isRunning = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @State private var timerTask: Task<Void, Never>?
    @State private var remoteController = RemoteClickController()

    private var progress: Double {
        guard timerLengthSeconds > 0 else { return 0 }
        return Double(remainingSeconds) / Double(timerLengthSeconds)
    }

    private var isFinalMinute: Bool {
        finalMinuteModeEnabled && remainingSeconds > 0 && remainingSeconds <= 60
    }

    private var displayedTime: String {
        if isFinalMinute && remainingSeconds < 60 {
            return "\(remainingSeconds)"
        }

        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            NavigationStack {
                ZStack {
                    stageBackground

                    if isFinalMinute {
                        finalMinuteBackground
                    }

                    if isLandscape {
                        landscapeLayout(in: geometry.size)
                    } else {
                        portraitLayout(in: geometry.size)
                    }
                }
                .navigationTitle("Open Micer Timer")
                .timerNavigationStyle()
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            showTutorial = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .accessibilityLabel("Show tutorial")
                        .tint(.white)

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                        }
                        .accessibilityLabel("Open settings")
                        .tint(.white)
                    }
                }
                .onAppear {
                    syncRemainingTimeIfNeeded()
                    remoteController.startReceivingClicks { toggleTimer() }
                    if !hasSeenTimerTutorial {
                        showTutorial = true
                        hasSeenTimerTutorial = true
                    }
                }
                .onDisappear {
                    timerTask?.cancel()
                    remoteController.stopReceivingClicks()
                }
                .onChange(of: timerLengthSeconds) { _, _ in
                    syncRemainingTimeIfNeeded()
                }
                .sheet(isPresented: $showTutorial) {
                    TutorialView()
                }
                .sheet(isPresented: $showSettings) {
                    TimerSettingsView(
                        timerLengthSeconds: $timerLengthSeconds,
                        finalMinuteModeEnabled: $finalMinuteModeEnabled,
                        showStageRemoteHint: $showStageRemoteHint,
                        isTimerRunning: isRunning,
                        resetTimer: resetTimer,
                        showTutorial: { showTutorial = true }
                    )
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .hardwareClickHandler { toggleTimer() }
    }

    private var stageBackground: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.05, green: 0.06, blue: 0.07)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var finalMinuteBackground: some View {
        ZStack {
            Color(red: 1, green: 0.84, blue: 0.04)

            AngularGradient(
                colors: [.red, .yellow, .orange, .red, .black, .red],
                center: .center
            )
            .opacity(0.72)
            .scaleEffect(1.8)

            VStack(spacing: 0) {
                ForEach(0..<14, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? .black.opacity(0.22) : .clear)
                        .frame(height: 18)
                    Spacer(minLength: 10)
                }
            }
            .rotationEffect(.degrees(-12))
            .scaleEffect(1.3)
        }
        .ignoresSafeArea()
    }

    private func portraitLayout(in size: CGSize) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            timerDisplay(fontSize: displayFontSize(for: size, isLandscape: false))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            stageControls
                .padding(.horizontal, 18)
                .padding(.bottom, showStageRemoteHint ? 0 : 18)

            if showStageRemoteHint {
                remoteStatus
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
        }
    }

    private func landscapeLayout(in size: CGSize) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                timerDisplay(fontSize: displayFontSize(for: size, isLandscape: true))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                ProgressView(value: progress)
                    .tint(timerColor)
                    .scaleEffect(x: 1, y: 4, anchor: .center)
                    .accessibilityLabel("Timer progress")
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 14) {
                stageControls

                if showStageRemoteHint {
                    remoteStatus
                }
            }
            .frame(width: min(350, max(280, size.width * 0.28)))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func timerDisplay(fontSize: CGFloat) -> some View {
        VStack(spacing: isFinalMinute ? 10 : 8) {
            Text(displayedTime)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.32)
                .contentTransition(.numericText())
                .shadow(color: isFinalMinute ? .black : timerTextColor.opacity(0.35), radius: isFinalMinute ? 0 : 12, x: isFinalMinute ? 7 : 0, y: isFinalMinute ? 7 : 0)
                .shadow(color: isFinalMinute ? .white : .clear, radius: isFinalMinute ? 0 : 0, x: isFinalMinute ? -4 : 0, y: isFinalMinute ? -4 : 0)
                .accessibilityLabel("Timer showing \(displayedTime)")

            Text(statusText)
                .font(.system(size: isFinalMinute ? 42 : 28, weight: .black, design: .rounded))
                .foregroundStyle(statusTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, isFinalMinute ? 8 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timer, \(displayedTime), \(statusText)")
    }

    private var stageControls: some View {
        HStack(spacing: 12) {
            Button(action: toggleTimer) {
                Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])
            .keyboardShortcut(.return, modifiers: [])

            Button(action: resetTimer) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .disabled(isRunning && remainingSeconds > 0)

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open timer settings")
        }
        .font(.headline)
        .padding(12)
        .background(.white.opacity(isFinalMinute ? 0.96 : 0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private var remoteStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bluetooth headphones ready", systemImage: "headphones")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Press play/pause once to start and again to stop. The timer must stay open and visible for stage use.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        if remainingSeconds == 0 { return "TIME" }
        if isFinalMinute { return "FINAL MINUTE" }
        return isRunning ? "RUNNING" : "READY"
    }

    private var timerColor: Color {
        if remainingSeconds == 0 { return .red }
        if isFinalMinute { return .red }
        return isRunning ? .green : .yellow
    }

    private var timerTextColor: Color {
        if remainingSeconds == 0 { return .red }
        if isFinalMinute { return .yellow }
        return .white
    }

    private var statusTextColor: Color {
        isFinalMinute ? .black : .white.opacity(0.85)
    }

    private func displayFontSize(for size: CGSize, isLandscape: Bool) -> CGFloat {
        if isFinalMinute {
            return isLandscape ? min(size.width * 0.34, size.height * 0.82) : min(size.width * 0.58, size.height * 0.42)
        }

        if isLandscape {
            return min(size.width * 0.2, size.height * 0.56)
        }

        return min(size.width * 0.31, size.height * 0.24)
    }

    private func syncRemainingTimeIfNeeded() {
        if !isRunning {
            timerLengthSeconds = min(max(timerLengthSeconds, 60), 7200)
            remainingSeconds = timerLengthSeconds
        }
    }

    private func toggleTimer() {
        isRunning ? stopTimer() : startTimer()
    }

    private func startTimer() {
        if remainingSeconds == 0 {
            remainingSeconds = timerLengthSeconds
        }

        isRunning = true
        remoteController.updatePlaybackState(isRunning: true)
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    remainingSeconds = max(remainingSeconds - 1, 0)
                    if remainingSeconds == 0 {
                        stopTimer()
                    }
                }
            }
        }
    }

    private func stopTimer() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
        remoteController.updatePlaybackState(isRunning: false)
    }

    private func resetTimer() {
        stopTimer()
        remainingSeconds = timerLengthSeconds
    }
}

private struct TimerSettingsView: View {
    @Binding var timerLengthSeconds: Int
    @Binding var finalMinuteModeEnabled: Bool
    @Binding var showStageRemoteHint: Bool

    let isTimerRunning: Bool
    let resetTimer: () -> Void
    let showTutorial: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var minuteValue: Binding<Int> {
        Binding {
            timerLengthSeconds / 60
        } set: { newValue in
            updateTimerLength(minutes: newValue, seconds: timerLengthSeconds % 60)
        }
    }

    private var secondValue: Binding<Int> {
        Binding {
            timerLengthSeconds % 60
        } set: { newValue in
            updateTimerLength(minutes: timerLengthSeconds / 60, seconds: newValue)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Timer") {
                    Stepper(value: minuteValue, in: 1...120, step: 1) {
                        settingRow(title: "Minutes", value: "\(timerLengthSeconds / 60)")
                    }
                    .disabled(isTimerRunning)

                    Stepper(value: secondValue, in: 0...59, step: 5) {
                        settingRow(title: "Seconds", value: String(format: "%02d", timerLengthSeconds % 60))
                    }
                    .disabled(isTimerRunning)

                    Button {
                        resetTimer()
                    } label: {
                        Label("Reset to Selected Time", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(isTimerRunning)
                }

                Section("Stage Display") {
                    Toggle(isOn: $finalMinuteModeEnabled) {
                        Label("Comic Final-Minute Mode", systemImage: "exclamationmark.bubble.fill")
                    }

                    Toggle(isOn: $showStageRemoteHint) {
                        Label("Show Bluetooth Help on Timer", systemImage: "headphones")
                    }
                }

                Section("Bluetooth Headphones") {
                    Label("Pair headphones in the iOS Settings app.", systemImage: "gear")
                    Label("Use the play/pause button to start or stop the timer.", systemImage: "playpause.fill")
                    Label("Keep this app open so the performer can see the countdown.", systemImage: "eye")
                }

                Section {
                    Button {
                        dismiss()
                        showTutorial()
                    } label: {
                        Label("Open Full Tutorial", systemImage: "questionmark.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func updateTimerLength(minutes: Int, seconds: Int) {
        let clampedMinutes = min(max(minutes, 1), 120)
        let clampedSeconds = min(max(seconds, 0), 59)
        timerLengthSeconds = min(max((clampedMinutes * 60) + clampedSeconds, 60), 7200)
    }
}

private struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Bluetooth headphones") {
                    Label("Open the iOS Settings app and pair the headphones first.", systemImage: "gear")
                    Label("Open this timer and leave the timer screen visible.", systemImage: "iphone")
                    Label("Press the headphone play/pause button once to start, then press it again to stop.", systemImage: "playpause.fill")
                }

                Section("Timer settings") {
                    Label("Tap the gear button to edit minutes and seconds.", systemImage: "gearshape.fill")
                    Label("Turn Comic Final-Minute Mode on for a huge, bright final countdown.", systemImage: "exclamationmark.bubble.fill")
                    Label("Turn Bluetooth help on or off on the stage screen.", systemImage: "headphones")
                }

                Section("Other Bluetooth remotes") {
                    Label("Bluetooth media remotes use the same play/pause control.", systemImage: "dot.radiowaves.left.and.right")
                    Label("Presentation clickers can use Space, Return, arrow keys, Page Up, or Page Down.", systemImage: "keyboard")
                    Label("If the button controls another audio app, close that app and reopen this timer.", systemImage: "speaker.wave.2")
                }

                Section("Stage visibility") {
                    Text("The timer uses oversized high-contrast digits and adapts to iPhone and iPad in portrait or landscape. During the final minute, 1:00 appears first, then the remaining seconds become giant single numbers: 59, 58, 57, and so on.")
                }

                Section("Selfie stick note") {
                    Text("Selfie sticks do not all send the same signal. Models that send media or keyboard commands should work. Models that only trigger the system camera shutter or volume button are blocked by iOS for normal apps.")
                }
            }
            .navigationTitle("How to Use")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

@MainActor
@Observable
private final class RemoteClickController {
    private var clickHandler: (() -> Void)?

    func startReceivingClicks(_ handler: @escaping () -> Void) {
        clickHandler = handler
        configureAudioSession()
        configureRemoteCommands()
        updatePlaybackState(isRunning: false)
    }

    func stopReceivingClicks() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
#if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
#endif
        clickHandler = nil
    }

    func updatePlaybackState(isRunning: Bool) {
        MPNowPlayingInfoCenter.default().playbackState = isRunning ? .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Open Micer Timer",
            MPMediaItemPropertyArtist: isRunning ? "Countdown running" : "Countdown ready",
            MPNowPlayingInfoPropertyPlaybackRate: isRunning ? 1.0 : 0.0
        ]
    }

    private func configureAudioSession() {
#if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Remote click audio session setup failed: \(error.localizedDescription)")
        }
#endif
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.clickHandler?() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.clickHandler?() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.clickHandler?() }
            return .success
        }
    }
}

private extension View {
    func timerNavigationStyle() -> some View {
#if os(iOS)
        navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
#else
        self
#endif
    }

    func hardwareClickHandler(_ action: @escaping () -> Void) -> some View {
#if os(iOS)
        background(HardwareClickReader(action: action).frame(width: 0, height: 0))
#else
        self
#endif
    }
}

#if os(iOS)
private struct HardwareClickReader: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> HardwareClickViewController {
        let viewController = HardwareClickViewController()
        viewController.action = action
        return viewController
    }

    func updateUIViewController(_ viewController: HardwareClickViewController, context: Context) {
        viewController.action = action
        DispatchQueue.main.async {
            viewController.becomeFirstResponder()
        }
    }
}

private final class HardwareClickViewController: UIViewController {
    var action: (() -> Void)?

    override var canBecomeFirstResponder: Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handledPress = presses.contains { press in
            guard let key = press.key else { return false }
            switch key.keyCode {
            case .keyboardSpacebar,
                 .keyboardReturnOrEnter,
                 .keyboardRightArrow,
                 .keyboardLeftArrow,
                 .keyboardUpArrow,
                 .keyboardDownArrow,
                 .keyboardPageUp,
                 .keyboardPageDown:
                return true
            default:
                return false
            }
        }

        if handledPress {
            action?()
        } else {
            super.pressesEnded(presses, with: event)
        }
    }
}
#endif

#Preview {
    ContentView()
}
