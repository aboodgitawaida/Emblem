import AppKit
import SwiftUI

/// Draws the menu bar icon at any point of the circle → owl morph.
/// progress 0 = play.circle, 1 = owl. Images are templates, so macOS tints them for light/dark menu bars.
enum StatusIconRenderer {
    static let canvas = NSSize(width: 18, height: 18)
    // Tuned so the owl sits with SF Symbols in the menu bar: lines thickened to roughly
    // their stroke weight, height matched to play.circle.
    static let owlHeight: CGFloat = 16.5
    static let owlWeight: CGFloat = 0.4   // extra outline stroke, in points

    static let circleSymbol: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let img = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Now Playing")!
            .withSymbolConfiguration(config)!
        img.isTemplate = true
        return img
    }()

    private static let owlPaths: [CGPath] = {
        let w = owlHeight * Owl.aspect
        let rect = CGRect(x: (canvas.width - w) / 2, y: (canvas.height - owlHeight) / 2, width: w, height: owlHeight)
        return Owl.paths(in: rect).map(\.cgPath)
    }()

    static func image(progress raw: CGFloat) -> NSImage {
        let p = min(max(raw, 0), 1)
        if p == 0 { return circleSymbol }
        let img = NSImage(size: canvas, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            draw(progress: p, in: ctx)
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Now Playing"
        return img
    }

    private static func draw(progress p: CGFloat, in ctx: CGContext) {
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

        // Owl: its lines are revealed along their own outlines, like a pen tracing them in.
        // The reveal mask is a wide stroke of the trimmed outlines; the owl fill shows through it.
        let trace = smooth((p - 0.15) / 0.85)
        guard trace > 0 else { return }
        ctx.saveGState()
        if trace < 1 {
            ctx.setLineWidth(1.8)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            for path in owlPaths { ctx.addPath(Path(path).trimmedPath(from: 0, to: trace).cgPath) }
            ctx.replacePathWithStrokedPath()
            ctx.clip()
        }
        ctx.setFillColor(NSColor.black.cgColor)
        let paths = owlPaths
        for path in paths { ctx.addPath(path) }
        ctx.fillPath(using: .winding)
        if owlWeight > 0 {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(owlWeight)
            ctx.setLineJoin(.round)
            // Only the body outline (last path) gets weight; the eyes and beak stay crisp,
            // since thickening them fills in the face at menu bar size.
            if let body = paths.last { ctx.addPath(body) }
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

/// Animates the status item's image between circle and owl.
@MainActor
final class StatusIconAnimator {
    private weak var button: NSStatusBarButton?
    private(set) var progress: CGFloat = 0
    private var target: CGFloat = 0
    private var timer: Timer?
    private var lastTick = Date()
    let duration: TimeInterval = 0.75

    init(button: NSStatusBarButton) {
        self.button = button
        button.image = StatusIconRenderer.image(progress: 0)
    }

    func setOwl(_ owl: Bool, animated: Bool = true) {
        let newTarget: CGFloat = owl ? 1 : 0
        guard newTarget != target || (timer == nil && progress != newTarget) else { return }
        target = newTarget
        guard animated else {
            progress = target; timer?.invalidate(); timer = nil
            button?.image = StatusIconRenderer.image(progress: progress)
            return
        }
        guard timer == nil else { return }   // a running animation simply reverses toward the new target
        lastTick = Date()
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        let step = CGFloat(now.timeIntervalSince(lastTick) / duration)
        lastTick = now
        progress = target > progress ? min(progress + step, target) : max(progress - step, target)
        button?.image = StatusIconRenderer.image(progress: progress)
        if progress == target { timer?.invalidate(); timer = nil }
    }
}
