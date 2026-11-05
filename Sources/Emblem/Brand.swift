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
        /// Colours for the living background, taken from the album art (empty: the flat background).
        var mesh: [Color] = []
    }

    static func == (a: Brand, b: Brand) -> Bool { a.id == b.id }

    func matches(name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.contains { $0.caseInsensitiveCompare(n) == .orderedSame }
    }

    /// Every artist in `Artists/` (and the user's own folder), loaded once at launch. See ArtistLibrary.
    static let all: [Brand] = ArtistLibrary.load().brands

    /// The artist whose folder is `Artists/<id>`.
    static func named(_ id: String) -> Brand? { all.first { $0.id == id } }
}
