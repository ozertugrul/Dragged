import AppKit

public class GlobalEventMonitor {
    public static let shared = GlobalEventMonitor()

    private var globalFlagsMonitor: Any? = nil
    private var globalDragMonitor: Any? = nil
    private var globalMouseUpMonitor: Any? = nil
    private var globalScrollMonitor: Any? = nil
    private var globalKeyMonitor: Any? = nil
    private var localFlagsMonitor: Any? = nil
    private var localScrollMonitor: Any? = nil
    private var localKeyMonitor: Any? = nil

    private init() {}

    public func startMonitoring() {
        stopMonitoring()

        // 1. Global Modifier Flags Monitor (Shift / Option)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // 2. Global Mouse Drag Monitor
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.handleMouseDragged(event)
        }

        // 3. Global Scroll Wheel Monitor (switch pages while dragging in Finder!)
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { event in
            guard RadialWindow.shared.isVisible else { return }
            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            DispatchQueue.main.async {
                RadialWheelState.shared.handleScroll(delta: delta)
            }
        }

        // 4. Global Mouse Up Monitor (clean dismissal if released without drop)
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
            if RadialWindow.shared.isVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if RadialWindow.shared.isVisible {
                        RadialWindow.shared.hideWheel()
                    }
                }
            }
        }

        // 5. Global Key Monitor (Escape to dismiss)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 && RadialWindow.shared.isVisible {
                DispatchQueue.main.async {
                    RadialWindow.shared.hideWheel()
                }
            }
        }

        // 6. Local Monitors (when our app is focused)
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
            if RadialWindow.shared.isVisible {
                let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
                RadialWheelState.shared.handleScroll(delta: delta)
                return nil
            }
            return event
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 && RadialWindow.shared.isVisible {
                RadialWindow.shared.hideWheel()
                return nil
            }
            return event
        }

        // Request accessibility permissions for deeper event taps if needed
        checkAccessibility()
    }

    public func stopMonitoring() {
        if let g = globalFlagsMonitor { NSEvent.removeMonitor(g); globalFlagsMonitor = nil }
        if let d = globalDragMonitor { NSEvent.removeMonitor(d); globalDragMonitor = nil }
        if let s = globalScrollMonitor { NSEvent.removeMonitor(s); globalScrollMonitor = nil }
        if let m = globalMouseUpMonitor { NSEvent.removeMonitor(m); globalMouseUpMonitor = nil }
        if let k = globalKeyMonitor { NSEvent.removeMonitor(k); globalKeyMonitor = nil }
        if let l = localFlagsMonitor { NSEvent.removeMonitor(l); localFlagsMonitor = nil }
        if let ls = localScrollMonitor { NSEvent.removeMonitor(ls); localScrollMonitor = nil }
        if let lk = localKeyMonitor { NSEvent.removeMonitor(lk); localKeyMonitor = nil }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let isShiftHeld = event.modifierFlags.contains(.shift)
        let isOptionHeld = event.modifierFlags.contains(.option)
        let isMouseDown = (NSEvent.pressedMouseButtons & 1) != 0

        // Case A: User is dragging (mouse button down) and presses Shift -> SUMMON RADIAL WHEEL!
        if isShiftHeld && isMouseDown {
            DispatchQueue.main.async {
                if !RadialWindow.shared.isVisible {
                    RadialWindow.shared.showAtCursor(with: nil, toolMode: isOptionHeld)
                }
            }
        }
        // Case B: User released Shift while wheel is open -> Dismiss wheel
        else if !isShiftHeld && RadialWindow.shared.isVisible {
            DispatchQueue.main.async {
                RadialWindow.shared.hideWheel()
            }
        }
        // Case C: User is in wheel and toggles Option key -> switch between Formats & Tools
        else if isShiftHeld && RadialWindow.shared.isVisible {
            DispatchQueue.main.async {
                RadialWindow.shared.setToolMode(isOptionHeld)
            }
        }
    }

    private func handleMouseDragged(_ event: NSEvent) {
        let isShiftHeld = event.modifierFlags.contains(.shift)
        let isOptionHeld = event.modifierFlags.contains(.option)

        // If Shift is held and dragging occurs -> summon wheel at cursor!
        if isShiftHeld && !RadialWindow.shared.isVisible {
            DispatchQueue.main.async {
                RadialWindow.shared.showAtCursor(with: nil, toolMode: isOptionHeld)
            }
        }
    }

    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
