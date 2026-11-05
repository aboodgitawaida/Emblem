import AppKit
import SwiftUI

/// Draws the menu bar icon at any point of the circle → logo morph.
/// progress 0 = play.circle, 1 = the brand's logo. Images are templates, so macOS tints them for light/dark menu bars.
enum StatusIconRenderer {
    static let canvas = NSSize(width: 18, height: 18)

    static let circleSymbol: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let img = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Now Playing")!
            .withSymbolConfiguration(config)!
        img.isTemplate = true
        return img
    }()

    /// Each brand's logo at menu bar size, centred on the canvas. Heights are tuned so the logos sit
    /// with SF Symbols: the owl matches play.circle's height, the solid bear sits a touch bigger.
    @MainActor private static var pathCache: [String: [CGPath]] = [:]

    @MainActor private static func iconPaths(_ brand: Brand) -> [CGPath] {
        if let p = pathCache[brand.id] { return p }
        // A logo wider than the canvas would be clipped at the sides, so it's scaled down to fit.
        var h = brand.iconHeight, w = h * brand.logo.aspect
        if w > canvas.width { w = canvas.width; h = w / brand.logo.aspect }
        let rect = CGRect(x: (canvas.width - w) / 2, y: (canvas.height - h) / 2, width: w, height: h)
        let p = brand.logo.paths(in: rect).map(\.cgPath)
        pathCache[brand.id] = p
        return p
    }

    /// `glint` (0…1) is a streak of light passing across the finished logo; nil for none.
    @MainActor static func image(progress raw: CGFloat, brand: Brand?, glint: CGFloat? = nil) -> NSImage {
        let p = min(max(raw, 0), 1)
        guard p > 0, let brand else { return circleSymbol }
        let paths = iconPaths(brand)
        let img = NSImage(size: canvas, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(progress: p, brand: brand, paths: paths, in: ctx)
            if p == 1, let g = glint, g > 0, g < 1 { applyGlint(g, in: ctx) }
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Now Playing"
        return img
    }

    private static func draw(progress p: CGFloat, brand: Brand, paths: [CGPath], in ctx: CGContext) {
        // Circle: shrinks toward the centre and fades out over the first ~60%.
        let circleT = smooth(p / 0.6)
        if circleT < 1 {
            let s = circleSymbol.size
            let scale = 1 - 0.55 * circleT
            let r = NSRect(x: (canvas.width - s.width * scale) / 2, y: (canvas.height - s.height * scale) / 2,
                           width: s.width * scale, height: s.height * scale)
            circleSymbol.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1 - circleT,
                              respectFlipped: true, hints: nil)
        }

        // Logo: its lines are revealed along their own outlines, like a pen tracing them in.
        // The reveal mask is a wide stroke of the trimmed outlines; the logo fill shows through it.
        let trace = smooth((p - 0.15) / 0.85)
        guard trace > 0 else { return }
        ctx.saveGState()
        // The logo springs into place as it traces in: it grows from 90% with a small overshoot
        // (~1%, so it still fits the 18pt icon) and settles, like Apple's spring animations.
        let x = min(max((p - 0.15) / 0.85, 0), 1)
        let scale = x >= 1 ? 1 : 0.9 + 0.1 * spring(x)   // exactly 100% at rest
        ctx.translateBy(x: canvas.width / 2, y: canvas.height / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -canvas.width / 2, y: -canvas.height / 2)
        if trace < 1, brand.logo.solid {
            // A pen traces the outline, then the shape fills in as the pen line fades away.
            let fill = smooth((trace - 0.45) / 0.55)
            if fill > 0 {
                ctx.setAlpha(fill)
                for path in paths { ctx.addPath(path) }
                ctx.fillPath(using: brand.logo.evenOdd ? .evenOdd : .winding)
            }
            ctx.setAlpha(1 - fill)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for path in paths { ctx.addPath(Path(path).trimmedPath(from: 0, to: min(trace / 0.6, 1)).cgPath) }
            ctx.strokePath()
            ctx.restoreGState()
            return
        }
        if trace < 1 {
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for path in paths { ctx.addPath(Path(path).trimmedPath(from: 0, to: trace).cgPath) }
            ctx.replacePathWithStrokedPath()
            ctx.clip()
        }
        ctx.setFillColor(NSColor.black.cgColor)
        for path in paths { ctx.addPath(path) }
        ctx.fillPath(using: brand.logo.evenOdd ? .evenOdd : .winding)
        if brand.iconWeight > 0, !brand.weightedPaths.isEmpty {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(brand.iconWeight)
            ctx.setLineJoin(.round)
            for i in brand.weightedPaths where paths.indices.contains(i) { ctx.addPath(paths[i]) }
            ctx.strokePath()
        }
        for (i, weight) in brand.pathWeights where weight > 0 && paths.indices.contains(i) {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(weight)
            ctx.setLineJoin(.round)
            ctx.addPath(paths[i])
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// A streak of light across the logo. The icon is a template (macOS tints it), so it can't get
    /// brighter than full: instead the logo dims a little while a full-strength diagonal band sweeps
    /// across it, then returns to normal. Drawn by erasing alpha outside the band.
    private static func applyGlint(_ g: CGFloat, in ctx: CGContext) {
        let dim = 0.45 * sin(.pi * g)      // fades in and out over the sweep
        let centre = -0.25 + 1.5 * g      // band position along the diagonal
        let n = 24
        var locations: [CGFloat] = [], components: [CGFloat] = []
        for k in 0...n {
            let x = CGFloat(k) / CGFloat(n)
            let band = exp(-pow((x - centre) / 0.13, 2))
            locations.append(x)
            components += [0, 0, 0, dim * (1 - band)]
        }
        guard let gradient = CGGradient(colorSpace: CGColorSpaceCreateDeviceRGB(), colorComponents: components,
                                        locations: locations, count: n + 1) else { return }
        ctx.saveGState()
        ctx.setBlendMode(.destinationOut)
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: canvas.width, y: canvas.height),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    /// An underdamped spring over 0…1: rises past 1 by ~12% around 0.35, then settles to 1.
    private static func spring(_ x: CGFloat) -> CGFloat {
        let damping: CGFloat = 6, freq: CGFloat = 9
        return 1 - exp(-damping * x) * (cos(freq * x) + damping / freq * sin(freq * x))
    }

    /// Clamped smoothstep.
    private static func smooth(_ x: CGFloat) -> CGFloat {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// Animates the status item's image between the circle and a brand's logo.
/// Switching straight from one brand to another traces the old logo out to the circle, then the new one in.
@MainActor
final class StatusIconAnimator {
    private weak var button: NSStatusBarButton?
    private(set) var progress: CGFloat = 0
    private var target: CGFloat = 0
    private var shown: Brand?    // the logo being drawn
    private var wanted: Brand?   // the logo we're heading to (nil = circle)
    private var timer: Timer?
    private var lastTick = Date()
    let duration: TimeInterval = 0.75
    /// The glint after a logo traces in: negative while it waits, 0…1 while it sweeps, nil when done.
    private var glintT: CGFloat?
    let glintDuration: TimeInterval = 0.9

    init(button: NSStatusBarButton) {
        self.button = button
        button.image = StatusIconRenderer.image(progress: 0, brand: nil)
    }

    func show(_ brand: Brand?, animated: Bool = true) {
        wanted = brand
        guard animated else {
            if let brand { shown = brand }
            progress = brand == nil ? 0 : 1
            target = progress
            timer?.invalidate(); timer = nil
            redraw()
            return
        }
        retarget()
        // A running animation simply heads toward the new target.
        if progress != target { startTimer() }
    }

    /// A new track by the same artist: the logo stays, so just sweep the light across it again.
    func glint() {
        guard let wanted, wanted == shown, progress == 1, target == 1 else { return }
        glintT = 0
        startTimer()
    }

    private func startTimer() {
        guard timer == nil else { return }
        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func retarget() {
        if let wanted, wanted != shown, progress > 0 {
            target = 0   // trace the old logo out first
        } else {
            if let wanted { shown = wanted }
            target = wanted == nil ? 0 : 1
        }
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        let before = progress
        let step = CGFloat(dt / duration)
        progress = target > progress ? min(progress + step, target) : max(progress - step, target)
        if progress == target { retarget() }
        // The logo just finished tracing in: the light sweeps across it after a short beat.
        if before < 1, progress == 1, wanted != nil { glintT = -0.15 }
        if let g = glintT {
            let next = g + CGFloat(dt / glintDuration)
            glintT = next >= 1 || progress < 1 ? nil : next
        }
        redraw()
        if progress == target && glintT == nil { timer?.invalidate(); timer = nil }
    }

    private func redraw() {
        let g = glintT.flatMap { $0 > 0 ? $0 : nil }
        button?.image = StatusIconRenderer.image(progress: progress, brand: shown, glint: g)
    }
}
