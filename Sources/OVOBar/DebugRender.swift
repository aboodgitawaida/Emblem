import AppKit
import SwiftUI

/// Writes morph frames and both player looks as PNGs, for checking visuals without the menu bar.
@MainActor
enum DebugRender {
    static func frames(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let steps = 8
        let scale: CGFloat = 6
        let w = StatusIconRenderer.canvas.width * scale, h = StatusIconRenderer.canvas.height * scale
        let strip = NSImage(size: NSSize(width: w * CGFloat(steps + 1), height: h))
        strip.lockFocus()
        NSColor.white.setFill(); NSRect(origin: .zero, size: strip.size).fill()
        for i in 0...steps {
            let img = StatusIconRenderer.image(progress: CGFloat(i) / CGFloat(steps))
            img.draw(in: NSRect(x: CGFloat(i) * w, y: 0, width: w, height: h))
        }
        strip.unlockFocus()
        write(strip, to: dir.appendingPathComponent("morph.png"))

        // Both player looks, light and dark.
        let art = NSImage(size: NSSize(width: 120, height: 120), flipped: false) { r in
            NSGradient(colors: [.systemPurple, .systemOrange])!.draw(in: r, angle: 45); return true
        }
        var info = NowPlayingInfo(bundleID: SpotifyMonitor.bundleID, title: "Portland",
                                  artist: "Drake, Quavo, Travis Scott", album: "More Life", isPlaying: true, duration: 237, elapsed: 151, elapsedAt: Date())
        info.artwork = art
        for (name, drake, dark) in [("player_normal_light", false, false), ("player_normal_dark", false, true),
                                    ("player_ovo", true, true), ("player_ovo_shimmer", true, true)] {
            let model = NowPlayingModel()
            var i = info
            model.preview(i, drake: drake)
            let view = PlayerView(model: model, previewShimmer: name.hasSuffix("shimmer") ? 0.35 : nil)
                .background(dark ? Color(white: 0.17) : Color(white: 0.93))
                .environment(\.colorScheme, dark ? .dark : .light)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage { write(img, to: dir.appendingPathComponent("\(name).png")) }
        }

        // Gold owl at a large size.
        let owl = ImageRenderer(content: OwlShape().fill(Owl.gold).frame(width: 300 * Owl.aspect, height: 300)
            .padding(20).background(Color.black))
        owl.scale = 2
        if let i = owl.nsImage { write(i, to: dir.appendingPathComponent("owl_gold.png")) }
    }

    static func write(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
        print("wrote \(url.path)")
    }
}
