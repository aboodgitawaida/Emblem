import AppKit
import ApplicationServices

// Compares Emblem's player with the system Now Playing player, element by element.
//
//   swiftc -O tools/compare.swift -o tools/compare && tools/compare [out-dir]
//
// For each player it opens the panel, reads every element through Accessibility (frame relative to
// the 308×140 card, text, font, colour), screenshots the card at rest, while hovering the progress
// bar and while hovering the play button, then closes it. It prints every difference and writes
// the screenshots plus a per-state pixel diff to out-dir (default: reference/compare).
// Needs Accessibility and Screen Recording for the terminal that runs it. Both players show the
// same track, so run it while Spotify plays something (a non-artist track compares colours too).

// MARK: Accessibility helpers

func attr(_ e: AXUIElement, _ n: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil
}
func str(_ e: AXUIElement, _ n: String) -> String? { attr(e, n) as? String }
func kids(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func frame(_ e: AXUIElement) -> CGRect? {
    guard let v = attr(e, "AXFrame") else { return nil }
    var r = CGRect.zero
    AXValueGetValue(v as! AXValue, .cgRect, &r)
    return r
}
func windows(_ pid: pid_t) -> [AXUIElement] {
    (attr(AXUIElementCreateApplication(pid), kAXWindowsAttribute) as? [AXUIElement]) ?? []
}
func app(_ bundleID: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
}

/// Font and colour of the first characters of a text element.
func textStyle(_ e: AXUIElement) -> (font: String, color: [Double])? {
    guard let text = attr(e, kAXValueAttribute) as? String, !text.isEmpty else { return nil }
    var range = CFRange(location: 0, length: 1)
    guard let rv = AXValueCreate(.cfRange, &range) else { return nil }
    var out: AnyObject?
    guard AXUIElementCopyParameterizedAttributeValue(e, kAXAttributedStringForRangeParameterizedAttribute as CFString, rv, &out) == .success,
          let s = out as? NSAttributedString, s.length > 0 else { return nil }
    let a = s.attributes(at: 0, effectiveRange: nil)
    var font = "?"
    if let f = a[NSAttributedString.Key(kAXFontTextAttribute.takeUnretainedValue() as String)] as? [String: Any] {
        font = "\(f["AXFontName"] ?? "?") \(f["AXFontSize"] ?? "?")"
    }
    var color: [Double] = []
    if let c = a[NSAttributedString.Key(kAXForegroundColorTextAttribute.takeUnretainedValue() as String)] {
        color = ((c as! CGColor).components ?? []).map(Double.init)
    }
    return (font, color)
}

// MARK: Model

struct Element {
    let key: String        // what it is, e.g. "button previous", "text title"
    let frame: CGRect      // relative to the card's top-left corner
    let text: String?
    let font: String?
    let color: [Double]
}

struct Player {
    let name: String
    let card: CGRect       // screen points, top-left origin
    let elements: [Element]
}

/// Accessibility can report a scrolling line twice (the visible copy and the copy that follows it).
/// Keeps the first, and names texts by their order: title, artist line, elapsed, remaining.
func collect(in root: AXUIElement, card: CGRect) -> [Element] {
    var raw: [(String, AXUIElement, CGRect)] = []
    func walk(_ e: AXUIElement) {
        let role = str(e, kAXRoleAttribute) ?? "?"
        // By its top-left corner: a scrolling line is reported at its full width, past the card's edge.
        if let f = frame(e), card.insetBy(dx: -1, dy: -1).contains(CGPoint(x: f.minX, y: f.minY)),
           ["AXButton", "AXStaticText", "AXImage", "AXSlider"].contains(role) {
            raw.append((role, e, f))
        }
        for c in kids(e) { walk(c) }
    }
    walk(root)
    var seenText = Set<String>()
    var texts: [(AXUIElement, CGRect)] = []
    var out: [Element] = []
    for (role, e, f) in raw {
        let rel = f.offsetBy(dx: -card.minX, dy: -card.minY)
        switch role {
        case "AXButton":
            let id = str(e, kAXIdentifierAttribute) ?? str(e, kAXDescriptionAttribute) ?? "?"
            out.append(Element(key: "button \(id)", frame: rel, text: str(e, kAXDescriptionAttribute), font: nil, color: []))
        case "AXImage":
            out.append(Element(key: "artwork", frame: rel, text: nil, font: nil, color: []))
        case "AXSlider":
            out.append(Element(key: "progress bar", frame: rel, text: nil, font: nil, color: []))
        default:
            let v = (attr(e, kAXValueAttribute) as? String) ?? ""
            if seenText.contains(v) { continue }
            seenText.insert(v)
            texts.append((e, rel))
        }
    }
    // The system player reports title and artist line as one element; split by position instead.
    let names = ["title", "artist line", "elapsed", "remaining"]
    for (i, (e, rel)) in texts.sorted(by: { ($0.1.minY, $0.1.minX) < ($1.1.minY, $1.1.minX) }).enumerated() {
        let style = textStyle(e)
        out.append(Element(key: "text " + (i < names.count ? names[i] : "\(i)"), frame: rel,
                           text: attr(e, kAXValueAttribute) as? String, font: style?.font, color: style?.color ?? []))
    }
    return out
}

// MARK: Input and capture

func click(_ p: CGPoint) {
    for t in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(60_000)
    }
}
func moveMouse(_ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
func shoot(_ r: CGRect, to path: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    p.arguments = ["-x", "-R", "\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))", path]
    try? p.run(); p.waitUntilExit()
}

/// The menu bar item of an app whose description is "Now Playing", found by hit-testing across the
/// menu bar (the system's items aren't reachable from their app's element tree).
func nowPlayingItem(_ bundleID: String) -> AXUIElement? {
    let system = AXUIElementCreateSystemWide()
    let width = Float(NSScreen.screens.first?.frame.width ?? 1440)
    for x in stride(from: Float(300), to: width, by: 4) {
        var e: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, x, 12, &e) == .success, let e else { continue }
        var pid: pid_t = 0
        AXUIElementGetPid(e, &pid)
        if NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == bundleID,
           (str(e, kAXDescriptionAttribute) ?? "") == "Now Playing" { return e }
    }
    return nil
}

