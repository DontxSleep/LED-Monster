import AppKit
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.063, green: 0.075, blue: 0.082, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204).fill()
let path = NSBezierPath(roundedRect: NSRect(x: 244, y: 244, width: 536, height: 536), xRadius: 124, yRadius: 124)
NSColor(calibratedRed: 0.831, green: 0.929, blue: 0.667, alpha: 1).setStroke()
path.lineWidth = 48; path.stroke()
let letter: NSString = "l"
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 320, weight: .medium), .foregroundColor: NSColor.white]
letter.draw(at: NSPoint(x: 466, y: 322), withAttributes: attrs)
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
