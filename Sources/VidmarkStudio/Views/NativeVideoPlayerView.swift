import AVKit
import SwiftUI

struct NativeVideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    var fullScreenTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFrameSteppingButtons = true
        view.showsFullScreenToggleButton = true
        view.allowsPictureInPicturePlayback = true
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }

        if fullScreenTrigger != context.coordinator.lastFullScreenTrigger {
            context.coordinator.lastFullScreenTrigger = fullScreenTrigger
            guard fullScreenTrigger > 0, let screen = nsView.window?.screen else { return }
            context.coordinator.showFullScreenPlayer(player: player, on: screen)
        }
    }

    @MainActor
    final class Coordinator {
        var lastFullScreenTrigger = 0
        private var fullScreenController: FullScreenPlayerController?

        func showFullScreenPlayer(player: AVPlayer, on screen: NSScreen) {
            fullScreenController?.close()
            let controller = FullScreenPlayerController(player: player, screen: screen) { [weak self] in
                self?.fullScreenController = nil
            }
            fullScreenController = controller
            controller.show()
        }
    }
}

@MainActor
private final class FullScreenPlayerController: NSObject, NSWindowDelegate {
    private let player: AVPlayer
    private let onClose: () -> Void
    private var window: EscapeClosingWindow?
    private var playerView: AVPlayerView?

    init(player: AVPlayer, screen: NSScreen, onClose: @escaping () -> Void) {
        self.player = player
        self.onClose = onClose
        super.init()

        let window = EscapeClosingWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.backgroundColor = .black
        window.level = .mainMenu
        window.collectionBehavior = [.fullScreenPrimary, .canJoinAllSpaces]
        window.delegate = self
        window.onEscape = { [weak self] in
            self?.close()
        }

        let container = FullScreenPlayerContainerView(player: player) { [weak self] in
            self?.close()
        }
        container.frame = screen.frame
        container.autoresizingMask = [.width, .height]
        window.contentView = container

        self.window = window
        self.playerView = container.playerView
    }

    func show() {
        guard let window else { return }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        playerView?.player = nil
        playerView = nil
        window = nil
        onClose()
    }
}

@MainActor
private final class EscapeClosingWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

@MainActor
private final class FullScreenPlayerContainerView: NSView {
    let playerView = AVPlayerView()
    private let closeButton = NSButton()
    private let onClose: () -> Void

    init(player: AVPlayer, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        playerView.player = player
        playerView.controlsStyle = .floating
        playerView.videoGravity = .resizeAspect
        playerView.showsFrameSteppingButtons = true
        playerView.showsFullScreenToggleButton = false
        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)

        closeButton.title = "Exit Full Screen (Esc)"
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.target = self
        closeButton.action = #selector(closeFullScreen)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func closeFullScreen() {
        onClose()
    }
}
