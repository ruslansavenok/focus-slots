import AppKit
import Foundation

let root = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: root).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let factor = CGFloat(pixels) / 1024
        let transform = NSAffineTransform()
        transform.scale(by: factor)
        transform.concat()
        NSColor(calibratedRed: 0.18, green: 0.39, blue: 0.33, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 30, y: 30, width: 964, height: 964), xRadius: 216, yRadius: 216).fill()
        NSColor(calibratedWhite: 0.96, alpha: 1).setStroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: 218, y: 218, width: 588, height: 588))
        ring.lineWidth = 38
        ring.stroke()
        let hands = NSBezierPath()
        hands.lineWidth = 42
        hands.lineCapStyle = .round
        hands.move(to: NSPoint(x: 512, y: 708))
        hands.line(to: NSPoint(x: 512, y: 512))
        hands.line(to: NSPoint(x: 638, y: 436))
        hands.stroke()
        for i in 0..<4 {
            (i == 0 ? NSColor(calibratedRed: 0.76, green: 0.88, blue: 0.61, alpha: 1) : NSColor(calibratedWhite: 1, alpha: 0.3)).setFill()
            NSBezierPath(ovalIn: NSRect(x: 398 + i * 62, y: 124, width: 38, height: 38)).fill()
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

// A quiet, short bell with soft attack and decay; no system alert fallback.
let rate = 44100
let duration = 0.8
let samples = Int(Double(rate) * duration)
var pcm = Data()
for i in 0..<samples {
    let t = Double(i) / Double(rate)
    let attack = min(1, t / 0.035)
    let release = min(1, (duration - t) / 0.18)
    let envelope = attack * release * exp(-4.5 * t)
    let wave = sin(2 * .pi * 660 * t) + 0.28 * sin(2 * .pi * 990 * t)
    var sample = Int16(wave * envelope * 0.55 * Double(Int16.max)).littleEndian
    withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
}
var wav = Data()
func bytes(_ value: String) { wav.append(value.data(using: .ascii)!) }
func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
bytes("RIFF"); u32(UInt32(36 + pcm.count)); bytes("WAVEfmt "); u32(16)
u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
bytes("data"); u32(UInt32(pcm.count)); wav.append(pcm)
try wav.write(to: URL(fileURLWithPath: root).appendingPathComponent("completion.wav"))
