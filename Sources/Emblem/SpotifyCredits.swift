import Foundation

/// Full artist credits for a Spotify track, read from its public embed page
/// (open.spotify.com/embed/track/<id>), which needs no login or API key.
enum SpotifyCredits {
    struct Artist: Equatable { let name: String; let uri: String }

    static func artists(trackID: String) async -> [Artist]? {
        // Only real catalogue tracks ("spotify:track:<id>"); skip local files, ads, episodes.
        let parts = trackID.split(separator: ":")
        guard parts.count == 3, parts[1] == "track",
              let url = URL(string: "https://open.spotify.com/embed/track/\(parts[2])") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8) else { return nil }
        return parse(html)
    }

    /// Pulls the first `"artists":[{"name":…,"uri":…},…]` array out of the page.
    static func parse(_ html: String) -> [Artist]? {
        guard let start = html.range(of: #""artists":["#) else { return nil }
        var depth = 0, end = start.upperBound
        for i in html[html.index(before: start.upperBound)...].indices {
            let c = html[i]
            if c == "[" { depth += 1 } else if c == "]" { depth -= 1; if depth == 0 { end = html.index(after: i); break } }
        }
        let json = String(html[html.index(before: start.upperBound)..<end])
        guard let arr = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]] else { return nil }
        return arr.compactMap { d in
            guard let name = d["name"] as? String else { return nil }
            return Artist(name: name, uri: d["uri"] as? String ?? "")
        }
    }
}
