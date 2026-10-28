import AppKit
import SwiftUI

/// Invisible view that holds keyboard focus and forwards physical key codes to the engine.
struct KeyCatcher: NSViewRepresentable {
    func makeNSView(context: Context) -> KeyView { KeyView() }
    func updateNSView(_ view: KeyView, context: Context) {}
}

final class KeyView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.window?.makeFirstResponder(self) }
    }

    override func keyDown(with event: NSEvent) {
        // Leave Cmd and Ctrl combos to the menus so Cmd-Q and Cmd-W keep working.
        if !event.modifierFlags.intersection([.command, .control]).isEmpty {
            return super.keyDown(with: event)
        }
        if !event.isARepeat { Engine.shared.keyDown(event.keyCode) }
    }

    override func keyUp(with event: NSEvent) {
        Engine.shared.keyUp(event.keyCode)
    }

    override func resignFirstResponder() -> Bool {
        Engine.shared.releaseAll()
        return super.resignFirstResponder()
    }
}
