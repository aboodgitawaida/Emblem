import AppKit
import ApplicationServices

// Dumps the on-screen layout (role, frame, text, font) of a player panel via Accessibility.
//   axdump apple   – opens the system Now Playing module from the menu bar and dumps it
//   axdump emblem  – dumps Emblem's panel (open it first)

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
}
func str(_ e: AXUIElement, _ name: String) -> String? { attr(e, name) as? String }
func children(_ e: AXUIElement) -> [AXUIElement] { (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] }
func frame(_ e: AXUIElement) -> CGRect? {
    var p = CGPoint.zero, s = CGSize.zero
    guard let pv = attr(e, kAXPositionAttribute), let sv = attr(e, kAXSizeAttribute) else { return nil }
    AXValueGetValue(pv as! AXValue, .cgPoint, &p); AXValueGetValue(sv as! AXValue, .cgSize, &s)
    return CGRect(origin: p, size: s)
}
func font(_ e: AXUIElement) -> String? {
    guard let text = (attr(e, kAXValueAttribute) as? String) ?? str(e, kAXTitleAttribute) ?? str(e, kAXDescriptionAttribute),
          !text.isEmpty else { return nil }
    var range = CFRange(location: 0, length: min(3, (text as NSString).length))
    guard let rv = AXValueCreate(.cfRange, &range) else { return nil }
    var out: AnyObject?
    guard AXUIElementCopyParameterizedAttributeValue(e, kAXAttributedStringForRangeParameterizedAttribute as CFString, rv, &out) == .success,
          let attributed = out as? NSAttributedString, attributed.length > 0 else { return nil }
    let a = attributed.attributes(at: 0, effectiveRange: nil)
    var parts: [String] = []
    if let f = a[NSAttributedString.Key(kAXFontTextAttribute.takeUnretainedValue() as String)] as? [String: Any] {
        parts.append("font=\(f["AXFontName"] ?? "?") \(f["AXFontSize"] ?? "?")pt")
    }
    if let c = a[NSAttributedString.Key(kAXForegroundColorTextAttribute.takeUnretainedValue() as String)] {
        let cg = c as! CGColor
        parts.append("color=" + (cg.components ?? []).map { String(format: "%.3f", $0) }.joined(separator: ","))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
}

var origin = CGPoint.zero
func dump(_ e: AXUIElement, depth: Int = 0) {
    let role = str(e, kAXRoleAttribute) ?? "?"
    var line = String(repeating: "  ", count: depth) + role
    if let sub = str(e, kAXSubroleAttribute) { line += "/\(sub)" }
    if let id = str(e, kAXIdentifierAttribute), !id.isEmpty { line += " id=\(id)" }
    if let f = frame(e) {
        line += String(format: " [x=%.1f y=%.1f w=%.1f h=%.1f]", f.minX - origin.x, f.minY - origin.y, f.width, f.height)
    }
    for k in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute] {
        if let v = attr(e, k) {
            let s = (v as? String) ?? "\(v)"
            if !s.isEmpty && s.count < 80 { line += " \(k.replacingOccurrences(of: "AX", with: "").lowercased())=\"\(s)\"" }
        }
    }
    if let f = font(e) { line += " " + f }
    print(line)
    for c in children(e) { dump(c, depth: depth + 1) }
}

func windows(of pid: pid_t) -> [AXUIElement] {
    (attr(AXUIElementCreateApplication(pid), kAXWindowsAttribute) as? [AXUIElement]) ?? []
}

let target = CommandLine.arguments.dropFirst().first ?? "apple"
// Writes to reference/ in the current directory, so run it from the repo root.
let outPath = (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent("reference/ax-\(target).txt")
try? FileManager.default.createDirectory(atPath: (outPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
FileManager.default.createFile(atPath: outPath, contents: nil)
let outHandle = FileHandle(forWritingAtPath: outPath)!
func print(_ s: String) { outHandle.write((s + "\n").data(using: .utf8)!) }
let promptOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
guard AXIsProcessTrustedWithOptions(promptOpts) else {
    print("NOT TRUSTED: enable AXDump in System Settings → Privacy & Security → Accessibility"); exit(2)
}
if target == "explore" {
    for bid in ["com.apple.controlcenter", "com.apple.systemuiserver"] {
        guard let r = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first else { print("\(bid): not running"); continue }
        let app = AXUIElementCreateApplication(r.processIdentifier)
        var names: CFArray?
        AXUIElementCopyAttributeNames(app, &names)
        print("\(bid) pid=\(r.processIdentifier) attrs=\((names as? [String]) ?? [])")
        for a in ["AXExtrasMenuBar", "AXMenuBar", kAXChildrenAttribute, kAXWindowsAttribute] {
            if let v = attr(app, a) {
                let items: [AXUIElement] = (v as? [AXUIElement]) ?? [v as! AXUIElement]
                print(" \(a): \(items.count)")
                for i in items { dump(i, depth: 2) }
            } else { print(" \(a): none") }
        }
    }
    exit(0)
}
if target == "apple" {
    guard let cc = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else {
        print("Control Center not running"); exit(1)
    }
    let app = AXUIElementCreateApplication(cc.processIdentifier)
    let extras = (attr(app, "AXExtrasMenuBar")).map { children($0 as! AXUIElement) } ?? []
    print("menu bar extras:")
    var nowPlaying: AXUIElement?
    for x in extras {
        let id = str(x, kAXIdentifierAttribute) ?? "", d = str(x, kAXDescriptionAttribute) ?? ""
        let f = frame(x).map { String(format: "[x=%.1f y=%.1f w=%.1f h=%.1f]", $0.minX, $0.minY, $0.width, $0.height) } ?? ""
        print("  id=\(id) desc=\(d) \(f)")
        if id.lowercased().contains("nowplaying") || d.lowercased().contains("now playing") { nowPlaying = x }
    }
    guard let np = nowPlaying else { print("Now Playing item not found"); exit(1) }
    let before = Set(windows(of: cc.processIdentifier).map { CFHash($0) })
    AXUIElementPerformAction(np, kAXPressAction as CFString)
    Thread.sleep(forTimeInterval: 1.2)
    let wins = windows(of: cc.processIdentifier)
    print("\nwindows after press: \(wins.count) (before \(before.count))")
    for w in wins {
        if let f = frame(w) { origin = f.origin; print(String(format: "WINDOW at screen x=%.1f y=%.1f w=%.1f h=%.1f", f.minX, f.minY, f.width, f.height)) }
        dump(w)
    }
    AXUIElementPerformAction(np, kAXPressAction as CFString)   // close it again
} else {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "io.github.aboodgitawaida.Emblem").first else {
        print("Emblem not running"); exit(1)
    }
    for w in windows(of: app.processIdentifier) {
        if let f = frame(w) { origin = f.origin; print(String(format: "WINDOW at screen x=%.1f y=%.1f w=%.1f h=%.1f", f.minX, f.minY, f.width, f.height)) }
        dump(w)
    }
}
