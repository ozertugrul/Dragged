import AppKit
import SwiftUI

public class RadialWindow: NSPanel, NSDraggingDestination {
    public static let shared = RadialWindow()

    public let state = RadialWheelState.shared
    private var hostingView: NSHostingView<RadialWheelView>? = nil
    private let windowSize: CGFloat = 390

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowSize, height: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Float above all windows and Finder drag sessions
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        self.registerForDraggedTypes([.fileURL])

        let rootView = RadialWheelView(state: self.state)
        let host = NSHostingView(rootView: rootView)
        host.frame = NSRect(x: 0, y: 0, width: windowSize, height: windowSize)
        self.contentView = host
        self.hostingView = host
    }

    public func showAtCursor(with url: URL? = nil, toolMode: Bool = false) {
        if let u = url {
            state.setFiles([u])
        } else {
            state.activeCategory = toolMode ? .tools : .formats
        }

        if toolMode {
            state.activeCategory = .tools
        }

        state.hoveredIndex = nil

        // Position centered at mouse cursor
        let mouse = NSEvent.mouseLocation
        let originX = mouse.x - (windowSize / 2)
        let originY = mouse.y - (windowSize / 2)

        self.setFrameOrigin(NSPoint(x: originX, y: originY))
        self.alphaValue = 0.0
        self.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            self.animator().alphaValue = 1.0
        }
    }

    public func setToolMode(_ isTool: Bool) {
        if isTool && state.activeCategory != .tools {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                self.state.activeCategory = .tools
            }
        } else if !isTool && state.activeCategory == .tools {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                self.state.activeCategory = .formats
            }
        }
    }

    public func hideWheel() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
            self.state.hoveredIndex = nil
        })
    }

    // MARK: - Scroll Wheel Handling
    override public func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
        state.handleScroll(delta: delta)
    }

    // MARK: - NSDraggingDestination
    public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let files = extractFileURLs(from: sender)
        if !files.isEmpty {
            state.setFiles(files)
        }

        let optionHeld = NSEvent.modifierFlags.contains(.option)
        setToolMode(optionHeld)

        let mouseInWindow = sender.draggingLocation
        let swiftUiPt = CGPoint(x: mouseInWindow.x, y: windowSize - mouseInWindow.y)
        state.updateHover(point: swiftUiPt)

        return .copy
    }

    public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let mouseInWindow = sender.draggingLocation
        let swiftUiPt = CGPoint(x: mouseInWindow.x, y: windowSize - mouseInWindow.y)
        state.updateHover(point: swiftUiPt)

        let optionHeld = NSEvent.modifierFlags.contains(.option)
        if optionHeld && state.activeCategory != .tools {
            setToolMode(true)
        } else if !optionHeld && state.activeCategory == .tools {
            setToolMode(false)
        }

        return .copy
    }

    public func draggingExited(_ sender: (any NSDraggingInfo)?) {
        state.hoveredIndex = nil
    }

    public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let files = extractFileURLs(from: sender)
        let filesToUse = files.isEmpty ? state.currentFiles : files
        let selectedIdx = state.hoveredIndex

        hideWheel()

        if let idx = selectedIdx, !filesToUse.isEmpty {
            state.triggerAction(at: idx, files: filesToUse)
            return true
        }
        return false
    }

    private func extractFileURLs(from info: any NSDraggingInfo) -> [URL] {
        let pasteboard = info.draggingPasteboard
        guard let items = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return []
        }
        return items
    }
}
