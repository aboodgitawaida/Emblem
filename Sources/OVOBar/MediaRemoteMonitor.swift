import AppKit

/// System-wide now playing info via mediaremote-adapter (github.com/ungive/mediaremote-adapter):
/// /usr/bin/perl is entitled to MediaRemote and loads the bundled helper framework.
/// If it fails, `isAvailable` becomes false and only non-Spotify sources are lost.
@MainActor
final class MediaRemoteMonitor {
    private(set) var info: NowPlayingInfo?
    private(set) var isAvailable = false
    var onChange: (() -> Void)?

    private let dir: URL
    private var process: Process?
    private var payload: [String: Any] = [:]
    private var buffer = Data()
    private var restarts = 0

    init?() {
        guard let res = Bundle.main.resourceURL?.appendingPathComponent("adapter"),
              FileManager.default.fileExists(atPath: res.appendingPathComponent("mediaremote-adapter.pl").path)
        else { Log.write("adapter not bundled"); return nil }
        dir = res
    }

    private var baseArgs: [String] {
        [dir.appendingPathComponent("mediaremote-adapter.pl").path,
         dir.appendingPathComponent("MediaRemoteAdapter.framework").path,
         dir.appendingPathComponent("MediaRemoteAdapterTestClient").path]
    }

    func start() {
        DispatchQueue.global(qos: .utility).async { [baseArgs] in
            // Kill adapters orphaned by a previous OVOBar that didn't quit cleanly (reparented to launchd).
            let cleanup = Process()
            cleanup.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            cleanup.arguments = ["-P", "1", "-f", "OVOBar.app/Contents/Resources/adapter/mediaremote-adapter.pl"]
            try? cleanup.run(); cleanup.waitUntilExit()

            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
            p.arguments = baseArgs + ["test"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            let ok = (try? p.run()) != nil && { p.waitUntilExit(); return p.terminationStatus == 0 }()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.isAvailable = ok
                    Log.write("Adapter self-test \(ok ? "passed" : "failed")")
                    if ok { self.launchStream() } else { Log.write("mediaremote-adapter test failed; general sources disabled") }
                }
            }
        }
    }

    func stop() { process?.terminate(); process = nil }

    private func launchStream() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = baseArgs + ["stream", "--micros", "--debounce=100"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let chunk = h.availableData
            guard !chunk.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.consume(chunk) } }
        }
        p.terminationHandler = { [weak self] _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.streamExited() } }
        }
        do { try p.run(); process = p } catch {
            Log.write("failed to launch adapter: \(error)"); isAvailable = false
        }
    }

    private func streamExited() {
        process = nil
        info = nil; payload = [:]; buffer = Data()
        onChange?()
        restarts += 1
        guard restarts <= 5 else { isAvailable = false; Log.write("adapter keeps exiting; giving up"); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(restarts) * 2) { [weak self] in self?.launchStream() }
    }

    private func consume(_ chunk: Data) {
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let p = obj["payload"] as? [String: Any] else { continue }
            restarts = 0
            if obj["diff"] as? Bool == true {
                for (k, v) in p { if v is NSNull { payload.removeValue(forKey: k) } else { payload[k] = v } }
            } else {
                payload = p.filter { !($0.value is NSNull) }
            }
            rebuild()
        }
    }

    private var artworkKey: String?
    private var artworkImage: NSImage?

    private func rebuild() {
        guard let bundle = payload["bundleIdentifier"] as? String,
              let title = payload["title"] as? String else {
            if info != nil { info = nil; onChange?() }
            return
        }
        func micros(_ k: String) -> Double { ((payload[k] as? NSNumber)?.doubleValue ?? 0) / 1_000_000 }
        let ts = micros("timestampEpochMicros")
        let parent = payload["parentApplicationBundleIdentifier"] as? String

        if let b64 = payload["artworkData"] as? String {
            let key = String(b64.prefix(64)) + "\(b64.count)"
            if key != artworkKey {
                artworkKey = key
                artworkImage = Data(base64Encoded: b64).flatMap(NSImage.init(data:))
            }
        } else { artworkKey = nil; artworkImage = nil }

        let new = NowPlayingInfo(
            bundleID: parent ?? bundle, title: title,
            artist: payload["artist"] as? String ?? "", album: payload["album"] as? String ?? "",
            isPlaying: payload["playing"] as? Bool ?? false,
            duration: micros("durationMicros"), elapsed: micros("elapsedTimeMicros"),
            elapsedAt: ts > 0 ? Date(timeIntervalSince1970: ts) : Date(),
            trackID: payload["uniqueIdentifier"].map { "\($0)" } ?? "", artwork: artworkImage)
        if new != info {
            if new.title != info?.title || new.isPlaying != info?.isPlaying {
                Log.write("System: \(new.bundleID) \(new.isPlaying ? "playing" : "paused") — \(new.artist) / \(new.title)")
            }
            info = new; onChange?()
        }
    }

    func seek(to seconds: TimeInterval) {
        info?.elapsed = seconds
        info?.elapsedAt = Date()
        onChange?()
        run(["seek", String(Int64(max(0, seconds) * 1_000_000))])
    }

    private func run(_ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = baseArgs + args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }

    func send(_ command: PlaybackCommand) {
        let id: String
        switch command {
        case .togglePlayPause: id = "2"
        case .next: id = "4"
        case .previous: id = "5"
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        p.arguments = baseArgs + ["send", id]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}
