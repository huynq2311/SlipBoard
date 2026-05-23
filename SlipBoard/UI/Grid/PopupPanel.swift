import AppKit
import SwiftUI

public struct PopupPanelPlaceholderView: View {
    public init() {}
    public var body: some View {
        VStack {
            Text("Popup Grid Placeholder")
                .foregroundColor(.white)
                .padding()
        }
        .frame(width: 800, height: 400)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
    }
}

public class PopupPanel: NSPanel {
    public init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.contentView = contentView
    }
    
    public override func resignKey() {
        super.resignKey()
        // Hide panel when focus is lost (clicking outside)
        self.orderOut(nil)
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
}
