import Foundation

struct SimDevice: Identifiable, Equatable {
    var id: String { udid }
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool
    let runtime: String
}

struct CommandError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum Simctl {
    static let xcrunPath = "/usr/bin/xcrun"

    static var xcrunExists: Bool {
        FileManager.default.isExecutableFile(atPath: xcrunPath)
    }

    static func run(_ arguments: [String]) throws -> String {
        if !xcrunExists {
            throw CommandError(message: "Install Xcode Command Line Tools")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: xcrunPath)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            throw CommandError(message: error.localizedDescription)
        }
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            let text = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let combined = text.isEmpty ? fallback : text
            if combined.lowercased().contains("xcode") || combined.lowercased().contains("developer") {
                throw CommandError(message: combined.isEmpty ? "Install Xcode Command Line Tools" : combined)
            }
            throw CommandError(message: combined.isEmpty ? "xcrun exited \(process.terminationStatus)" : combined)
        }
        return stdout
    }

    static func listDevices() throws -> [SimDevice] {
        let json = try run(["simctl", "list", "-j", "devices"])
        guard let data = json.data(using: .utf8) else {
            throw CommandError(message: "simctl returned empty JSON")
        }
        let root: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CommandError(message: "simctl JSON was not an object")
            }
            root = parsed
        } catch let error as CommandError {
            throw error
        } catch {
            throw CommandError(message: error.localizedDescription)
        }
        guard let map = root["devices"] as? [String: Any] else {
            throw CommandError(message: "simctl JSON missing devices")
        }
        var result: [SimDevice] = []
        for (runtime, value) in map {
            guard let rows = value as? [[String: Any]] else { continue }
            let pretty = prettyRuntime(runtime)
            for row in rows {
                guard let udid = row["udid"] as? String, !udid.isEmpty else { continue }
                let name = row["name"] as? String ?? udid
                let state = row["state"] as? String ?? ""
                let available = (row["isAvailable"] as? Bool) ?? true
                let booted = state.caseInsensitiveCompare("Booted") == .orderedSame
                if available || booted {
                    result.append(
                        SimDevice(
                            udid: udid,
                            name: name,
                            state: state,
                            isAvailable: available,
                            runtime: pretty
                        )
                    )
                }
            }
        }
        result.sort { a, b in
            let aBoot = a.state.caseInsensitiveCompare("Booted") == .orderedSame
            let bBoot = b.state.caseInsensitiveCompare("Booted") == .orderedSame
            if aBoot != bBoot { return aBoot && !bBoot }
            if a.runtime != b.runtime { return a.runtime < b.runtime }
            return a.name < b.name
        }
        return result
    }

    static func boot(_ udid: String) throws {
        _ = try run(["simctl", "boot", udid])
    }

    static func shutdown(_ udid: String) throws {
        _ = try run(["simctl", "shutdown", udid])
    }

    static func addMedia(udid: String, path: String) throws {
        _ = try run(["simctl", "addmedia", udid, path])
    }

    static func install(udid: String, path: String) throws {
        _ = try run(["simctl", "install", udid, path])
    }

    static func push(udid: String, path: String) throws {
        _ = try run(["simctl", "push", udid, "booted", path])
    }

    static func openURL(udid: String, url: String) throws {
        _ = try run(["simctl", "openurl", udid, url])
    }

    static func openSimulatorApp() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Simulator"]
        let err = Pipe()
        process.standardError = err
        do {
            try process.run()
        } catch {
            throw CommandError(message: error.localizedDescription)
        }
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let text = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CommandError(message: text.isEmpty ? "open -a Simulator failed" : text)
        }
    }

    private static func prettyRuntime(_ key: String) -> String {
        guard let last = key.split(separator: ".").last else { return key }
        return last.replacingOccurrences(of: "-", with: " ")
    }
}
