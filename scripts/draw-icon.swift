import AppKit
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(calibratedRed: 0.075, green: 0.095, blue: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 210, yRadius: 210).fill()
let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: 512, y: 510), radius: 284, startAngle: 220, endAngle: -40, clockwise: true)
arc.lineWidth = 62
arc.lineCapStyle = .round
NSColor(calibratedRed: 0.26, green: 0.84, blue: 0.79, alpha: 1).setStroke()
arc.stroke()
let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: 551, y: 752))
bolt.line(to: NSPoint(x: 368, y: 479))
bolt.line(to: NSPoint(x: 491, y: 479))
bolt.line(to: NSPoint(x: 454, y: 290))
bolt.line(to: NSPoint(x: 653, y: 561))
bolt.line(to: NSPoint(x: 526, y: 561))
bolt.close()
NSColor.white.setFill()
bolt.fill()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
