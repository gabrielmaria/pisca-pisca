import AppKit

let size = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

// Fundo: squircle escuro com gradiente
let inset: CGFloat = 54
let rect = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let squircle = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)
NSGradient(colors: [NSColor(srgbRed: 0.17, green: 0.20, blue: 0.19, alpha: 1),
                    NSColor(srgbRed: 0.05, green: 0.06, blue: 0.06, alpha: 1)])!
    .draw(in: squircle, angle: -90)

// Brilho verde suave atrás do olho
// Traço de luz no topo do squircle
let sheen = NSBezierPath()
sheen.move(to: NSPoint(x: 200, y: 940))
sheen.curve(to: NSPoint(x: 824, y: 940),
            controlPoint1: NSPoint(x: 340, y: 985),
            controlPoint2: NSPoint(x: 684, y: 985))
sheen.lineWidth = 6
sheen.lineCapStyle = .round
NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
sheen.stroke()

// Contorno do olho
let cx: CGFloat = 512, cy: CGFloat = 600
let w: CGFloat = 500, h: CGFloat = 260
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
eye.lineWidth = 30
eye.lineCapStyle = .round
eye.lineJoinStyle = .round
NSColor(srgbRed: 0.96, green: 0.98, blue: 0.97, alpha: 1).setStroke()
eye.stroke()

// Íris
let iris = NSBezierPath(ovalIn: NSRect(x: cx - 104, y: cy - 104, width: 208, height: 208))
NSGradient(colors: [NSColor(srgbRed: 0.47, green: 0.96, blue: 0.76, alpha: 1),
                    NSColor(srgbRed: 0.05, green: 0.66, blue: 0.50, alpha: 1)])!
    .draw(in: iris, angle: -90)

// Pupila
let pupil = NSBezierPath(ovalIn: NSRect(x: cx - 46, y: cy - 46, width: 92, height: 92))
NSColor(srgbRed: 0.02, green: 0.08, blue: 0.06, alpha: 1).setFill()
pupil.fill()

// Reflexo
let shine = NSBezierPath(ovalIn: NSRect(x: cx - 62, y: cy + 18, width: 34, height: 34))
NSColor(calibratedWhite: 1, alpha: 0.8).setFill()
shine.fill()

// Texto 20 · 20 · 20
let base = NSFont.systemFont(ofSize: 88, weight: .semibold)
let desc = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
let font = NSFont(descriptor: desc, size: 88) ?? base
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.88),
    .kern: 9
]
let text = NSAttributedString(string: "20 · 20 · 20", attributes: attrs)
let tsize = text.size()
text.draw(at: NSPoint(x: (CGFloat(size) - tsize.width) / 2, y: 210))

img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
rep.size = NSSize(width: size, height: size)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("ok")
