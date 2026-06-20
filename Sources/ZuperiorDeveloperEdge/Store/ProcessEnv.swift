import Foundation

/// Builds the environment dictionary used when spawning Process instances.
/// Centralizes PATH/HOME defaults so adding a variable (e.g. GIT_CONFIG_GLOBAL)
/// is a one-file change instead of a scavenger hunt across Store+*.swift.
enum ProcessEnv {

    /// Base PATH that Homebrew + system binaries resolve under.
    private static let standardPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

    /// Path additions to find python3 from python.org framework installs.
    private static let pythonPath = "/Library/Frameworks/Python.framework/Versions/3.13/bin"

    /// Build a base environment with PATH + HOME set.
    static func base(extraPath: String? = nil) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let prefix = extraPath.map { "\($0):\(standardPath)" } ?? standardPath
        env["PATH"] = "\(prefix):\(env["PATH"] ?? "")"
        env["HOME"] = NSHomeDirectory()
        return env
    }

    /// Base + git hardening (no interactive prompts, auto-accept SSH host keys).
    static func git() -> [String: String] {
        var env = base()
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_SSH_COMMAND"] = "ssh -o StrictHostKeyChecking=accept-new"
        return env
    }

    /// Base + Python framework PATH.
    static func python() -> [String: String] {
        base(extraPath: pythonPath)
    }
}
