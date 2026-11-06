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
        for brand in Brand.all {
            let strip = NSImage(size: NSSize(width: w * CGFloat(steps + 1), height: h))
            strip.lockFocus()
            NSColor.white.setFill(); NSRect(origin: .zero, size: strip.size).fill()
            for i in 0...steps {
                let img = StatusIconRenderer.image(progress: CGFloat(i) / CGFloat(steps), brand: brand)
                img.draw(in: NSRect(x: CGFloat(i) * w, y: 0, width: w, height: h))
            }
            strip.unlockFocus()
            write(strip, to: dir.appendingPathComponent(brand.id == "ovo" ? "morph.png" : "morph_\(brand.id).png"))
        }

        // The glint sweeping across the finished owl.
        let glint = NSImage(size: NSSize(width: w * CGFloat(steps + 1), height: h))
        glint.lockFocus()
        NSColor.white.setFill(); NSRect(origin: .zero, size: glint.size).fill()
        for i in 0...steps {
            let g = CGFloat(i) / CGFloat(steps)
            StatusIconRenderer.image(progress: 1, brand: Brand.named("ovo"), glint: g == 0 || g == 1 ? nil : g)
                .draw(in: NSRect(x: CGFloat(i) * w, y: 0, width: w, height: h))
        }
        glint.unlockFocus()
        write(glint, to: dir.appendingPathComponent("glint.png"))

        // The normal player (light and dark), and each brand's look.
        let art = NSImage(size: NSSize(width: 120, height: 120), flipped: false) { r in
            NSGradient(colors: [.systemPurple, .systemOrange])!.draw(in: r, angle: 45); return true
        }
        var info = NowPlayingInfo(bundleID: SpotifyMonitor.bundleID, title: "Portland",
                                  artist: "Drake, Quavo, Travis Scott", album: "More Life", isPlaying: true, duration: 237, elapsed: 151, elapsedAt: Date())
        info.artwork = art
        var looks: [(String, Brand?, Bool)] = [("player_normal_light", nil, false), ("player_normal_dark", nil, true)]
        for b in Brand.all { looks += [("player_\(b.id)", b, true), ("player_\(b.id)_shimmer", b, true)] }
        for (name, brand, dark) in looks {
            let model = NowPlayingModel()
            var i = info
            if brand?.id == "kanye" { (i.title, i.artist, i.album) = ("Stronger", "Kanye West", "Graduation") }
            if brand?.id == "cole" { (i.title, i.artist, i.album) = ("No Role Modelz", "J. Cole", "2014 Forest Hills Drive") }
            if brand?.id == "tyler" { (i.title, i.artist, i.album) = ("EARFQUAKE", "Tyler, The Creator", "IGOR") }
            if brand?.id == "travis" { (i.title, i.artist, i.album) = ("goosebumps", "Travis Scott", "Birds in the Trap Sing McKnight") }
            if brand?.id == "xo" { (i.title, i.artist, i.album) = ("Blinding Lights", "The Weeknd", "After Hours") }
            model.preview(i, brand: brand)
            let view = PlayerView(model: model, previewShimmer: name.hasSuffix("shimmer") ? 0.35 : nil)
                .background(dark ? Color(white: 0.17) : Color(white: 0.93))
                .environment(\.colorScheme, dark ? .dark : .light)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage { write(img, to: dir.appendingPathComponent("\(name).png")) }
        }

        // Each logo at a large size, in its brand's color.
        for b in Brand.all {
            let r = ImageRenderer(content: LogoMark(logo: b.logo, color: b.palette.accent)
                .frame(width: 300 * b.logo.aspect, height: 300).padding(20).background(b.palette.background))
            r.scale = 2
            if let i = r.nsImage { write(i, to: dir.appendingPathComponent("logo_\(b.id).png")) }
        }
    }

    /// The player with real album art, each as `<brand-id>=<image path>`, to check the art-derived colours.
    /// Add `|<title>|<artist>|<album>` to show a real song, e.g. `travis=a.jpg|SICKO MODE|Travis Scott|ASTROWORLD`.
    static func covers(to dir: URL, _ specs: [String]) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for spec in specs {
            let parts = spec.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { print("skip \(spec)"); continue }
            let fields = parts[1].components(separatedBy: "|")
            guard let brand = Brand.all.first(where: { $0.id == parts[0] }),
                  let art = NSImage(contentsOfFile: fields[0]) else { print("skip \(spec)"); continue }
            let name = ((fields[0] as NSString).lastPathComponent as NSString).deletingPathExtension
            let title = fields.count > 1 ? fields[1] : name
            let artist = fields.count > 2 ? fields[2] : parts[0]
            let album = fields.count > 3 ? fields[3] : ""
            var info = NowPlayingInfo(bundleID: SpotifyMonitor.bundleID, title: title, artist: artist, album: album,
                                      hasAlbum: !album.isEmpty, isPlaying: true, duration: 237, elapsed: 151, elapsedAt: Date())
            info.artwork = art
            let model = NowPlayingModel()
            model.preview(info, brand: brand)
            let r = ImageRenderer(content: PlayerView(model: model).environment(\.colorScheme, .dark))
            r.scale = 2
            if let img = r.nsImage { write(img, to: dir.appendingPathComponent("cover_\(name).png")) }
        }
    }

    static func write(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
        print("wrote \(url.path)")
    }
}
