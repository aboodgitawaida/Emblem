import AppKit
import ApplicationServices
// axat scan            – lists menu bar elements found across the top of the screen
// axat press X Y       – presses the element at (X, Y)
// axat dump X Y        – dumps the window containing (X, Y)
func attr(_ e: AXUIElement, _ n: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil }
func str(_ e: AXUIElement, _ n: String) -> String? { attr(e, n) as? String }
func frame(_ e: AXUIElement) -> CGRect? {
    var p = CGPoint.zero, s = CGSize.zero
    guard let pv = attr(e, kAXPositionAttribute), let sv = attr(e, kAXSizeAttribute) else { return nil }
    AXValueGetValue(pv as! AXValue, .cgPoint, &p); AXValueGetValue(sv as! AXValue, .cgSize, &s); return CGRect(origin: p, size: s)
}
func at(_ x: Float, _ y: Float) -> AXUIElement? { var e: AXUIElement?; return AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), x, y, &e) == .success ? e : nil }
func pidOf(_ e: AXUIElement) -> pid_t { var p: pid_t = 0; AXUIElementGetPid(e, &p); return p }
func desc(_ e: AXUIElement) -> String {
    let f = frame(e).map { String(format: "[x=%.1f y=%.1f w=%.1f h=%.1f]", $0.minX, $0.minY, $0.width, $0.height) } ?? ""
    let app = NSRunningApplication(processIdentifier: pidOf(e))?.bundleIdentifier ?? "?"
    return "\(str(e, kAXRoleAttribute) ?? "?")/\(str(e, kAXSubroleAttribute) ?? "-") id=\(str(e, kAXIdentifierAttribute) ?? "") title=\(str(e, kAXTitleAttribute) ?? "") desc=\(str(e, kAXDescriptionAttribute) ?? "") \(f) app=\(app)"
}
let a = CommandLine.arguments
switch a[1] {
case "scan":
    var seen = Set<String>()
    let w = Float(NSScreen.main!.frame.width)
    for x in stride(from: Float(700), to: w, by: 4) {
        if let e = at(x, 16) { let d = desc(e); if seen.insert(d).inserted { print(d) } }
    }
case "press":
    if let e = at(Float(a[2])!, Float(a[3])!) { print("press", desc(e), AXUIElementPerformAction(e, kAXPressAction as CFString).rawValue) }
case "agent":
    // windows of every process that might host the module
    for bid in ["com.apple.MenuBarAgent", "com.apple.controlcenter"] {
        for r in NSRunningApplication.runningApplications(withBundleIdentifier: bid) {
            let app = AXUIElementCreateApplication(r.processIdentifier)
            let wins = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
            let kids = (attr(app, kAXChildrenAttribute) as? [AXUIElement]) ?? []
            print("\(bid) pid=\(r.processIdentifier) windows=\(wins.count) children=\(kids.count)")
            for w in wins + kids { print("  " + desc(w)) }
        }
    }
case "dump", "ccdump":
    var e: AXUIElement? = nil
    if a[1] == "ccdump" {
        let r = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first!
        e = ((attr(AXUIElementCreateApplication(r.processIdentifier), kAXWindowsAttribute) as? [AXUIElement]) ?? []).first
    } else { e = at(Float(a[2])!, Float(a[3])!) }
    // walk up to the window
    while let cur = e, str(cur, kAXRoleAttribute) != kAXWindowAttribute as String && str(cur, kAXRoleAttribute) != "AXWindow" {
        guard let parent = attr(cur, kAXParentAttribute) else { break }
        e = (parent as! AXUIElement)
    }
    guard let win = e else { print("nothing at point"); exit(1) }
    let origin = frame(win)?.origin ?? .zero
    print("WINDOW " + desc(win))
    func font(_ e: AXUIElement) -> String {
        guard let text = (attr(e, kAXValueAttribute) as? String) ?? str(e, kAXTitleAttribute) ?? str(e, kAXDescriptionAttribute), !text.isEmpty else { return "" }
        var r = CFRange(location: 0, length: min(2, (text as NSString).length))
        var out: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(e, kAXAttributedStringForRangeParameterizedAttribute as CFString, AXValueCreate(.cfRange, &r)!, &out) == .success,
              let at = out as? NSAttributedString, at.length > 0 else { return "" }
        let d = at.attributes(at: 0, effectiveRange: nil)
        var parts: [String] = []
        if let f = d[NSAttributedString.Key(kAXFontTextAttribute.takeUnretainedValue() as String)] as? [String: Any] {
            parts.append("FONT=\(f["AXFontName"] ?? "?")/\(f["AXFontSize"] ?? "?")")
        }
        if let c = d[NSAttributedString.Key(kAXForegroundColorTextAttribute.takeUnretainedValue() as String)] {
            parts.append("COLOR=" + ((c as! CGColor).components ?? []).map { String(format: "%.3f", $0) }.joined(separator: ","))
        }
        return parts.joined(separator: " ")
    }
    func walk(_ e: AXUIElement, _ depth: Int) {
        var line = String(repeating: "  ", count: depth) + "\(str(e, kAXRoleAttribute) ?? "?")"
        if let sr = str(e, kAXSubroleAttribute) { line += "/\(sr)" }
        if let id = str(e, kAXIdentifierAttribute), !id.isEmpty { line += " id=\(id)" }
        if let f = frame(e) { line += String(format: " [x=%.1f y=%.1f w=%.1f h=%.1f]", f.minX - origin.x, f.minY - origin.y, f.width, f.height) }
        for k in [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute] {
            if let v = attr(e, k) { let t = (v as? String) ?? "\(v)"; if !t.isEmpty && t.count < 80 { line += " \(k)=\"\(t)\"" } }
        }
        let f = font(e); if !f.isEmpty { line += " " + f }
        print(line)
        for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { walk(c, depth + 1) }
    }
    walk(win, 0)
case "track":
    // Samples the frames of an app's text elements over time (seconds = a[2], bundle id = a[3]).
    let r = NSRunningApplication.runningApplications(withBundleIdentifier: a.count > 3 ? a[3] : "com.apple.controlcenter").first!
    let app = AXUIElementCreateApplication(r.processIdentifier)
    func texts(_ e: AXUIElement, _ out: inout [AXUIElement]) {
        if str(e, kAXRoleAttribute) == "AXStaticText" { out.append(e) }
        for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { texts(c, &out) }
    }
    let start = Date()
    let dur = Double(a[2]) ?? 12
    while Date().timeIntervalSince(start) < dur {
        var els: [AXUIElement] = []
        for w in (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { texts(w, &els) }
        let parts = els.compactMap { e -> String? in
            guard let f = frame(e) else { return nil }
            let v = ((attr(e, kAXValueAttribute) as? String) ?? "").prefix(12)
            return String(format: "%@@x%.1f,y%.1f,w%.1f", String(v), f.minX, f.minY, f.width)
        }
        print(String(format: "%.2f ", Date().timeIntervalSince(start)) + parts.joined(separator: " | "))
        usleep(50_000)
    }
default: break
}
