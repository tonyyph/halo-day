#!/usr/bin/env swift
// Renders the v2 app icon (light, dark, tinted) from the Living Sky / Celestial keyframe colours and the Orbit ring.
// Usage: swift scripts/generate_icon.swift <AppIcon.appiconset>
import AppKit
import CoreGraphics

let size = 1024
let out = CommandLine.arguments.dropFirst().first ?? "HaloDayApp/Resources/Assets.xcassets/AppIcon.appiconset"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

enum Variant { case light, dark, tinted }

func render(_ variant: Variant) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alphaInfo = variant == .tinted ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: alphaInfo)!
    let s = CGFloat(size)
    let center = CGPoint(x: s / 2, y: s * 0.5)
    let radius = s * 0.30
    let track = s * 0.072

    // Sky (CoreGraphics origin is bottom-left: index 0 = bottom stop).
    switch variant {
    case .light:
        let g = CGGradient(colorsSpace: space, colors: [color(0xF6CDA9), color(0xE0B2C0), color(0x8E97D0)] as CFArray, locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s), options: [])
    case .dark:
        let g = CGGradient(colorsSpace: space, colors: [color(0x1C1A36), color(0x12142C), color(0x0A0B1C)] as CFArray, locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: s), options: [])
        // A few stars.
        var seed: UInt64 = 7
        for _ in 0..<70 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = CGFloat(seed >> 33 & 1023), y = CGFloat(seed >> 13 & 1023)
            let r = CGFloat(seed >> 50 & 3) * 0.8 + 1.2
            ctx.setFillColor(color(0xFBF7F0, 0.25 + CGFloat(seed >> 40 & 7) / 14))
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
    case .tinted:
        break
    }

    // Inner glow.
    let glowColor: UInt32 = variant == .dark ? 0x9DB0FF : 0xFFE2B0
    if variant != .tinted {
        let glow = CGGradient(colorsSpace: space, colors: [color(glowColor, variant == .dark ? 0.35 : 0.7), color(glowColor, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius * 1.05, options: [])
    }

    // Track.
    let trackInk: CGColor = switch variant {
    case .light: color(0xFBF7F0, 0.55)
    case .dark: color(0xFBF7F0, 0.28)
    case .tinted: color(0xFFFFFF, 0.35)
    }
    ctx.setLineWidth(track)
    ctx.setStrokeColor(trackInk)
    ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))

    // Day arcs (noon at top, clockwise like the Orbit). Angle for hour h: 90° - (h-12)*15° in CG (counter-clockwise positive).
    func angle(_ h: CGFloat) -> CGFloat { (90 - (h - 12) * 15) * .pi / 180 }
    let arcs: [(CGFloat, CGFloat, UInt32)] = [(9.0, 11.0, 0x5B6FD6), (13.0, 14.5, 0xD0567A), (16.0, 17.5, 0x3E9C7E)]
    ctx.setLineCap(.round)
    for (start, end, hex) in arcs {
        ctx.setStrokeColor(variant == .tinted ? color(0xFFFFFF, 0.9) : color(hex))
        ctx.addArc(center: center, radius: radius, startAngle: angle(start), endAngle: angle(end), clockwise: true)
        ctx.strokePath()
    }

    // The sun (or moon) on the ring at 07:30.
    let a = angle(7.5)
    let p = CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
    let bodyR = track * (variant == .dark ? 1.15 : 0.95)
    if variant != .tinted {
        let halo = CGGradient(colorsSpace: space, colors: [color(variant == .dark ? 0xDDE3FF : 0xFFF4D6, 0.95), color(variant == .dark ? 0x9DB0FF : 0xFFC99A, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(halo, startCenter: p, startRadius: 0, endCenter: p, endRadius: bodyR * 4.2, options: [])
    }
    let body = CGRect(x: p.x - bodyR, y: p.y - bodyR, width: 2 * bodyR, height: 2 * bodyR)
    ctx.setFillColor(variant == .dark ? color(0xEEF0FF) : color(0xFFFFFF))
    if variant == .dark {
        // Crescent: the moon minus an offset disc, so the sky and ring show through the cut.
        let cut = bodyR * 0.86
        let c = CGPoint(x: p.x + bodyR * 0.5, y: p.y + bodyR * 0.38)
        ctx.saveGState()
        ctx.addEllipse(in: body)
        ctx.clip()
        ctx.addEllipse(in: body)
        ctx.addEllipse(in: CGRect(x: c.x - cut, y: c.y - cut, width: 2 * cut, height: 2 * cut))
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    } else {
        ctx.fillEllipse(in: body)
    }
    return ctx.makeImage()!
}

func write(_ image: CGImage, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: out).appendingPathComponent(name))
}

write(render(.light), "AppIcon.png")
write(render(.dark), "AppIcon-Dark.png")
write(render(.tinted), "AppIcon-Tinted.png")
let contents = """
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "AppIcon-Dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ], "filename" : "AppIcon-Tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try! contents.write(toFile: out + "/Contents.json", atomically: true, encoding: .utf8)
print("Wrote icons to \(out)")
