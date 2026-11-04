import AppKit

/// Tracks Spotify through its `PlaybackStateChanged` distributed notification (no polling).
/// Independent of MediaRemote, so Spotify + Drake mode keep working if the adapter breaks.
@MainActor
final class SpotifyMonitor: NSObject {
    static let bundleID = "com.spotify.client"

    /// nil when Spotify isn't running or has stopped.
    private(set) var info: NowPlayingInfo?
    var onChange: (() -> Void)?

    private let scriptQueue = DispatchQueue(label: "OVOBar.spotify-applescript")
    private var artworkCache: [String: NSImage] = [:]   // trackID → art
    private var creditsCache: [String: [SpotifyCredits.Artist]] = [:]   // trackID → all artists

    var isDrakeTrack: Bool {
        guard let info else { return false }
        if DrakeMatcher.isDrake(artist: info.artist, title: info.title) { return true }
        // The notification only names the first artist; the full credits catch e.g. "Lil Wayne, Drake, Future".
        return creditsCache[info.trackID]?.contains { $0.uri == SpotifyCredits.drakeURI } ?? false
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    func start() {
        // .deliverImmediately: menu bar apps are never "active", and the default
        // suspension behaviour would hold Spotify's updates until they were.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(playbackStateChanged(_:)),
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil,
            suspensionBehavior: .deliverImmediately)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == SpotifyMonitor.bundleID else { return }
            MainActor.assumeIsolated {
                self?.info = nil
                self?.onChange?()
            }
        }
        if isRunning { fetchInitialState() }
    }

    @objc private func playbackStateChanged(_ note: Notification) {
        handle(note.userInfo ?? [:])
    }

    private func handle(_ u: [AnyHashable: Any]) {
        let state = u["Player State"] as? String ?? ""
        Log.write("Spotify: \(state) — \(u["Artist"] ?? "-") / \(u["Name"] ?? "-")")
        if state == "Stopped" { info = nil; onChange?(); return }

        let title = u["Name"] as? String ?? ""
        let artist = u["Artist"] as? String ?? ""
        let trackID = u["Track ID"] as? String ?? ""
        let durationMs = (u["Duration"] as? NSNumber)?.doubleValue ?? 0
        let position = (u["Playback Position"] as? NSNumber)?.doubleValue ?? 0
        let isPlaying = state == "Playing"
        let duration = durationMs / 1000

        // Treat "paused at the very end of a track" as the song having ended.
        if !isPlaying && duration > 0 && position >= duration - 1 {
            info = nil; onChange?(); return
        }

        // Display the main artist only, like the system player; full credits are just for Drake detection.
        var new = NowPlayingInfo(bundleID: Self.bundleID, title: title, artist: artist,
                                 album: u["Album"] as? String ?? "", isPlaying: isPlaying,
                                 duration: duration, elapsed: position, elapsedAt: Date(), trackID: trackID)
        new.artwork = artworkCache[trackID] ?? (info?.trackID == trackID ? info?.artwork : nil)
        info = new
        onChange?()
        if new.artwork == nil, !trackID.isEmpty { fetchArtwork(trackID: trackID) }
        if creditsCache[trackID] == nil { fetchCredits(trackID: trackID) }
    }

    private var creditsInFlight = Set<String>()

    private func fetchCredits(trackID: String) {
        guard !creditsInFlight.contains(trackID) else { return }
        creditsInFlight.insert(trackID)
        Task { [weak self] in
            let artists = await SpotifyCredits.artists(trackID: trackID)
            await MainActor.run {
                guard let self else { return }
                self.creditsInFlight.remove(trackID)
                guard let artists, !artists.isEmpty else { return }
                self.creditsCache[trackID] = artists
                Log.write("Spotify credits: \(artists.map(\.name).joined(separator: ", "))")
                if self.info?.trackID == trackID {
                    self.onChange?()
                }
            }
        }
    }

    // MARK: AppleScript (artwork, initial state, controls)

    private func runScript(_ source: String, completion: (@MainActor (NSAppleEventDescriptor?) -> Void)? = nil) {
        scriptQueue.async {
            var err: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
            if let err { Log.write("Spotify AppleScript error: \(err)") }
            nonisolated(unsafe) let r = result
            DispatchQueue.main.async { MainActor.assumeIsolated { completion?(r) } }
        }
    }

    private func fetchArtwork(trackID: String) {
        // Only talk to Spotify while it's running; `tell` would otherwise launch it.
        guard isRunning else { return }
        runScript(#"tell application "Spotify" to get artwork url of current track"#) { [weak self] r in
            guard let s = r?.stringValue, let url = URL(string: s) else { return }
            Task { [weak self] in
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let img = NSImage(data: data) else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.artworkCache[trackID] = img
                    if self.info?.trackID == trackID { self.info?.artwork = img; self.onChange?() }
                }
            }
        }
    }

    private func fetchInitialState() {
        let script = """
        tell application "Spotify"
            set s to player state as string
            if s is "stopped" then return {s}
            set t to current track
            return {s, name of t, artist of t, album of t, id of t, (duration of t) as string, (player position) as string}
        end tell
        """
        runScript(script) { [weak self] r in
            guard let self, let r, r.numberOfItems >= 7 else { return }
            func item(_ i: Int) -> String { r.atIndex(i)?.stringValue ?? "" }
            let state = item(1) == "playing" ? "Playing" : "Paused"
            let pos = Double(item(7).replacingOccurrences(of: ",", with: ".")) ?? 0
            let dur = Double(item(6).replacingOccurrences(of: ",", with: ".")) ?? 0
            guard self.info == nil else { return }   // a live notification already arrived
            self.handle(["Player State": state, "Name": item(2), "Artist": item(3), "Album": item(4),
                         "Track ID": item(5), "Duration": NSNumber(value: dur), "Playback Position": NSNumber(value: pos)])
        }
    }

    func seek(to seconds: TimeInterval) {
        guard isRunning else { return }
        // Spotify doesn't always post an update after seeking, so move our copy now.
        info?.elapsed = seconds
        info?.elapsedAt = Date()
        onChange?()
        runScript("tell application \"Spotify\" to set player position to \(String(format: "%.2f", seconds))")
    }

    func send(_ command: PlaybackCommand) {
        guard isRunning else { return }
        let verb: String
        switch command {
        case .togglePlayPause: verb = "playpause"
        case .next: verb = "next track"
        case .previous: verb = "previous track"
        case .skipBack15, .skipForward15: return   // done as a seek by NowPlayingModel
        }
        runScript("tell application \"Spotify\" to \(verb)")
    }
}
