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
    /// Brand names that contain a separator themselves ("Tyler, The Creator") are kept whole.
    static func credits(in s: String) -> [String] {
        let pattern = #"\s*(?:,|&|\+|/|\bx\b|\band\b|\bwith\b|\bfeat\.?|\bft\.?|\bfeaturing\b)\s*"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [s] }
        var s = s
        let kept = Brand.all.flatMap(\.names).filter { re.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
        for (i, name) in kept.enumerated() {
            s = s.replacingOccurrences(of: name, with: "\u{1E}\(i)\u{1E}", options: .caseInsensitive)
        }
        let marked = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "\u{1F}")
        return marked.split(separator: "\u{1F}").map { part in
            var p = String(part)
            for (i, name) in kept.enumerated() { p = p.replacingOccurrences(of: "\u{1E}\(i)\u{1E}", with: name) }
            return p
        }
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

    /// Run with `Emblem --selftest`.
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
            // Tyler, the Creator (his name contains a comma)
            ("Tyler, The Creator", "EARFQUAKE", "tyler"),
            ("TYLER, THE CREATOR", "NEW MAGIC WAND", "tyler"),
            ("Tyler, The Creator, Kali Uchis", "See You Again", "tyler"),
            ("Kali Uchis", "After The Storm (feat. Tyler, The Creator & Bootsy Collins)", "tyler"),
            ("Drake", "Song (feat. Tyler, The Creator)", "ovo"),
            ("Tyler Childers", "Song", nil),
            ("The Creator", "Song", nil),
            ("Tyler", "Song", nil),
            // J. Cole
            ("J. Cole", "No Role Modelz", "cole"),
            ("J. Cole, Lil Baby", "pride.is.the.devil", "cole"),
            ("Drake", "First Person Shooter (feat. J. Cole)", "ovo"),
            ("21 Savage", "a lot (feat. J. Cole)", "savage"),      // the lead artist wins
            ("Kendrick Lamar", "Like That", nil),
            ("Cole Swindell", "Song", nil),
            // MF DOOM, Wu-Tang Clan, 21 Savage, Billie Eilish, Lil Peep
            ("MF DOOM", "Doomsday", "doom"),
            ("DOOM", "Gazzillion Ear", "doom"),
            ("Madvillain", "Accordion", nil),                        // a group, not the DOOM credit
            ("Danger Doom", "Sofa King", nil),
            ("Wu-Tang Clan", "C.R.E.A.M.", "wutang"),
            ("Wu-Tang Clan, Method Man", "Song", "wutang"),
            ("21 Savage", "redrum", "savage"),
            ("21 Savage, Metro Boomin", "Runnin", "savage"),
            ("Drake", "Rich Flex (with 21 Savage)", "ovo"),
            ("Metro Boomin", "Song (feat. 21 Savage)", "savage"),
            ("Billie Eilish", "BIRDS OF A FEATHER", "billie"),
            ("Khalid", "lovely (with Billie Eilish)", "billie"),
            ("Lil Peep", "Star Shopping", "peep"),
            ("Lil Peep, XXXTENTACION", "Falling Down", "peep"),
            ("Lil Peeps", "Song", nil),
        ]
        var ok = true
        for (a, t, want) in cases where brand(artist: a, title: t)?.id != want {
            print("FAIL: artist=\(a) title=\(t) expected \(want ?? "none")"); ok = false
        }
        // Full credits from Spotify, when the notification only names the first artist.
        let drake = SpotifyCredits.Artist(name: "Drake", uri: (Brand.named("ovo")?.spotifyURI ?? ""))
        let kanye = SpotifyCredits.Artist(name: "Kanye West", uri: (Brand.named("kanye")?.spotifyURI ?? ""))
        let other = SpotifyCredits.Artist(name: "¥$", uri: "spotify:artist:other")
        let creditCases: [(String, [SpotifyCredits.Artist], String?)] = [
            ("Lil Wayne", [other, drake], "ovo"),
            ("¥$", [other, kanye], "kanye"),
            ("Someone", [other, kanye, drake], "kanye"),
            ("Kanye West", [kanye, drake], "kanye"),
            ("Kali Uchis", [other, SpotifyCredits.Artist(name: "Tyler, The Creator", uri: (Brand.named("tyler")?.spotifyURI ?? ""))], "tyler"),
            ("Dreamville", [other, SpotifyCredits.Artist(name: "J. Cole", uri: (Brand.named("cole")?.spotifyURI ?? ""))], "cole"),
            ("JACKBOYS", [other, SpotifyCredits.Artist(name: "Travis Scott", uri: (Brand.named("travis")?.spotifyURI ?? ""))], "travis"),
            ("Ariana Grande", [other, SpotifyCredits.Artist(name: "The Weeknd", uri: (Brand.named("xo")?.spotifyURI ?? ""))], "xo"),
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
