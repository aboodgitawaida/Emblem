import AppKit

let args = CommandLine.arguments

// Debug helpers: `Emblem --selftest`, `Emblem --check-artists`, `Emblem --render-frames <dir>`, `Emblem --palette <image>…`.
if args.contains("--selftest") {
    exit(ArtistMatcher.selfTest() ? 0 : 1)
}
if args.contains("--check-artists") {
    // Lists every artist that loads, and explains any folder that doesn't.
    let (brands, problems) = ArtistLibrary.load()
    print("Built-in: \(ArtistLibrary.bundledFolder?.path ?? "not found")")
    print("Yours:    \(ArtistLibrary.userFolder.path)\n")
    for b in brands {
        let size = b.logo.size
        print("✓ \(b.id): \(b.names.joined(separator: ", ")) · \(b.logo.rawPaths.count) paths · logo \(Int(size.width))×\(Int(size.height)) · \(b.spotifyURI)")
    }
    for p in problems { print("✗ \(p)") }
    print(problems.isEmpty ? "\nAll \(brands.count) artists load." : "\n\(problems.count) folder(s) need fixing.")
    exit(problems.isEmpty ? 0 : 1)
}
if let i = args.firstIndex(of: "--palette"), i + 1 < args.count {
    // Prints the colour picked from an image, e.g. an album cover.
    for path in args[(i + 1)...] {
        guard let img = NSImage(contentsOfFile: path) else { print("\(path): can't read"); continue }
        if let c = ArtworkPalette.dominantColor(in: img) {
            let rgb = NSColor(hue: c.h, saturation: c.s, brightness: c.b, alpha: 1).usingColorSpace(.sRGB)!
            print(String(format: "%@: #%02X%02X%02X", (path as NSString).lastPathComponent,
                         Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255)))
        } else { print("\((path as NSString).lastPathComponent): black and white, silver palette") }
    }
    exit(0)
}
if let i = args.firstIndex(of: "--fit-logo"), i + 1 < args.count {
    // Crops an SVG's viewBox tight around its paths, as artist logos need.
    let url = URL(fileURLWithPath: args[i + 1])
    guard var svg = try? String(contentsOf: url, encoding: .utf8) else { print("can't read \(url.path)"); exit(1) }
    do {
        let (paths, _) = try ArtistLibrary.svgPaths(svg, folder: url.lastPathComponent)
        var box = CGRect.null
        for d in paths { box = box.union(SVGPath.parse(d).boundingRect) }
        let vb = String(format: "%g %g %g %g", box.minX, box.minY, box.width, box.height)
        svg = svg.replacingOccurrences(of: #"viewBox\s*=\s*"[^"]*""#, with: "viewBox=\"\(vb)\"", options: .regularExpression)
        try svg.write(to: url, atomically: true, encoding: .utf8)
        print("viewBox is now \(vb) (\(paths.count) paths)")
        exit(0)
    } catch { print("\(error)"); exit(1) }
}
if let i = args.firstIndex(of: "--render-covers"), i + 1 < args.count {
    // `--render-covers <dir> <brand-id>=<cover image>…`: the player for real album art.
    MainActor.assumeIsolated { DebugRender.covers(to: URL(fileURLWithPath: args[i + 1]), Array(args[(i + 2)...])) }
    exit(0)
}
if let i = args.firstIndex(of: "--render-frames"), i + 1 < args.count {
    MainActor.assumeIsolated { DebugRender.frames(to: URL(fileURLWithPath: args[i + 1])) }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
