import Foundation

/// Decides whether a track has Drake as lead or featured artist.
/// Matches "Drake" as a whole artist name, so e.g. "Drake Bell" or "Mandrake" don't count.
enum DrakeMatcher {
    static func isDrake(artist: String, title: String) -> Bool {
        if credits(in: artist).contains(where: isDrakeName) { return true }
        return featuredCredits(inTitle: title).contains(where: isDrakeName)
    }

    private static func isDrakeName(_ s: String) -> Bool {
        s.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("drake") == .orderedSame
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
        let cases: [(String, String, Bool)] = [
            ("Drake", "Hotline Bling", true),
            ("DRAKE", "God's Plan", true),
            ("Drake, 21 Savage", "Rich Flex", true),
            ("Future", "Life Is Good (feat. Drake)", true),
            ("Rihanna", "Work (ft. Drake)", true),
            ("Travis Scott", "SICKO MODE (with Drake)", true),
            ("Lil Wayne", "Right Above It - feat. Drake", true),
            ("DJ Khaled", "Popstar (feat. Drake) [Explicit]", true),
            ("Future & Drake", "Jumpman", true),
            ("Drake Bell", "Found a Way", false),
            ("Mandrake", "Drakeford", false),
            ("Josh Drake", "Song", false),
            ("Kendrick Lamar", "Not Like Us", false),
            ("Someone", "Song (feat. Drake Bell)", false),
            ("Someone", "Drake", false),   // a title *about* Drake isn't a feature
            ("Someone", "Song with Drakeo the Ruler", false),
        ]
        var ok = true
        for (a, t, want) in cases where isDrake(artist: a, title: t) != want {
            print("FAIL: artist=\(a) title=\(t) expected \(want)"); ok = false
        }
        print(ok ? "DrakeMatcher: all \(cases.count) cases pass" : "DrakeMatcher: failures")
        return ok
    }
}
