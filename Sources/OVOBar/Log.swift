import Foundation

/// Appends to ~/Library/Logs/OVOBar.log (and the system log).
enum Log {
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/OVOBar.log")
    private static let queue = DispatchQueue(label: "OVOBar.log")

    static func write(_ message: String) {
        NSLog("OVOBar: %@", message)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        queue.async {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
            } else {
                try? line.data(using: .utf8)!.write(to: url)
            }
        }
    }
}
