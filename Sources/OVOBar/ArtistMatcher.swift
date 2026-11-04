import Foundation

/// Decides which brand (if any) a track belongs to.
/// Artists match as whole credits, so e.g. "Drake Bell", "Mandrake", "Yeat" or "The Weekend" don't count.
enum ArtistMatcher {
    /// The lead artist wins: a Kanye song featuring Drake is Kanye's, and Drake's song featuring Kanye is Drake's.
    /// Order: the artist field (lead first), then Spotify's full credits, then "feat." names in the title.
    static func brand(artist: String, title: String, credits full: [SpotifyCredits.Artist]? = nil,
                      among brands: [Brand] = Brand.all) -> Brand? {
        for name in credits(in: artist) {
            if let b = brands.first(where: { $0.matches(name: name) }) { return b }
        }
        for c in full ?? [] {
            if let b = brands.first(where: { $0.spotifyURI == c.uri }) { return b }
        }
        for name in featuredCredits(inTitle: title) {
            if let b = brands.first(where: { $0.matches(name: name) }) { return b }
        }
        return nil
    }

    /// Splits "A, B & C", "A x B", "A and B", "A feat. B" into names.
    static func credits(in s: String) -> [String] {
        let pattern = #"\s*(?:,|&|\+|/|\bx\b|\band\b|\bwith\b|\bfeat\.?|\bft\.?|\bfeaturing\b)\s*"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [s] }
        let marked = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "\u{1F}")
        return marked.split(separator: "\u{1F}").map { String($0) }
    }

    /// Credits after "feat."/"ft."/"featuring"/"with" in a title, e.g. "Song (feat. Drake & Future)".
    static func featuredCredits(inTitle title: String) -> [String] {
        let pattern = #"(?:^|[\s(\[\-])(?:feat\.?|ft\.?|featuring|with)\s+([^)\]]+)"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = title as NSString
        return re.matches(in: title, range: NSRange(location: 0, length: ns.length)).flatMap { m in
            credits(in: ns.substring(with: m.range(at: 1)))
        }
    }

    /// Run with `OVOBar --selftest`.
    static func selfTest() -> Bool {
        let cases: [(String, String, String?)] = [
            // Drake
            ("Drake", "Hotline Bling", "ovo"),
            ("DRAKE", "God's Plan", "ovo"),
            ("Drake, 21 Savage", "Rich Flex", "ovo"),
            ("Future", "Life Is Good (feat. Drake)", "ovo"),
            ("Rihanna", "Work (ft. Drake)", "ovo"),
            ("Travis Scott", "SICKO MODE (with Drake)", "travis"),   // Travis's song, so Travis wins
            ("Future", "Song (with Drake)", "ovo"),
            ("Lil Wayne", "Right Above It - feat. Drake", "ovo"),
            ("DJ Khaled", "Popstar (feat. Drake) [Explicit]", "ovo"),
            ("Future & Drake", "Jumpman", "ovo"),
            ("Drake Bell", "Found a Way", nil),
            ("Mandrake", "Drakeford", nil),
            ("Josh Drake", "Song", nil),
            ("Kendrick Lamar", "Not Like Us", nil),
            ("Someone", "Song (feat. Drake Bell)", nil),
            ("Someone", "Drake", nil),   // a title *about* Drake isn't a feature
            ("Someone", "Song with Drakeo the Ruler", nil),
            // Kanye
            ("Kanye West", "Stronger", "kanye"),
            ("Ye", "Donda Chant", "kanye"),
            ("Kanye West, JAY-Z", "Otis", "kanye"),
            ("Pusha T", "What Would Meek Do? (feat. Kanye West)", "kanye"),
            ("Yeat", "Sorry Bout That", nil),
            ("Kanye West Tribute", "Song", nil),
            // Both: the lead artist wins
            ("Drake", "Glow (feat. Kanye West)", "ovo"),
            ("Kanye West", "Forever (feat. Drake)", "kanye"),
            ("Someone", "Song (feat. Kanye West & Drake)", "kanye"),
            // The Weeknd
            ("The Weeknd", "Blinding Lights", "xo"),
            ("The Weeknd, Daft Punk", "Starboy", "xo"),
            ("Future", "Low Life (feat. The Weeknd)", "xo"),
            ("Drake", "Crew Love (feat. The Weeknd)", "ovo"),
            ("Kanye West", "Hold Tight (feat. The Weeknd)", "kanye"),
            ("The Weekend", "Song", nil),
            ("Weekend Band", "Song", nil),
            // Travis Scott
            ("Travis Scott", "goosebumps", "travis"),
            ("Travis Scott, Kendrick Lamar", "goosebumps", "travis"),
            ("Kanye West", "Piss On Your Grave (feat. Travis Scott)", "kanye"),
            ("Drake", "Company (feat. Travis Scott)", "ovo"),
            ("Don Toliver", "Can't Feel My Legs (feat. Travis Scott)", "travis"),
            ("Travis Scott Fan", "Song", nil),
            ("Randy Travis", "Song", nil),
        ]
        var ok = true
        for (a, t, want) in cases where brand(artist: a, title: t)?.id != want {
            print("FAIL: artist=\(a) title=\(t) expected \(want ?? "none")"); ok = false
        }
        // Full credits from Spotify, when the notification only names the first artist.
        let drake = SpotifyCredits.Artist(name: "Drake", uri: Brand.ovo.spotifyURI)
        let kanye = SpotifyCredits.Artist(name: "Kanye West", uri: Brand.kanye.spotifyURI)
        let other = SpotifyCredits.Artist(name: "¥$", uri: "spotify:artist:other")
        let creditCases: [(String, [SpotifyCredits.Artist], String?)] = [
            ("Lil Wayne", [other, drake], "ovo"),
            ("¥$", [other, kanye], "kanye"),
            ("Someone", [other, kanye, drake], "kanye"),
            ("Kanye West", [kanye, drake], "kanye"),
            ("JACKBOYS", [other, SpotifyCredits.Artist(name: "Travis Scott", uri: Brand.travis.spotifyURI)], "travis"),
            ("Ariana Grande", [other, SpotifyCredits.Artist(name: "The Weeknd", uri: Brand.xo.spotifyURI)], "xo"),
            ("Someone", [other], nil),
        ]
        for (a, credits, want) in creditCases where brand(artist: a, title: "Song", credits: credits)?.id != want {
            print("FAIL: artist=\(a) credits=\(credits.map(\.name)) expected \(want ?? "none")"); ok = false
        }
        let total = cases.count + creditCases.count
        print(ok ? "ArtistMatcher: all \(total) cases pass" : "ArtistMatcher: failures")
        return ok
    }
}
