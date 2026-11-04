import SwiftUI

/// The OVO owl, cropped to its bounding box and normalized to a unit-height coordinate space.
enum Owl {
    static let gold = Color(red: 0xBF / 255, green: 0xA6 / 255, blue: 0x6E / 255)
    static let goldNS = NSColor(srgbRed: 0xBF / 255, green: 0xA6 / 255, blue: 0x6E / 255, alpha: 1)

    /// width / height of the owl's bounding box.
    static let aspect = OwlPathData.bounds.width / OwlPathData.bounds.height

    /// Each SVG <path>, translated so the owl's bounding box starts at (0,0).
    static let rawPaths: [Path] = OwlPathData.paths.map { d in
        SVGPath.parse(d).applying(
            CGAffineTransform(translationX: -OwlPathData.bounds.x, y: -OwlPathData.bounds.y))
    }

    /// The owl's paths scaled to fit `rect` (aspect preserved, centered). SVG y-down.
    static func paths(in rect: CGRect) -> [Path] {
        let b = OwlPathData.bounds
        let scale = min(rect.width / b.width, rect.height / b.height)
        let w = b.width * scale, h = b.height * scale
        let t = CGAffineTransform(translationX: rect.midX - w / 2, y: rect.midY - h / 2)
            .scaledBy(x: scale, y: scale)
        return rawPaths.map { $0.applying(t) }
    }
}

/// SwiftUI shape of the owl (used for the gold mark in the OVO player).
struct OwlShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for sub in Owl.paths(in: rect) { p.addPath(sub) }
        return p
    }
}
