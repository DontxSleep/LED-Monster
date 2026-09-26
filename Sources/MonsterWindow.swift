import SwiftUI
import AppKit

/// Transparent native window; SwiftUI clips the entire surface to the artwork's outline.
struct MonsterWindowStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowAnchor() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class WindowAnchor: NSView {
        private var configured = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !configured else { return }
            configured = true
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.contentAspectRatio = NSSize(width: 1, height: 1)
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(type)?.isHidden = true
            }
            let available = window.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
            let edge = min(700, available.height - 40, available.width - 40)
            window.setContentSize(NSSize(width: edge, height: edge))
            window.center()
        }
    }
}

/// Only the empty top/bottom rim drags the window; pad and knob gestures stay independent.
struct MonsterWindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

/// Covers the native controls hosted by SwiftUI without changing keyboard or accessibility focus.
struct MonsterFocusRingSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = FocusRingAnchor(frame: .zero)
        DispatchQueue.main.async { view.suppressFocusRings() }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? FocusRingAnchor else { return }
        DispatchQueue.main.async { view.suppressFocusRings() }
    }

    private final class FocusRingAnchor: NSView {
        private var windowUpdateObserver: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let windowUpdateObserver {
                NotificationCenter.default.removeObserver(windowUpdateObserver)
                self.windowUpdateObserver = nil
            }
            guard let window else { return }
            suppressFocusRings()
            windowUpdateObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didUpdateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.suppressFocusRings()
            }
        }

        func suppressFocusRings() {
            guard let root = window?.contentView else { return }
            suppressFocusRings(in: root)
        }

        private func suppressFocusRings(in view: NSView) {
            view.focusRingType = .none
            view.subviews.forEach { suppressFocusRings(in: $0) }
        }

        deinit {
            if let windowUpdateObserver { NotificationCenter.default.removeObserver(windowUpdateObserver) }
        }
    }
}

struct MonsterOverlayButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white.opacity(enabled ? 1 : 0.45))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.black.opacity(configuration.isPressed ? 0.95 : 0.78), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.white.opacity(0.22)))
    }
}
