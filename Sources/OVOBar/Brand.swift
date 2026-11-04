import SwiftUI

/// An artist the app dresses up for: who counts, the menu bar logo, and the player's colors.
struct Brand: Equatable {
    let id: String
    /// Whole credit names, matched case-insensitively ("Drake" counts, "Drake Bell" doesn't).
    let names: [String]
    let spotifyURI: String
    let logo: Logo
    /// Menu bar logo height and the extra outline stroke on `weightedPath` (pt).
    let iconHeight: CGFloat
    let iconWeight: CGFloat
    let weightedPath: Int?
    /// The small logo top-right of the player, where the level meter normally sits.
    let markSize: CGSize
    let palette: Palette

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
        logo: .owl, iconHeight: 16.5, iconWeight: 0.4,
        // Only the body outline (last path) gets weight; thickening the eyes and beak fills in the face.
        weightedPath: OwlPathData.paths.count - 1,
        markSize: CGSize(width: 10, height: 12.5),
        palette: Palette(accent: ovoGold,
                         highlight: Color(red: 1, green: 0.95, blue: 0.82),
                         knob: Color(red: 0.93, green: 0.86, blue: 0.68),
                         background: Color(white: 0.035),
                         ambient: ovoGold.opacity(0.10)))

    /// Kanye: the College Dropout bear, maroon and gold.
    static let kanye = Brand(
        id: "kanye", names: ["Kanye West", "Kanye", "Ye"], spotifyURI: "spotify:artist:5K4W6rqBFWDnAN6FQUkS6x",
        // The bear is an outline already (1.4pt head, 0.9pt face at 16.5pt), so no extra weight.
        // It's nearly as wide as tall, so it sits a little smaller than the owl to look the same size.
        logo: .bear, iconHeight: 15.5, iconWeight: 0, weightedPath: nil,
        markSize: CGSize(width: 12.5, height: 12),
        palette: Palette(accent: Color(red: 0xD9 / 255, green: 0xA4 / 255, blue: 0x41 / 255),
                         highlight: Color(red: 1, green: 0.92, blue: 0.74),
                         knob: Color(red: 0.96, green: 0.86, blue: 0.62),
                         background: Color(red: 0.075, green: 0.025, blue: 0.03),
                         ambient: Color(red: 0.62, green: 0.12, blue: 0.18).opacity(0.28)))

    /// Checked in this order when several brands are credited equally.
    static let all = [ovo, kanye]
}
