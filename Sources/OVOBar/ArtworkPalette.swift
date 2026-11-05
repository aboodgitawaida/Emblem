import AppKit
import SwiftUI

/// Player colours taken from the album art that's playing, for the brand artists:
/// ASTROWORLD gets its gold, IGOR its pink, and a black-and-white cover a black-and-white player.
/// Other songs keep the normal player.
enum ArtworkPalette {
    /// nil only when the image can't be read; the brand's own palette is used then.
    static func palette(from image: NSImage) -> Brand.Palette? {
        guard image.cgImage(forProposedRect: nil, context: nil, hints: nil) != nil else { return nil }
        // Black-and-white art (House of Balloons, Scorpion…) gets a silver-on-black player, so the
        // colours still follow the album rather than falling back to the artist's own.
        let mesh = meshColors(in: image)
        guard let accent = dominantColor(in: image) else {
            var p = monochrome; p.mesh = mesh; return p
        }
        let h = accent.h, s = accent.s
        return Brand.Palette(
            // Readable over the living background, which is the same hue: lighter and softer than the
            // art's colour, so the artist line and controls stand out from what's flowing behind them.
            accent: Color(hue: h, saturation: min(max(s, 0.2), 0.52), brightness: max(accent.b, 0.95)),
            highlight: Color(hue: h, saturation: s * 0.22, brightness: 1),
            knob: Color(hue: h, saturation: s * 0.32, brightness: 0.97),
            // A very dark tint of the same hue, like the fixed palettes' backgrounds.
            background: Color(hue: h, saturation: min(s, 0.55) * 0.75, brightness: 0.075),
            ambient: Color(hue: h, saturation: min(max(s, 0.3), 0.8), brightness: 0.8).opacity(0.16),
            mesh: mesh)
    }

    static let monochrome = Brand.Palette(
        accent: Color(white: 0.86),
        highlight: .white,
        knob: Color(white: 0.96),
        background: Color(white: 0.055),
        ambient: Color.white.opacity(0.10))

    /// A hue histogram of the art, weighted by saturation, brightness and closeness to the centre.
    private struct Histogram {
        static let bins = 36
        var weight = [Double](repeating: 0, count: bins)
        var sum = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: bins)
        var pixels = 0
        /// Total colour weight per pixel; low for black-and-white art.
        var colourfulness: Double { weight.reduce(0, +) / Double(max(pixels, 1)) }
        var smoothed: [Double] {
            let n = Self.bins
            return (0..<n).map { weight[($0 + n - 1) % n] + 2 * weight[$0] + weight[($0 + 1) % n] }
        }
        /// The average colour of the pixels around bin `k`.
        func colour(around k: Int) -> (h: Double, s: Double, b: Double)? {
            let n = Self.bins
            var w = 0.0, r = 0.0, g = 0.0, b = 0.0
            for j in [(k + n - 1) % n, k, (k + 1) % n] { w += weight[j]; r += sum[j].r; g += sum[j].g; b += sum[j].b }
            return w > 0 ? ArtworkPalette.hsv(r / w, g / w, b / w) : nil
        }
    }

    private static func histogram(of image: NSImage) -> Histogram? {
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
        var hist = Histogram()
        hist.pixels = side * side
        let mid = Double(side - 1) / 2
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
                let (h, s, v) = hsv(r, g, b)
                guard v > 0.15, s > 0.08 else { continue }
                let d = hypot(Double(x) - mid, Double(y) - mid) / (mid * 1.4143)
                let w = s * s * v * (1 - 0.6 * d)
                let bin = Int(h * Double(Histogram.bins)) % Histogram.bins
                hist.weight[bin] += w
                hist.sum[bin].r += r * w; hist.sum[bin].g += g * w; hist.sum[bin].b += b * w
            }
        }
        return hist
    }

    /// The most prominent colour (nil for black-and-white art): the strongest hue, where the
    /// centre weighting favours the subject (ASTROWORLD's gold head beats its blue sky).
    static func dominantColor(in image: NSImage) -> (h: Double, s: Double, b: Double)? {
        guard let hist = histogram(of: image), hist.colourfulness > 0.006 else { return nil }
        let sm = hist.smoothed
        guard let best = sm.indices.max(by: { sm[$0] < sm[$1] }) else { return nil }
        return hist.colour(around: best)
    }

    /// Four colours for the living background: the art's strongest hues (at least 40° apart),
    /// padded with lighter and darker shades of the main one. Greys for black-and-white art.
    static func meshColors(in image: NSImage) -> [Color] {
        guard let hist = histogram(of: image), hist.colourfulness > 0.006 else {
            return [Color(white: 0.42), Color(white: 0.2), Color(white: 0.32), Color(white: 0.12)]
        }
        let sm = hist.smoothed
        var picks: [Int] = []
        for k in sm.indices.sorted(by: { sm[$0] > sm[$1] }) where picks.count < 3 {
            guard let first = picks.first else { picks.append(k); continue }
            let apart = picks.allSatisfy { min(abs($0 - k), Histogram.bins - abs($0 - k)) >= 4 }
            if apart && sm[k] > sm[first] * 0.12 { picks.append(k) }
        }
        // Rich but not neon, mid brightness, so white text stays readable over the dark scrim.
        func tone(_ c: (h: Double, s: Double, b: Double), brightness: Double) -> Color {
            Color(hue: c.h, saturation: min(max(c.s, 0.35), 0.85), brightness: brightness)
        }
        let colours = picks.compactMap { hist.colour(around: $0) }
        guard let main = colours.first else { return [] }
        var out = [tone(main, brightness: 0.72)]
        out += colours.dropFirst().map { tone($0, brightness: 0.62) }
        out.append(tone((main.h, main.s, main.b), brightness: 0.42))
        if out.count < 4 { out.append(tone(((main.h + 0.035).truncatingRemainder(dividingBy: 1), main.s, main.b), brightness: 0.56)) }
        if out.count < 4 { out.append(tone(((main.h + 0.965).truncatingRemainder(dividingBy: 1), main.s, main.b), brightness: 0.3)) }
        return Array(out.prefix(4))
    }

    fileprivate static func hsv(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
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
