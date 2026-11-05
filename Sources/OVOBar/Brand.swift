import SwiftUI

/// An artist the app dresses up for: who counts, the menu bar logo, and the player's colors.
struct Brand: Equatable {
    let id: String
    /// Whole credit names, matched case-insensitively ("Drake" counts, "Drake Bell" doesn't).
    let names: [String]
    let spotifyURI: String
    let logo: Logo
    /// Menu bar logo height and the extra outline stroke on `weightedPaths` (pt).
    let iconHeight: CGFloat
    let iconWeight: CGFloat
    let weightedPaths: [Int]
    /// The small logo top-right of the player, where the level meter normally sits.
    let markSize: CGSize
    let palette: Palette
    /// Extra line weight for the player's small logo (pt), for thin line drawings.
    var markWeight: CGFloat = 0
    /// Extra menu bar stroke for single paths (pt), on top of `iconWeight`, e.g. a lighter touch on a face.
    var pathWeights: [Int: CGFloat] = [:]

    struct Palette {
        let accent: Color        // secondary text, controls, progress, logo
        let highlight: Color     // centre of the shimmer band
        let knob: Color
        let background: Color
        let ambient: Color       // soft glow from the panel's top corner
    }

    static func == (a: Brand, b: Brand) -> Bool { a.id == b.id }

    func matches(name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.contains { $0.caseInsensitiveCompare(n) == .orderedSame }
    }

    static let ovoGold = Color(red: 0xBF / 255, green: 0xA6 / 255, blue: 0x6E / 255)

    /// Drake: black, OVO gold and the owl.
    static let ovo = Brand(
        id: "ovo", names: ["Drake"], spotifyURI: "spotify:artist:3TVXtAsR1Inumwj472S9r4",
        // As big as the 18pt icon allows, with a bolder body outline: at a glance the owl is recognised by
        // its silhouette (ear tufts, wing, perch); its eyes are only a few pixels across at this size.
        // The face (eye frames and beak, path 2) gets just 0.15pt so it doesn't fade to grey; more fills it in.
        // 17.2pt plus the 0.65pt outline fills the 18pt icon without clipping the ear tufts or perch.
        logo: .owl, iconHeight: 17.2, iconWeight: 0.65,
        weightedPaths: [OwlPathData.paths.count - 1],
        markSize: CGSize(width: 10, height: 12.5),
        palette: Palette(accent: ovoGold,
                         highlight: Color(red: 1, green: 0.95, blue: 0.82),
                         knob: Color(red: 0.93, green: 0.86, blue: 0.68),
                         background: Color(white: 0.035),
                         ambient: ovoGold.opacity(0.10)),
        pathWeights: [2: 0.15])

    /// Kanye: the College Dropout bear, maroon and gold.
    static let kanye = Brand(
        id: "kanye", names: ["Kanye West", "Kanye", "Ye"], spotifyURI: "spotify:artist:5K4W6rqBFWDnAN6FQUkS6x",
        // Solid like the original logo: an outline version was too faint to recognise in the menu bar.
        // 17pt tall (17.5 wide) fills the 18pt canvas a little more than the owl, so the face reads.
        logo: .bear, iconHeight: 17, iconWeight: 0, weightedPaths: [],
        markSize: CGSize(width: 12.5, height: 12),
        palette: Palette(accent: Color(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255),
                         highlight: Color(red: 1, green: 0.92, blue: 0.74),
                         knob: Color(red: 0.96, green: 0.86, blue: 0.62),
                         background: Color(red: 0.075, green: 0.025, blue: 0.03),
                         ambient: Color(red: 0.62, green: 0.12, blue: 0.18).opacity(0.28)))

    /// The Weeknd: the XO brush logo, black and After Hours red.
    static let xo = Brand(
        id: "xo", names: ["The Weeknd", "Weeknd"], spotifyURI: "spotify:artist:1Xyo4u8uXC1ZmMpatF05PJ",
        // Brush strokes come out ~1pt at this size; thickening them all by 0.4pt matches the owl's weight,
        // since a thin bear outline proved too faint next to the system icons.
        logo: .xo, iconHeight: 17, iconWeight: 0.4, weightedPaths: Array(XOPathData.paths.indices),
        markSize: CGSize(width: 12, height: 12.5),
        palette: Palette(accent: Color(red: 0xE2 / 255, green: 0x32 / 255, blue: 0x3C / 255),
                         highlight: Color(red: 1, green: 0.84, blue: 0.84),
                         knob: Color(red: 0.98, green: 0.88, blue: 0.88),
                         background: Color(white: 0.03),
                         ambient: Color(red: 0.89, green: 0.12, blue: 0.16).opacity(0.16)))

