import AppKit
import IOKit.hid

/// Écoute globale des événements souris + clavier via NSEvent.
/// - La souris ne nécessite aucune autorisation.
/// - Le clavier nécessite l'autorisation "Surveillance des saisies" (Input Monitoring).
final class EventMonitor {
    static let shared = EventMonitor()
    private var monitors: [Any] = []

    private let masks: NSEvent.EventTypeMask = [
        .leftMouseDown, .rightMouseDown, .otherMouseDown,
        .keyDown, .scrollWheel,
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
    ]

    func start() {
        // Demande l'autorisation "Surveillance des saisies" pour le clavier.
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        // Événements destinés aux AUTRES apps.
        if let g = NSEvent.addGlobalMonitorForEvents(matching: masks, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(g)
        }

        // Événements reçus par Mousy lui-même (quand le panneau a le focus).
        if let l = NSEvent.addLocalMonitorForEvents(matching: masks, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(l)
        }
    }

    /// Vrai si "Surveillance des saisies" est accordée (requise pour compter le clavier).
    var keyboardTrusted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    private func handle(_ event: NSEvent) {
        let store = StatsStore.shared
        switch event.type {
        case .leftMouseDown:
            store.recordLeftClick()
        case .rightMouseDown:
            store.recordRightClick()
        case .otherMouseDown:
            store.recordOtherClick()
        case .keyDown:
            if !event.isARepeat { store.recordKey() } // on ignore l'auto-répétition
        case .scrollWheel:
            store.recordScroll()
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            store.recordMovement(dx: event.deltaX, dy: event.deltaY)
        default:
            break
        }
    }
}
