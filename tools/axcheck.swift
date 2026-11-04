import ApplicationServices
// Prints whether this process may use Accessibility; with --prompt, asks macOS to show the permission prompt.
let prompt = CommandLine.arguments.contains("--prompt")
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
print(AXIsProcessTrustedWithOptions(opts) ? "trusted" : "not trusted")
