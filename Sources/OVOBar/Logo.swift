import SwiftUI

/// A logo from SVG path data, cropped to its bounding box.
struct Logo {
    /// Each SVG path, translated so the bounding box starts at (0,0).
    let rawPaths: [Path]
    let size: CGSize
    /// The bear is a solid head with holes cut in, so it fills even-odd.
    /// The owl's pieces don't overlap, so non-zero is fine there.
    let evenOdd: Bool
    /// Solid shapes, unlike line art, can't be revealed by tracing their outlines alone,
    /// so the morph traces the outline and then fades the fill in.
    let solid: Bool

    init(paths: [String], bounds b: (x: Double, y: Double, width: Double, height: Double),
         evenOdd: Bool, solid: Bool = false) {
        rawPaths = paths.map { SVGPath.parse($0).applying(CGAffineTransform(translationX: -b.x, y: -b.y)) }
        size = CGSize(width: b.width, height: b.height)
        self.evenOdd = evenOdd
        self.solid = solid
    }

    /// width / height of the bounding box.
    var aspect: CGFloat { size.width / size.height }

    /// The paths scaled to fit `rect` (aspect preserved, centered). SVG y-down.
    func paths(in rect: CGRect) -> [Path] {
        let scale = min(rect.width / size.width, rect.height / size.height)
        let w = size.width * scale, h = size.height * scale
        let t = CGAffineTransform(translationX: rect.midX - w / 2, y: rect.midY - h / 2).scaledBy(x: scale, y: scale)
        return rawPaths.map { $0.applying(t) }
    }

    static let owl = Logo(paths: OwlPathData.paths, bounds: OwlPathData.bounds, evenOdd: false)
    static let bear = Logo(paths: BearPathData.paths, bounds: BearPathData.bounds, evenOdd: true, solid: true)
    static let xo = Logo(paths: XOPathData.paths, bounds: XOPathData.bounds, evenOdd: true)
    static let golfFlower = Logo(paths: GolfFlowerPathData.paths, bounds: GolfFlowerPathData.bounds, evenOdd: true, solid: true)
    static let cactusJack = Logo(paths: CactusJackPathData.paths, bounds: CactusJackPathData.bounds, evenOdd: true)
}

/// A logo filled with one color, fitted to its frame.
struct LogoMark: View {
    let logo: Logo
    let color: Color
    var weight: CGFloat = 0   // extra line weight (pt)
    var body: some View {
        LogoShape(logo: logo).fill(color, style: FillStyle(eoFill: logo.evenOdd))
            .overlay { if weight > 0 { LogoShape(logo: logo).stroke(color, style: StrokeStyle(lineWidth: weight, lineJoin: .round)) } }
    }
}

struct LogoShape: Shape {
    let logo: Logo
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for sub in logo.paths(in: rect) { p.addPath(sub) }
        return p
    }
}
