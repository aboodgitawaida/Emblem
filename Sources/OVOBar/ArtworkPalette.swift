import AppKit
import SwiftUI

/// Player colours taken from the album art that's playing, for the brand artists:
/// ASTROWORLD gets its gold, IGOR its pink. Other songs keep the normal player.
enum ArtworkPalette {
    /// nil when the art has no real colour (black and white, greys); the brand's own palette is used then.
    static func palette(from image: NSImage) -> Brand.Palette? {
        guard let accent = dominantColor(in: image) else { return nil }
        let h = accent.h, s = accent.s
        return Brand.Palette(
            // Readable on the dark panel: bright, and not so saturated that it glares.
            accent: Color(hue: h, saturation: min(max(s, 0.22), 0.72), brightness: max(accent.b, 0.84)),
            highlight: Color(hue: h, saturation: s * 0.22, brightness: 1),
            knob: Color(hue: h, saturation: s * 0.32, brightness: 0.97),
            // A very dark tint of the same hue, like the fixed palettes' backgrounds.
            background: Color(hue: h, saturation: min(s, 0.55) * 0.75, brightness: 0.075),
            ambient: Color(hue: h, saturation: min(max(s, 0.3), 0.8), brightness: 0.8).opacity(0.16))
    }

    /// The most prominent colour: a hue histogram weighted by saturation, brightness and closeness
    /// to the centre, where the subject usually is (ASTROWORLD's gold head beats its blue sky).
    static func dominantColor(in image: NSImage) -> (h: Double, s: Double, b: Double)? {
        let side = 48
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var px = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = px.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        let bins = 36
        var weight = [Double](repeating: 0, count: bins)
        var sum = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: bins)
        let mid = Double(side - 1) / 2
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
                let (h, s, v) = hsv(r, g, b)
                guard v > 0.15, s > 0.08 else { continue }
                let d = hypot(Double(x) - mid, Double(y) - mid) / (mid * 1.4143)
                let w = s * s * v * (1 - 0.6 * d)
                let bin = Int(h * Double(bins)) % bins
                weight[bin] += w
                sum[bin].r += r * w; sum[bin].g += g * w; sum[bin].b += b * w
            }
        }
        // Mostly grey art: no colour worth using.
        guard weight.reduce(0, +) / Double(side * side) > 0.006 else { return nil }
        // Pick the strongest hue, smoothed with its neighbours, then average the pixels around it.
        let smoothed = (0..<bins).map { weight[($0 + bins - 1) % bins] + 2 * weight[$0] + weight[($0 + 1) % bins] }
        guard let best = smoothed.indices.max(by: { smoothed[$0] < smoothed[$1] }) else { return nil }
        var w = 0.0, r = 0.0, g = 0.0, b = 0.0
        for k in [(best + bins - 1) % bins, best, (best + 1) % bins] {
            w += weight[k]; r += sum[k].r; g += sum[k].g; b += sum[k].b
        }
        guard w > 0 else { return nil }
        return hsv(r / w, g / w, b / w)
    }

    private static func hsv(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, mx > 0 ? d / mx : 0, mx)
    }
}