    /// Travis Scott: the Cactus Jack face, in the gold of the ASTROWORLD head.
    static let travis = Brand(
        id: "travis", names: ["Travis Scott"], spotifyURI: "spotify:artist:0Y5tJX1MQlPlqiwlOH1tJY",
        // A line drawing that's wider than tall, so the 18pt canvas width limits it to 16pt tall.
        // Its pen lines are thin at this size; 0.5pt extra weight keeps the stitches apart but readable.
        // (The CACTUS/JACK cross logo was tried too: at menu bar size its letters turn to dots.)
        logo: .cactusJack, iconHeight: 16, iconWeight: 0.5, weightedPaths: Array(CactusJackPathData.paths.indices),
        markSize: CGSize(width: 13.5, height: 12.5),
        // Sampled from the cover's gold head: #B98E49 in shadow to #EBC477 in the highlights.
        palette: Palette(accent: Color(red: 0xD7 / 255, green: 0xB5 / 255, blue: 0x63 / 255),
                         highlight: Color(red: 1, green: 0.95, blue: 0.8),
                         knob: Color(red: 0xF3 / 255, green: 0xDF / 255, blue: 0xA8 / 255),
                         background: Color(red: 0.07, green: 0.052, blue: 0.03),
                         ambient: Color(red: 0xB9 / 255, green: 0x8E / 255, blue: 0x49 / 255).opacity(0.16)),
        markWeight: 0.6)

    /// Tyler, the Creator: the GOLF le FLEUR* flower, in IGOR pink.
    static let tyler = Brand(
        id: "tyler", names: ["Tyler, The Creator"], spotifyURI: "spotify:artist:4V8LLVI7PbaPR0K2TGSxFF",
        // Solid like the bear. It's wider than tall, so the 18pt canvas width limits it to 16pt tall.
        logo: .golfFlower, iconHeight: 16, iconWeight: 0, weightedPaths: [],
        markSize: CGSize(width: 13.5, height: 12.5),
        // Sampled from the IGOR cover's pink background (#DCA9B8–#EDC8D3).
        palette: Palette(accent: Color(red: 0xEC / 255, green: 0xB4 / 255, blue: 0xCC / 255),
                         highlight: Color(red: 1, green: 0.9, blue: 0.95),
                         knob: Color(red: 0xF8 / 255, green: 0xDC / 255, blue: 0xE6 / 255),
                         background: Color(red: 0.06, green: 0.04, blue: 0.05),
                         ambient: Color(red: 0xEC / 255, green: 0xB4 / 255, blue: 0xCC / 255).opacity(0.14)))

    /// J. Cole: the Born Sinner crown.
    static let cole = Brand(
        id: "cole", names: ["J. Cole", "J Cole"], spotifyURI: "spotify:artist:6l3HvQ5sa6mXTsMTB19rO5",
        // A line drawing traced from the album cover, about as wide as tall, so it's full height.
        // 0.3pt extra weight matches the owl; more merges the zigzag points.
        logo: .crown, iconHeight: 17, iconWeight: 0.3, weightedPaths: Array(CrownPathData.paths.indices),
        markSize: CGSize(width: 12, height: 12.5),
        // Fallback only (the album art's colour is used): the crown's gold, #DBC74C.
        palette: Palette(accent: Color(red: 0xDB / 255, green: 0xC7 / 255, blue: 0x4C / 255),
                         highlight: Color(red: 1, green: 0.97, blue: 0.8),
                         knob: Color(red: 0.97, green: 0.93, blue: 0.72),
                         background: Color(white: 0.04),
                         ambient: Color(red: 0xDB / 255, green: 0xC7 / 255, blue: 0x4C / 255).opacity(0.12)),
        markWeight: 0.4)

    /// Checked in this order when several brands are credited equally.
    static let all = [ovo, kanye, xo, travis, tyler, cole]
}
