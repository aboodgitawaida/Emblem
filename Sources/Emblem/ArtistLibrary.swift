import SwiftUI

/// Loads the artists Emblem dresses up for. Each artist is a folder holding `artist.json` and its
/// logo as an SVG (see ADDING_ARTISTS.md):
///   - the app's own, in `Emblem.app/Contents/Resources/Artists` (from `Artists/` in the repo), and
///   - your own, in `~/Library/Application Support/Emblem/Artists`, which needs no rebuild.
/// A folder of yours with the same name as a built-in one replaces it.
enum ArtistLibrary {
    static var userFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Emblem/Artists", isDirectory: true)
    }

    /// The built-in folder: inside the app, or `Artists/` in the repo when run from `.build`.
    static var bundledFolder: URL? {
        if let r = Bundle.main.resourceURL?.appendingPathComponent("Artists"), exists(r) { return r }
        var dir = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        for _ in 0..<6 {
            let candidate = dir.appendingPathComponent("Artists")
            if exists(candidate) { return candidate }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    private static func exists(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    struct Problem: Error, CustomStringConvertible {
        let folder: String
        let message: String
        var description: String { "\(folder): \(message)" }
    }

    /// Every artist that loads, sorted by folder name, plus what was wrong with any that didn't.
    static func load() -> (brands: [Brand], problems: [Problem]) {
        var byID: [String: Brand] = [:]
        var problems: [Problem] = []
        for root in [bundledFolder, userFolder].compactMap({ $0 }) where exists(root) {
            let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for folder in folders where exists(folder) && !folder.lastPathComponent.hasPrefix(".") {
                do { let b = try brand(in: folder); byID[b.id] = b }
                catch let p as Problem { problems.append(p) }
                catch { problems.append(Problem(folder: folder.lastPathComponent, message: "\(error)")) }
            }
        }
        // Two artists can't share a Spotify ID or a name: a track would match whichever loads first.
        let brands = byID.keys.sorted().map { byID[$0]! }
        var seen: [String: String] = [:]
        for b in brands {
            for key in [b.spotifyURI] + b.names.map({ $0.lowercased() }) {
                if let other = seen[key] {
                    problems.append(Problem(folder: b.id, message: "shares \(key.hasPrefix("spotify:") ? "its Spotify ID" : "the name \"\(key)\"") with \(other)"))
                } else { seen[key] = b.id }
            }
        }
        for p in problems { Log.write("Artist problem — \(p)") }
        return (brands, problems)
    }

    // MARK: artist.json

    private struct Spec: Decodable {
        let name: String
        let matchNames: [String]
        let spotifyArtistID: String
        let logo: LogoSpec
        let menuBar: MenuBarSpec
        let player: PlayerSpec
        let colors: ColorsSpec

        struct LogoSpec: Decodable {
            let file: String
            let fill: String          // "evenOdd" (holes cut out) or "nonZero"
            let solid: Bool           // solid shapes trace their outline, then fade the fill in
        }
        struct MenuBarSpec: Decodable {
            let height: CGFloat
            let outlineWeight: CGFloat
            let outlinedPaths: Paths   // "all", or path numbers (0 = first, -1 = last)
            let extraWeights: [String: CGFloat]?
        }
        struct PlayerSpec: Decodable {
            let markSize: [CGFloat]
            let markWeight: CGFloat?
        }
        struct ColorsSpec: Decodable {
            let accent, highlight, knob, background, ambient: ColorValue
        }
        enum Paths: Decodable {
            case all, some([Int])
            init(from d: Decoder) throws {
                let c = try d.singleValueContainer()
                if let s = try? c.decode(String.self), s == "all" { self = .all; return }
                self = .some(try c.decode([Int].self))
            }
        }
    }

    /// "#RRGGBB", "#RRGGBBAA", or sRGB components 0–1: [r, g, b] or [r, g, b, opacity].
    private struct ColorValue: Decodable {
        let r, g, b, a: Double
        init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let s = try? c.decode(String.self) {
                let hex = s.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                guard hex.count == 6 || hex.count == 8, let v = UInt64(hex, radix: 16) else {
                    throw DecodingError.dataCorruptedError(in: c, debugDescription: "colour \"\(s)\" should look like #D9A441")
                }
                let n = hex.count == 8 ? v : (v << 8 | 0xFF)
                r = Double(n >> 24 & 0xFF) / 255; g = Double(n >> 16 & 0xFF) / 255
                b = Double(n >> 8 & 0xFF) / 255; a = Double(n & 0xFF) / 255
                return
            }
            let v = try c.decode([Double].self)
            guard v.count == 3 || v.count == 4, v.allSatisfy({ (0...1).contains($0) }) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "colour lists are [r, g, b] or [r, g, b, opacity], each 0–1")
            }
            r = v[0]; g = v[1]; b = v[2]; a = v.count == 4 ? v[3] : 1
        }
        var color: Color {
            let c = Color(red: r, green: g, blue: b)
            return a < 1 ? c.opacity(a) : c
        }
    }

    static func brand(in folder: URL) throws -> Brand {
        let id = folder.lastPathComponent
        func fail(_ m: String) -> Problem { Problem(folder: id, message: m) }
        let jsonURL = folder.appendingPathComponent("artist.json")
        guard let data = try? Data(contentsOf: jsonURL) else { throw fail("no artist.json") }
        let spec: Spec
        do { spec = try JSONDecoder().decode(Spec.self, from: data) }
        catch let DecodingError.keyNotFound(key, _) { throw fail("artist.json is missing \"\(key.stringValue)\"") }
        catch let DecodingError.dataCorrupted(ctx) { throw fail("artist.json: \(ctx.debugDescription)") }
        catch let DecodingError.typeMismatch(_, ctx) {
            throw fail("artist.json: wrong kind of value at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
        }
        guard !spec.matchNames.isEmpty else { throw fail("matchNames is empty") }
        guard spec.spotifyArtistID.count == 22, spec.spotifyArtistID.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw fail("spotifyArtistID should be the 22 characters after open.spotify.com/artist/")
        }
        guard ["evenOdd", "nonZero"].contains(spec.logo.fill) else { throw fail("logo.fill is \"evenOdd\" or \"nonZero\"") }
        guard spec.player.markSize.count == 2 else { throw fail("player.markSize is [width, height]") }
        guard (8...21.5).contains(spec.menuBar.height) else { throw fail("menuBar.height should be 8–21.5pt (the icon is 22pt tall)") }

        let svgURL = folder.appendingPathComponent(spec.logo.file)
        guard let svg = try? String(contentsOf: svgURL, encoding: .utf8) else { throw fail("no \(spec.logo.file)") }
        let (paths, box) = try svgPaths(svg, folder: id)
        let logo = Logo(paths: paths, bounds: box, evenOdd: spec.logo.fill == "evenOdd", solid: spec.logo.solid)

        let outlined: [Int]
        switch spec.menuBar.outlinedPaths {
        case .all: outlined = Array(paths.indices)
        case .some(let list):
            outlined = try list.map { i in
                let j = i < 0 ? paths.count + i : i
                guard paths.indices.contains(j) else { throw fail("outlinedPaths has \(i), but the logo has \(paths.count) paths") }
                return j
            }
        }
        var extra: [Int: CGFloat] = [:]
        for (k, v) in spec.menuBar.extraWeights ?? [:] {
            guard let i = Int(k), paths.indices.contains(i) else { throw fail("extraWeights has path \(k), but the logo has \(paths.count) paths") }
            extra[i] = v
        }
        let c = spec.colors
        return Brand(id: id, names: spec.matchNames, spotifyURI: "spotify:artist:\(spec.spotifyArtistID)", logo: logo,
                     iconHeight: spec.menuBar.height, iconWeight: spec.menuBar.outlineWeight, weightedPaths: outlined,
                     markSize: CGSize(width: spec.player.markSize[0], height: spec.player.markSize[1]),
                     palette: Brand.Palette(accent: c.accent.color, highlight: c.highlight.color, knob: c.knob.color,
                                            background: c.background.color, ambient: c.ambient.color),
                     markWeight: spec.player.markWeight ?? 0, pathWeights: extra)
    }

    /// The `d` of every `<path>` and the `viewBox`, which should be cropped tight around the logo.
    static func svgPaths(_ svg: String, folder: String) throws -> ([String], (x: Double, y: Double, width: Double, height: Double)) {
        func fail(_ m: String) -> Problem { Problem(folder: folder, message: m) }
        func firstGroup(_ pattern: String, in s: String) -> String? {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let r = Range(m.range(at: 1), in: s) else { return nil }
            return String(s[r])
        }
        guard let vb = firstGroup(#"viewBox\s*=\s*"([^"]+)""#, in: svg) else { throw fail("logo has no viewBox") }
        let n = vb.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard n.count == 4, n[2] > 0, n[3] > 0 else { throw fail("logo's viewBox should be four numbers: x y width height") }
        let re = try NSRegularExpression(pattern: #"<path\b[^>]*?\sd\s*=\s*"([^"]*)""#, options: [.dotMatchesLineSeparators])
        let paths = re.matches(in: svg, range: NSRange(svg.startIndex..., in: svg)).compactMap { m in
            Range(m.range(at: 1), in: svg).map { String(svg[$0]) }
        }
        guard !paths.isEmpty else { throw fail("logo has no <path d=\"…\"> elements (shapes like <circle> need converting to paths)") }
        if paths.contains(where: { $0.contains(where: { $0 == "A" || $0 == "a" }) }) {
            throw fail("logo uses arcs (A/a in a path), which Emblem can't draw; convert them to curves")
        }
        return (paths, (n[0], n[1], n[2], n[3]))
    }
}
