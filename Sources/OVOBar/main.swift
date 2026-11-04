import AppKit

let args = CommandLine.arguments

// Debug helpers: `OVOBar --selftest`, `OVOBar --render-frames <dir>`.
if args.contains("--selftest") {
    exit(ArtistMatcher.selfTest() ? 0 : 1)
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
