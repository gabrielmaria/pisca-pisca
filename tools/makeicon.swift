import AppKit

// Uso: ./makeicon <output.png> [mono|green]
let outPath = CommandLine.arguments[1]
let mode = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "mono"

let size = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Fundo branco (squircle) com sombra muito subtil
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

// Contorno fino para o ícone não se perder num fundo branco
NSGraphicsContext.saveGraphicsState()
let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 218, yRadius: 218)
border.lineWidth = 3
NSColor(calibratedWhite: 0, alpha: 0.06).setStroke()
border.stroke()
NSGraphicsContext.restoreGraphicsState()

// Olho minimalista
let cx: CGFloat = 512, cy: CGFloat = 548
let w: CGFloat = 520, h: CGFloat = 250
let eye = NSBezierPath()
eye.move(to: NSPoint(x: cx - w / 2, y: cy))
eye.curve(to: NSPoint(x: cx, y: cy + h / 2),
          controlPoint1: NSPoint(x: cx - w / 3.2, y: cy + h / 2.15),
          controlPoint2: NSPoint(x: cx - w / 7, y: cy + h / 2))
eye.curve(to: NSPoint(x: cx + w / 2, y: cy),
          controlPoint1: NSPoint(x: cx + w / 7, y: cy + h / 2),
          controlPoint2: NSPoint(x: cx + w / 3.2, y: cy + h / 2.15))
eye.curve(to: NSPoint(x: cx, y: cy - h / 2),
          controlPoint1: NSPoint(x: cx + w / 3.2, y: cy - h / 2.15),
          controlPoint2: NSPoint(x: cx + w / 7, y: cy - h / 2))
eye.curve(to: NSPoint(x: cx - w / 2, y: cy),
          controlPoint1: NSPoint(x: cx - w / 7, y: cy - h / 2),
          controlPoint2: NSPoint(x: cx - w / 3.2, y: cy - h / 2.15))
eye.close()
eye.lineWidth = 24
eye.lineCapStyle = .round
eye.lineJoinStyle = .round
NSColor(srgbRed: 0.07, green: 0.08, blue: 0.08, alpha: 1).setStroke()
eye.stroke()

if mode == "green" {
    // Íris verde discreta + pupila
    let iris = NSBezierPath(ovalIn: NSRect(x: cx - 96, y: cy - 96, width: 192, height: 192))
    NSColor(srgbRed: 0.09, green: 0.64, blue: 0.42, alpha: 1).setFill()
    iris.fill()

    let pupil = NSBezierPath(ovalIn: NSRect(x: cx - 44, y: cy - 44, width: 88, height: 88))
    NSColor(srgbRed: 0.05, green: 0.06, blue: 0.06, alpha: 1).setFill()
    pupil.fill()
} else {
    // Monocromático: apenas uma pupila sólida
    let pupil = NSBezierPath(ovalIn: NSRect(x: cx - 88, y: cy - 88, width: 176, height: 176))
    NSColor(srgbRed: 0.07, green: 0.08, blue: 0.08, alpha: 1).setFill()
    pupil.fill()
}

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
rep.size = NSSize(width: size, height: size)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: outPath))
print("ok")
