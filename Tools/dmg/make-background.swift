// Draws the DMG window background used by build_release.sh.
//
//   swift Tools/dmg/make-background.swift Tools/dmg
//
// Writes background.png (660x400) and background@2x.png. The icon positions in
// build_release.sh must match the arrow drawn here.
import AppKit

let width: CGFloat = 660
let height: CGFloat = 400
let appIconCenter = CGPoint(x: 170, y: 190)
let applicationsIconCenter = CGPoint(x: 490, y: 190)

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width * scale),
        pixelsHigh: Int(height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // Finder measures positions from the top left; AppKit draws from the bottom left.
    func flipped(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: height - point.y) }

    NSGradient(
        starting: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1),
        ending: NSColor(srgbRed: 0.90, green: 0.92, blue: 0.95, alpha: 1)
    )!.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    // Arrow between the two icons, clear of their 128 pt artwork.
    let start = flipped(CGPoint(x: appIconCenter.x + 88, y: appIconCenter.y))
    let end = flipped(CGPoint(x: applicationsIconCenter.x - 88, y: applicationsIconCenter.y))
    let arrowColor = NSColor(srgbRed: 0.45, green: 0.49, blue: 0.56, alpha: 1)
    arrowColor.setStroke()
    arrowColor.setFill()

    let shaft = NSBezierPath()
    shaft.lineWidth = 3
    shaft.lineCapStyle = .round
    shaft.setLineDash([8, 7], count: 2, phase: 0)
    shaft.move(to: start)
    shaft.line(to: CGPoint(x: end.x - 12, y: end.y))
    shaft.stroke()

    let head = NSBezierPath()
    head.move(to: end)
    head.line(to: CGPoint(x: end.x - 18, y: end.y + 11))
    head.line(to: CGPoint(x: end.x - 18, y: end.y - 11))
    head.close()
    head.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    func drawCaption(_ text: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(srgbRed: 0.22, green: 0.24, blue: 0.28, alpha: alpha),
            .paragraphStyle: paragraph
        ]
        let rect = NSRect(x: 0, y: height - top - size * 1.5, width: width, height: size * 1.5)
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }
    drawCaption("Drag SlipBoard to Applications to install", top: 316, size: 15, weight: .medium, alpha: 1)
    drawCaption("Kéo SlipBoard vào Applications để cài đặt", top: 342, size: 13, weight: .regular, alpha: 0.7)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try render(scale: 1).write(to: outputDirectory.appendingPathComponent("background.png"))
try render(scale: 2).write(to: outputDirectory.appendingPathComponent("background@2x.png"))
