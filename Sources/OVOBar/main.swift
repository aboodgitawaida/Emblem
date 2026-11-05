import AppKit

let args = CommandLine.arguments

// Debug helpers: `OVOBar --selftest`, `OVOBar --render-frames <dir>`, `OVOBar --palette <image>…`.
if args.contains("--selftest") {
    exit(ArtistMatcher.selfTest() ? 0 : 1)
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
