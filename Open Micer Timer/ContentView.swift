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
    @State private var activeSheet: ActiveSheet?
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
            let layout = StageLayout(size: geometry.size)

            ZStack {
                stageBackground

                if isFinalMinute {
                    finalMinuteBackground
                }

                VStack(spacing: layout.verticalSpacing) {
                    headerStrip(isCompact: layout.isCompact)
                        .padding(.horizontal, layout.outerPadding)
                        .padding(.top, layout.topPadding)

                    timerDisplay(fontSize: timerFontSize(for: layout))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, layout.timerHorizontalPadding)
                        .layoutPriority(2)

                    ProgressView(value: progress)
                        .tint(progressColor)
                        .scaleEffect(x: 1, y: layout.progressHeightMultiplier, anchor: .center)
                        .padding(.horizontal, layout.outerPadding)
                        .accessibilityLabel("Timer progress")

                    bottomPanel(layout: layout)
                        .padding(.horizontal, layout.outerPadding)
                        .padding(.bottom, layout.bottomPadding)
                }
                .frame(maxWidth: layout.contentMaxWidth, maxHeight: .infinity)
            }
            .onAppear {
                syncRemainingTimeIfNeeded()
                remoteController.startReceivingClicks { toggleTimer() }
                if !hasSeenTimerTutorial {
                    activeSheet = .tutorial
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
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .tutorial:
                    TutorialView()
                case .settings:
                    TimerSettingsView(
                        timerLengthSeconds: $timerLengthSeconds,
                        finalMinuteModeEnabled: $finalMinuteModeEnabled,
                        showStageRemoteHint: $showStageRemoteHint,
                        isTimerRunning: isRunning,
                        resetTimer: resetTimer,
                        showTutorial: showTutorialFromSettings
                    )
                    .settingsSheetStyle()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .macWindowSizing()
        .hardwareClickHandler { toggleTimer() }
    }

    private var stageBackground: some View {
        Color.black
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, Color(red: 0.09, green: 0.11, blue: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxHeight: 420)
            }
            .ignoresSafeArea()
    }

    private var finalMinuteBackground: some View {
        Color(red: 1, green: 0.74, blue: 0.16)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
    }

    private func headerStrip(isCompact: Bool) -> some View {
        HStack(spacing: 10) {
            Image("TimerLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            Label(statusText, systemImage: statusIcon)
                .font(.system(size: isCompact ? 15 : 18, weight: .black, design: .rounded))
                .foregroundStyle(statusBadgeForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, isCompact ? 12 : 16)
                .padding(.vertical, isCompact ? 8 : 10)
                .background(statusBadgeBackground, in: Capsule())
                .accessibilityLabel(statusText)

            Spacer(minLength: 8)

            if !isCompact {
                Text("Bluetooth: play/pause toggles timer")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            stageIconButton(systemImage: "questionmark.circle", accessibilityLabel: "Show tutorial") {
                activeSheet = .tutorial
            }

            stageIconButton(systemImage: "gearshape.fill", accessibilityLabel: "Open settings") {
                activeSheet = .settings
            }
        }
    }

    private func stageIconButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func timerDisplay(fontSize: CGFloat) -> some View {
        VStack(spacing: isFinalMinute ? 6 : 8) {
            Text(displayedTime)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.28)
                .contentTransition(.numericText())
                .shadow(color: timerShadowColor, radius: isFinalMinute ? 0 : 12, x: 0, y: isFinalMinute ? 0 : 4)

            if !isFinalMinute {
                Text(isRunning ? "RUNNING" : remainingSeconds == 0 ? "TIME" : "READY")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timer, \(displayedTime), \(statusText)")
    }

    private func bottomPanel(layout: StageLayout) -> some View {
        Group {
            if layout.useWideControls {
                HStack(spacing: layout.controlSpacing) {
                    stageControls(layout: layout)
                        .frame(maxWidth: 520)

                    if showStageRemoteHint {
                        remoteHint(compact: false)
                            .frame(maxWidth: 420)
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: layout.controlSpacing) {
                    stageControls(layout: layout)

                    if showStageRemoteHint && !layout.isVeryShort {
                        remoteHint(compact: layout.isCompact)
                    }
                }
            }
        }
    }

    private func stageControls(layout: StageLayout) -> some View {
        HStack(spacing: 10) {
            Button(action: toggleTimer) {
                Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity, minHeight: layout.controlHeight)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isRunning ? .red : Color(red: 1, green: 0.74, blue: 0.16))
            .keyboardShortcut(.space, modifiers: [])
            .keyboardShortcut(.return, modifiers: [])

            Button(action: resetTimer) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: layout.iconButtonSize, height: layout.controlHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isRunning && remainingSeconds > 0)
            .accessibilityLabel("Reset timer")

            Button {
                activeSheet = .settings
            } label: {
                Image(systemName: "gearshape.fill")
                    .frame(width: layout.iconButtonSize, height: layout.controlHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Open timer settings")
        }
        .font(.headline.weight(.bold))
        .padding(layout.controlPadding)
        .background(.white.opacity(isFinalMinute ? 0.94 : 0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func remoteHint(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "headphones")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("Bluetooth headphones")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(compact ? "Play/pause starts or stops." : "Press play/pause once to start and again to stop. Keep this screen visible for the performer.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 12 : 14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusText: String {
        if remainingSeconds == 0 { return "TIME" }
        if isFinalMinute { return remainingSeconds == 60 ? "ONE MINUTE" : "FINAL COUNTDOWN" }
        return isRunning ? "RUNNING" : "READY"
    }

    private var statusIcon: String {
        if remainingSeconds == 0 { return "flag.checkered" }
        if isFinalMinute { return "exclamationmark.triangle.fill" }
        return isRunning ? "timer" : "play.circle.fill"
    }

    private var progressColor: Color {
        if remainingSeconds == 0 { return .red }
        if isFinalMinute { return .black }
        return isRunning ? Color(red: 1, green: 0.74, blue: 0.16) : .white.opacity(0.7)
    }

    private var timerTextColor: Color {
        if remainingSeconds == 0 { return .red }
        if isFinalMinute { return .black }
        return .white
    }

    private var timerShadowColor: Color {
        if isFinalMinute { return .clear }
        return timerTextColor.opacity(0.24)
    }

    private var statusBadgeForeground: Color {
        isFinalMinute ? .white : .white
    }

    private var statusBadgeBackground: Color {
        if remainingSeconds == 0 { return .red }
        if isFinalMinute { return .black.opacity(0.82) }
        return isRunning ? Color(red: 1, green: 0.74, blue: 0.16).opacity(0.24) : .white.opacity(0.12)
    }

    private func timerFontSize(for layout: StageLayout) -> CGFloat {
        if isFinalMinute {
            return layout.isLandscape ? layout.size.height * 0.76 : layout.size.width * 0.64
        }

        if layout.isLandscape {
            return min(layout.size.width * 0.24, layout.size.height * 0.6)
        }

        return min(layout.size.width * 0.36, layout.size.height * 0.27)
    }

    private func syncRemainingTimeIfNeeded() {
        if !isRunning {
            timerLengthSeconds = min(max(timerLengthSeconds, 60), 7200)
            remainingSeconds = timerLengthSeconds
        }
    }

    private func showTutorialFromSettings() {
        activeSheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            activeSheet = .tutorial
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

private enum ActiveSheet: Identifiable {
    case settings
    case tutorial

    var id: Self { self }
}

private struct StageLayout {
    let size: CGSize

    var isLandscape: Bool {
        size.width > size.height
    }

    var isCompact: Bool {
        min(size.width, size.height) < 390
    }

    var isVeryShort: Bool {
        size.height < 420
    }

    var useWideControls: Bool {
#if os(macOS)
        isLandscape && size.width >= 900
#else
        isLandscape && size.width >= 760
#endif
    }

    var contentMaxWidth: CGFloat? {
#if os(macOS)
        min(max(size.width * 0.9, 520), 980)
#else
        nil
#endif
    }

    var outerPadding: CGFloat {
        min(max(size.width * 0.045, 16), 44)
    }

    var topPadding: CGFloat {
        isCompact ? 8 : 14
    }

    var bottomPadding: CGFloat {
        isCompact ? 14 : 22
    }

    var timerHorizontalPadding: CGFloat {
        isLandscape ? outerPadding : max(10, outerPadding * 0.55)
    }

    var verticalSpacing: CGFloat {
        isCompact ? 10 : 18
    }

    var controlSpacing: CGFloat {
        isCompact ? 10 : 14
    }

    var controlHeight: CGFloat {
        isCompact ? 48 : 56
    }

    var iconButtonSize: CGFloat {
        isCompact ? 48 : 56
    }

    var controlPadding: CGFloat {
        isCompact ? 8 : 12
    }

    var progressHeightMultiplier: CGFloat {
        isCompact ? 3 : 4
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
                Section("Start Fast") {
                    Label("Tap Start on the main screen to begin immediately.", systemImage: "play.fill")
                    Label("Tap the gear button when you need to change the time.", systemImage: "gearshape.fill")
                    Label("Tap Reset to return to the selected time.", systemImage: "arrow.counterclockwise")
                }

                Section("Bluetooth Headphones") {
                    Label("Open the iOS Settings app and pair the headphones first.", systemImage: "gear")
                    Label("Open this timer and leave the timer screen visible.", systemImage: "iphone")
                    Label("Press the headphone play/pause button once to start, then press it again to stop.", systemImage: "playpause.fill")
                }

                Section("Stage Visibility") {
                    Text("The timer fills the available screen on iPhone and iPad in portrait or landscape. During the final minute, 1:00 appears first, then the remaining seconds become giant single numbers: 59, 58, 57, and so on.")
                }

                Section("Other Bluetooth Remotes") {
                    Label("Bluetooth media remotes use the same play/pause control.", systemImage: "dot.radiowaves.left.and.right")
                    Label("Presentation clickers can use Space, Return, arrow keys, Page Up, or Page Down.", systemImage: "keyboard")
                    Label("If the button controls another audio app, close that app and reopen this timer.", systemImage: "speaker.wave.2")
                }

                Section("Selfie Stick Note") {
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
    func settingsSheetStyle() -> some View {
#if os(iOS)
        presentationDetents([.medium, .large])
#else
        frame(minWidth: 440, minHeight: 420)
#endif
    }

    func macWindowSizing() -> some View {
#if os(macOS)
        frame(minWidth: 520, idealWidth: 760, minHeight: 460, idealHeight: 620)
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
