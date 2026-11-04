import Foundation
// AXDump launcher: runs ./axdump (next to this app) with the given arguments.
// The child inherits this app's Accessibility permission, so axdump can be rebuilt freely.
let tool = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    .appendingPathComponent("../../../axdump").standardizedFileURL
let p = Process()
p.executableURL = tool
p.arguments = Array(CommandLine.arguments.dropFirst())
try p.run()
p.waitUntilExit()
exit(p.terminationStatus)
