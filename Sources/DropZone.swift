import AppKit
import UniformTypeIdentifiers

final class DropZoneView: NSView {
    var onPaths: (([String]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"),
        ])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"),
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let paths = Self.paths(from: sender.draggingPasteboard)
        guard !paths.isEmpty else { return false }
        onPaths?(paths)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.windowBackgroundColor.withAlphaComponent(0.4).setFill()
        bounds.fill()
        let inset = bounds.insetBy(dx: 12, dy: 12)
        let path = NSBezierPath(roundedRect: inset, xRadius: 10, yRadius: 10)
        path.lineWidth = 2
        let dashes: [CGFloat] = [7, 5]
        path.setLineDash(dashes, count: 2, phase: 0)
        NSColor.secondaryLabelColor.setStroke()
        path.stroke()
        let text = "Drop .app, media, .apns, or URL file"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        text.draw(at: point, withAttributes: attrs)
    }

    static func paths(from pasteboard: NSPasteboard) -> [String] {
        if let files = pasteboard.propertyList(
            forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        ) as? [String], !files.isEmpty {
            return files
        }
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
        ]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            return urls.map(\.path)
        }
        return []
    }
}

final class DropZoneController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    var onPaths: (([String]) -> Void)?

    func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Drop zone"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            let view = DropZoneView(frame: NSRect(x: 0, y: 0, width: 360, height: 220))
            view.onPaths = { [weak self] paths in
                self?.onPaths?(paths)
            }
            panel.contentView = view
            panel.center()
            self.panel = panel
        }
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}
