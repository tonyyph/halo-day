import AppKit
import Foundation

// Code-native placeholder artwork; replace with final branded art before release.
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
NSColor(calibratedRed: 0.965, green: 0.949, blue: 0.933, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.95, green: 0.827, blue: 0.839, alpha: 1), ending: NSColor(calibratedRed: 0.965, green: 0.949, blue: 0.933, alpha: 1))!
gradient.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: size)), relativeCenterPosition: NSPoint(x: 0.2, y: 0.4))
let halo = NSBezierPath(ovalIn: NSRect(x: 180, y: 194, width: 650, height: 650))
halo.lineWidth = 13
NSColor(calibratedRed: 0.60, green: 0.52, blue: 0.45, alpha: 0.65).setStroke()
halo.stroke()
NSColor(calibratedRed: 0.69, green: 0.08, blue: 0.18, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 733, y: 715, width: 56, height: 56)).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let path = URL(fileURLWithPath: CommandLine.arguments[1])
try bitmap.representation(using: .png, properties: [:])!.write(to: path, options: .atomic)