let cardSize = CGSize(width: 308, height: 140)
let states: [(name: String, point: (CGRect) -> CGPoint?)] = [
    ("rest", { _ in nil }),
    ("hover-bar", { card in CGPoint(x: card.minX + 140 + 77, y: card.minY + 107) }),
    ("hover-play", { card in CGPoint(x: card.minX + 140 + 77, y: card.minY + 96.5 - 19) }),
]

func capture(_ name: String, card: CGRect, outDir: String, away: CGPoint) {
    for s in states {
        moveMouse(s.point(card) ?? away)
        usleep(700_000)
        shoot(card, to: "\(outDir)/\(name)-\(s.name).png")
    }
    moveMouse(away)
}

// MARK: The two players

/// Opens the system player from its menu bar item and reads it.
func readSystem(outDir: String, away: CGPoint) -> Player? {
    guard let item = nowPlayingItem("com.apple.MenuBarAgent") else { print("system Now Playing item not in the menu bar"); return nil }
    AXUIElementPerformAction(item, kAXPressAction as CFString)
    defer { AXUIElementPerformAction(item, kAXPressAction as CFString); usleep(500_000) }
    usleep(1_200_000)
    guard let cc = app("com.apple.controlcenter") else { return nil }
    for w in windows(cc.processIdentifier) {
        var card: CGRect?
        func find(_ e: AXUIElement) {
            if card == nil, let f = frame(e), abs(f.width - cardSize.width) < 1, abs(f.height - cardSize.height) < 1 { card = f }
            for c in kids(e) { find(c) }
        }
        find(w)
        guard let card else { continue }
        let elements = collect(in: w, card: card)
        capture("system", card: card, outDir: outDir, away: away)
        return Player(name: "system", card: card, elements: elements)
    }
    print("system player didn't open"); return nil
}

/// Opens Emblem's player by clicking its menu bar icon and reads it.
func readEmblem(outDir: String, away: CGPoint) -> Player? {
    guard let a = app("io.github.aboodgitawaida.Emblem") else { print("Emblem isn't running"); return nil }
    guard let item = nowPlayingItem("io.github.aboodgitawaida.Emblem"), let f = frame(item) else { print("Emblem's icon not found"); return nil }
    let icon = CGPoint(x: f.midX, y: f.midY)
    click(icon)
    defer { click(icon); usleep(500_000) }
    usleep(1_200_000)
    // The panel is the window with the card inside a shadow margin (40pt sides, 20pt top).
    for w in windows(a.processIdentifier) {
        guard let wf = frame(w), wf.width > 300 else { continue }
        let card = CGRect(x: wf.minX + 40, y: wf.minY + 20, width: cardSize.width, height: cardSize.height)
        let elements = collect(in: w, card: card)
        capture("emblem", card: card, outDir: outDir, away: away)
        return Player(name: "emblem", card: card, elements: elements)
    }
    print("Emblem's player didn't open"); return nil
}

// MARK: Report

