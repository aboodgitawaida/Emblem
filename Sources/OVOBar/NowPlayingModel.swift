import AppKit

extension Notification.Name { static let dismissPlayer = Notification.Name("OVOBar.dismissPlayer") }
import Combine

/// Combines Spotify (notifications) and everything else (MediaRemote adapter)
/// into the one "now playing" item the menu bar shows.
@MainActor
final class NowPlayingModel: ObservableObject {
    @Published private(set) var current: NowPlayingInfo?
    @Published private(set) var brand: Brand?

    let spotify = SpotifyMonitor()
    let system = MediaRemoteMonitor()

    private var currentIsSpotify = false

    func start() {
        spotify.onChange = { [weak self] in self?.recompute() }
        system?.onChange = { [weak self] in self?.recompute() }
        spotify.start()
        system?.start()
    }

    private func recompute() {
        let sp = spotify.info
        let sys = system?.info
        var pick: NowPlayingInfo?

        if let sys, sys.bundleID != SpotifyMonitor.bundleID {
            // Another app owns now playing, unless Spotify is the one actually playing.
            pick = (sp?.isPlaying == true && !sys.isPlaying) ? sp : sys
        } else {
            // MediaRemote says Spotify (or nothing / adapter down): use Spotify's own data.
            pick = sp
        }
        currentIsSpotify = pick?.bundleID == SpotifyMonitor.bundleID
        let newBrand = currentIsSpotify ? spotify.brand : nil
        if pick != current { current = pick }
        if newBrand != brand {
            Log.write("Brand \(newBrand?.id ?? "off") — \(pick?.artist ?? "-") / \(pick?.title ?? "-")")
            brand = newBrand
        }
    }

    /// For DebugRender only.
    func preview(_ info: NowPlayingInfo?, brand: Brand?) { current = info; self.brand = brand }

    /// Brings the playing app forward (Spotify, Music, the browser…), like clicking the system player's artwork.
    func openSource() {
        guard let id = current?.bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)
        NotificationCenter.default.post(name: .dismissPlayer, object: nil)
    }

    func seek(to seconds: TimeInterval) {
        if currentIsSpotify { spotify.seek(to: seconds) } else { system?.seek(to: seconds) }
    }

    func send(_ command: PlaybackCommand) {
        if command == .skipBack15 || command == .skipForward15, let info = current {
            let now = info.elapsed(at: Date())
            let target = command == .skipBack15 ? max(0, now - 15) : min(info.duration > 0 ? info.duration : .infinity, now + 15)
            seek(to: target)
            return
        }
        if currentIsSpotify { spotify.send(command) } else { system?.send(command) }
    }
}
