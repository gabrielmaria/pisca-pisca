import AppKit

// Uso: ./makeicon <output.png> [dot|ring] [green]
//   dot   -> olho aberto cheio (por omissão)
//   ring  -> olho aberto em contorno
//   green -> piscadela em verde
let outPath = CommandLine.arguments[1]
let style = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "dot"
let greenWink = CommandLine.arguments.contains("green")

let size = 1024
let ink = NSColor(srgbRed: 0.07, green: 0.08, blue: 0.08, alpha: 1)
let green = NSColor(srgbRed: 0.07, green: 0.62, blue: 0.41, alpha: 1)

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Fundo branco (squircle) com sombra e contorno muito subtis
let inset: CGFloat = 54
let rect = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
NSGradient(colors: [NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
                    NSColor(srgbRed: 0.955, green: 0.957, blue: 0.958, alpha: 1)])!
    .draw(in: squircle, angle: -90)

NSGraphicsContext.saveGraphicsState()
let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 218, yRadius: 218)
border.lineWidth = 3
NSColor(calibratedWhite: 0, alpha: 0.06).setStroke()
border.stroke()
NSGraphicsContext.restoreGraphicsState()

// Cara
let cx: CGFloat = 512, cy: CGFloat = 512
let faceRadius: CGFloat = 300
let face = NSBezierPath(ovalIn: NSRect(x: cx - faceRadius, y: cy - faceRadius,
                                       width: faceRadius * 2, height: faceRadius * 2))
face.lineWidth = 24
face.lineCapStyle = .round
ink.setStroke()
face.stroke()

// Olho aberto
let eyeRect = NSRect(x: cx - 190, y: cy - 36, width: 84, height: 84)
let openEye = NSBezierPath(ovalIn: eyeRect)
if style == "ring" {
    openEye.lineWidth = 26
    ink.setStroke()
    openEye.stroke()
} else {
    ink.setFill()
    openEye.fill()
}

// Olho a piscar
let wink = NSBezierPath()
wink.move(to: NSPoint(x: cx + 48, y: cy + 54))
wink.curve(to: NSPoint(x: cx + 196, y: cy + 54),
           controlPoint1: NSPoint(x: cx + 94, y: cy + 128),
           controlPoint2: NSPoint(x: cx + 152, y: cy + 128))
wink.lineWidth = 24
wink.lineCapStyle = .round
wink.lineJoinStyle = .round
(greenWink ? green : ink).setStroke()
wink.stroke()

// Sorriso
let smile = NSBezierPath()
smile.move(to: NSPoint(x: cx - 108, y: cy - 118))
smile.curve(to: NSPoint(x: cx + 108, y: cy - 118),
            controlPoint1: NSPoint(x: cx - 44, y: cy - 196),
            controlPoint2: NSPoint(x: cx + 44, y: cy - 196))
smile.lineWidth = 24
smile.lineCapStyle = .round
ink.setStroke()
smile.stroke()

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
rep.size = NSSize(width: size, height: size)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: outPath))
print("ok")