func fmt(_ r: CGRect) -> String { String(format: "x %.1f  y %.1f  w %.1f  h %.1f", r.minX, r.minY, r.width, r.height) }
func fmtColor(_ c: [Double]) -> String { c.map { String(format: "%.3f", $0) }.joined(separator: ",") }

func report(_ s: Player, _ e: Player) -> Int {
    var problems = 0
    let keys = (s.elements.map(\.key) + e.elements.map(\.key)).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    // The system's first text holds title and artist line together, so text positions are compared
    // on their left edge and top only when both sides report them separately.
    for k in keys {
        let a = s.elements.first { $0.key == k }, b = e.elements.first { $0.key == k }
        guard let a, let b else {
            print("• \(k): only in \(a == nil ? "Emblem" : "the system player")"); problems += 1; continue
        }
        var notes: [String] = []
        let d = [b.frame.minX - a.frame.minX, b.frame.minY - a.frame.minY, b.frame.width - a.frame.width, b.frame.height - a.frame.height]
        let combinedText = k == "text title" && (a.text ?? "").contains(" – ")
        if !combinedText, d.contains(where: { abs($0) > 0.25 }) {
            notes.append("frame  system \(fmt(a.frame))  emblem \(fmt(b.frame))")
        }
        if let fa = a.font, let fb = b.font, fa != fb, !combinedText { notes.append("font  system \(fa)  emblem \(fb)") }
        if !a.color.isEmpty, !b.color.isEmpty, zip(a.color, b.color).contains(where: { abs($0 - $1) > 0.01 }), !combinedText {
            notes.append("colour  system \(fmtColor(a.color))  emblem \(fmtColor(b.color))")
        }
        if k.hasPrefix("button"), let ta = a.text, let tb = b.text, ta != tb { notes.append("label  system \"\(ta)\"  emblem \"\(tb)\"") }
        if notes.isEmpty { print("✓ \(k)") } else { problems += 1; print("• \(k)"); notes.forEach { print("    \($0)") } }
    }
    return problems
}

/// Share of pixels that differ noticeably between the two screenshots of one state.
/// Decodes a PNG into plain sRGB RGBA bytes.
func rgba(_ path: String) -> (w: Int, h: Int, px: [UInt8])? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ok = px.withUnsafeMutableBytes { buf -> Bool in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    return ok ? (w, h, px) : nil
}

/// Share of pixels that differ noticeably between two screenshots of one state; writes a picture of
/// where (red = different, dimmed = same).
func pixelDiff(_ a: String, _ b: String, out: String) -> Double? {
    guard let A = rgba(a), let B = rgba(b), A.w == B.w, A.h == B.h else { return nil }
    var o = [UInt8](repeating: 255, count: A.px.count)
    var differing = 0
    for i in stride(from: 0, to: A.px.count, by: 4) {
        let d = abs(Int(A.px[i]) - Int(B.px[i])) + abs(Int(A.px[i + 1]) - Int(B.px[i + 1])) + abs(Int(A.px[i + 2]) - Int(B.px[i + 2]))
        if d > 30 { differing += 1; o[i] = 255; o[i + 1] = 40; o[i + 2] = 40 }
        else { let g = UInt8(Int(A.px[i]) * 35 / 100); o[i] = g; o[i + 1] = g; o[i + 2] = g }
    }
    o.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: A.w, height: A.h, bitsPerComponent: 8, bytesPerRow: A.w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let img = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
    }
    return Double(differing) / Double(A.w * A.h)
}

// MARK: Main

guard AXIsProcessTrusted() else { print("Turn on Accessibility for this terminal first."); exit(2) }
let outDir = CommandLine.arguments.dropFirst().first ?? "reference/compare"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let away = CGPoint(x: (NSScreen.main?.frame.midX ?? 600), y: (NSScreen.main?.frame.midY ?? 400))
moveMouse(away)

guard let system = readSystem(outDir: outDir, away: away), let emblem = readEmblem(outDir: outDir, away: away) else { exit(1) }
print("Elements (relative to the card's top-left, points):")
let problems = report(system, emblem)
print("\nScreenshots (red = pixels that differ):")
for s in states {
    let a = "\(outDir)/system-\(s.name).png", b = "\(outDir)/emblem-\(s.name).png"
    if let share = pixelDiff(a, b, out: "\(outDir)/diff-\(s.name).png") {
        print(String(format: "  %-11@ %.1f%% of pixels differ  → diff-%@.png", s.name as NSString, share * 100, s.name))
    }
}
print(problems == 0 ? "\nNo element differences." : "\n\(problems) element difference(s).")
