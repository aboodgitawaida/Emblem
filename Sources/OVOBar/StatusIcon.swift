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
    /// with SF Symbols: the owl matches play.circle's height, the wider bear sits a little smaller.
    @MainActor private static var pathCache: [String: [CGPath]] = [:]

    @MainActor private static func iconPaths(_ brand: Brand) -> [CGPath] {
        if let p = pathCache[brand.id] { return p }
        let h = brand.iconHeight, w = h * brand.logo.aspect
        let rect = CGRect(x: (canvas.width - w) / 2, y: (canvas.height - h) / 2, width: w, height: h)
        let p = brand.logo.paths(in: rect).map(\.cgPath)
        pathCache[brand.id] = p
        return p
    }

    @MainActor static func image(progress raw: CGFloat, brand: Brand?) -> NSImage {
        let p = min(max(raw, 0), 1)
        guard p > 0, let brand else { return circleSymbol }
        let paths = iconPaths(brand)
        let img = NSImage(size: canvas, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(progress: p, brand: brand, paths: paths, in: ctx)
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
        if brand.iconWeight > 0, let i = brand.weightedPath, paths.indices.contains(i) {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(brand.iconWeight)
            ctx.setLineJoin(.round)
            ctx.addPath(paths[i])
            ctx.strokePath()
        }
        ctx.restoreGState()
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
        guard timer == nil, progress != target else { return }
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
        let step = CGFloat(now.timeIntervalSince(lastTick) / duration)
        lastTick = now
        progress = target > progress ? min(progress + step, target) : max(progress - step, target)
        if progress == target { retarget() }
        redraw()
        if progress == target { timer?.invalidate(); timer = nil }
    }

    private func redraw() {
        button?.image = StatusIconRenderer.image(progress: progress, brand: shown)
    }
}
