import Foundation
import AppKit

class MacWindow: TreeNode, Hashable { // todo rename to Window?
    let windowId: CGWindowID
    // todo: make private
    let axWindow: AXUIElement
    let app: MacApp
    private var prevUnhiddenEmulationPosition: CGPoint?
    // todo redundant?
    private var prevUnhiddenEmulationSize: CGSize?
    fileprivate var previousSize: CGSize?
    private var axObservers: [AXObserverWrapper] = [] // keep observers in memory

    private init(_ id: CGWindowID, _ app: MacApp, _ axWindow: AXUIElement, parent: TreeNode) {
        self.windowId = id
        self.app = app
        self.axWindow = axWindow
        super.init(parent: parent)
    }

    fileprivate static var allWindows: [CGWindowID: MacWindow] = [:]

    static func get(app: MacApp, axWindow: AXUIElement) -> MacWindow? {
        guard let id = axWindow.windowId() else { return nil }
        if let existing = allWindows[id] {
            return existing
        } else {
            guard let topLeftCorner = axWindow.get(Ax.topLeftCornerAttr) else { return nil }
            let workspace = topLeftCorner.monitorApproximation.workspace
            // Layout the window in the container of the last active window
            let parent = workspace.lastActiveWindow?.parent ?? workspace.rootContainer
            let window = MacWindow(id, app, axWindow, parent: parent)
            debug("New window detected: \(window.title)")

            window.observe(windowIsDestroyedObs, kAXUIElementDestroyedNotification)
            window.observe(refreshObs, kAXWindowDeminiaturizedNotification)
            window.observe(refreshObs, kAXWindowMiniaturizedNotification)
            window.observe(refreshObs, kAXMovedNotification)
            window.observe(refreshObs, kAXResizedNotification)
//            window.observe(refreshObs, kAXFocusedUIElementChangedNotification)

            allWindows[id] = window
            return window
        }
    }

    func free() {
        for obs in axObservers {
            AXObserverRemoveNotification(obs.obs, obs.ax, obs.notif)
        }
        axObservers = []
    }

    private func observe(_ handler: AXObserverCallback, _ notifKey: String) {
        let observer = AXObserver.observe(app.nsApp.processIdentifier, notifKey, axWindow, self, handler)
        axObservers.append(AXObserverWrapper(obs: observer, ax: axWindow, notif: notifKey as CFString))
    }

    var title: String? {
        axWindow.get(Ax.titleAttr)
    }

    func activate() -> Bool {
        app.nsApp.activate(options: .activateIgnoringOtherApps)
        return AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString) == AXError.success
    }

    func close() -> Bool {
        guard let closeButton = axWindow.get(Ax.closeButtonAttr) else { return false }
        return AXUIElementPerformAction(closeButton, kAXPressAction as CFString) == AXError.success
    }

    // todo current approach breaks mission control (three fingers up the trackpad). Or is it only because of IDEA?
    // todo hypnotize: change size to cooperate with mission control (make it configurable)
    func hideByEmulation() {
        // Don't accidentally override prevUnhiddenEmulationPosition in case of subsequent
        // `hideEmulation` calls
        if !isHiddenEmulation {
            prevUnhiddenEmulationPosition = topLeftCorner
            prevUnhiddenEmulationSize = getSize()
        }
        guard let monitorApproximation else { return }
//        let foo = if true { true } else {false}
        // todo hiding is broken for secondary monitor
        setPosition(monitorApproximation.rect.bottomRight)
//        setSize(CGSize(width: 0, height: 0))
    }

    func unhideByEmulation() {
        assert((prevUnhiddenEmulationPosition != nil) == (prevUnhiddenEmulationSize != nil))
        guard let prevUnhiddenEmulationPosition else { return }
        guard let prevUnhiddenEmulationSize else { return }
        self.prevUnhiddenEmulationPosition = nil
        self.prevUnhiddenEmulationSize = nil
        setPosition(prevUnhiddenEmulationPosition)

        // Restore the size because during hiding the window can end up on different monitor with different density,
        // size, etc. And macOS changes the size of the window when the window is moved on different monitor in that
        // case. So we need to restore the size of the window
//        setSize(prevUnhiddenEmulationSize)
    }

    var isHiddenEmulation: Bool {
        assert((prevUnhiddenEmulationPosition != nil) == (prevUnhiddenEmulationSize != nil))
        return prevUnhiddenEmulationPosition != nil
    }

    func setSize(_ size: CGSize) {
        previousSize = getSize()
        axWindow.set(Ax.sizeAttr, size)
    }

    func getSize() -> CGSize {
        axWindow.get(Ax.sizeAttr)!
    }

    func setPosition(_ position: CGPoint) {
        axWindow.set(Ax.topLeftCornerAttr, position)
    }

    var topLeftCorner: CGPoint? {
        axWindow.get(Ax.topLeftCornerAttr)
    }

    //static func ==(lhs: MacWindow, rhs: MacWindow) -> Bool {
    //    lhs.windowId == rhs.windowId
    //}

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }
}

extension MacWindow {
    var monitorApproximation: NSScreen? {
        topLeftCorner?.monitorApproximation
    }
}

private extension UnsafeMutableRawPointer {
    var window: MacWindow { Unmanaged.fromOpaque(self).takeUnretainedValue() }
}

private func windowIsDestroyedObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    guard let window = data?.window else { return }
    debug("Destroyed: \(window.title)")
    assert(MacWindow.allWindows.removeValue(forKey: window.windowId) != nil)
    for workspace in Workspace.all {
        workspace.remove(window: window)
    }
    window.free()
    refresh()
}