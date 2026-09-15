import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let bundlePrefix = "engineer.badry.simulatordrop."
    static let pinnedKey = bundlePrefix + "pinnedUDID"
    static let recentKey = bundlePrefix + "recentPaths"

    @Published var devices: [SimDevice] = []
    @Published var selectedUDID: String = ""
    @Published var errorText: String?
    @Published var statusText: String?
    @Published var pasteURL: String = ""
    @Published var recentPaths: [String] = []
    @Published var isBusy = false
    @Published var xcrunMissing = false

    private let dropController = DropZoneController()

    init() {
        recentPaths = UserDefaults.standard.stringArray(forKey: Self.recentKey) ?? []
        selectedUDID = UserDefaults.standard.string(forKey: Self.pinnedKey) ?? ""
        dropController.onPaths = { [weak self] paths in
            Task { @MainActor in
                self?.handleDropped(paths: paths)
            }
        }
        refresh()
    }

    var selectedDevice: SimDevice? {
        devices.first { $0.udid == selectedUDID }
    }

    var showEmpty: Bool {
        !xcrunMissing && errorText == nil && devices.isEmpty
    }

    func refresh() {
        errorText = nil
        xcrunMissing = false
        if !Simctl.xcrunExists {
            xcrunMissing = true
            devices = []
            errorText = "Install Xcode Command Line Tools"
            return
        }
        isBusy = true
        Task.detached {
            do {
                let list = try Simctl.listDevices()
                await MainActor.run {
                    self.devices = list
                    self.resolveSelection()
                    self.isBusy = false
                    if list.isEmpty {
                        self.errorText = nil
                    }
                }
            } catch {
                await MainActor.run {
                    self.devices = []
                    self.isBusy = false
                    let message = error.localizedDescription
                    if !Simctl.xcrunExists || message == "Install Xcode Command Line Tools" {
                        self.xcrunMissing = true
                        self.errorText = "Install Xcode Command Line Tools"
                    } else {
                        self.errorText = message
                    }
                }
            }
        }
    }

    func pin(_ udid: String) {
        selectedUDID = udid
        UserDefaults.standard.set(udid, forKey: Self.pinnedKey)
    }

    func boot(_ device: SimDevice) {
        runAction("Boot \(device.name)") {
            try Simctl.boot(device.udid)
        }
    }

    func shutdown(_ device: SimDevice) {
        runAction("Shutdown \(device.name)") {
            try Simctl.shutdown(device.udid)
        }
    }

    func openSimulator() {
        runAction("Open Simulator") {
            try Simctl.openSimulatorApp()
        }
    }

    func showDropZone() {
        dropController.show()
    }

    func openPastedURL() {
        let trimmed = pasteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorText = "Paste a URL first"
            return
        }
        guard let udid = requireUDID() else { return }
        runAction("Open URL") {
            try Simctl.openURL(udid: udid, url: trimmed)
        }
    }

    func handleDropped(paths: [String]) {
        guard let udid = requireUDID() else { return }
        for path in paths {
            remember(path)
            runAction("Drop \(URL(fileURLWithPath: path).lastPathComponent)") {
                try Self.dispatchDrop(udid: udid, path: path)
            }
        }
    }

    func replay(path: String) {
        handleDropped(paths: [path])
    }

    private func requireUDID() -> String? {
        if !selectedUDID.isEmpty { return selectedUDID }
        errorText = "Select a simulator first"
        return nil
    }

    private func resolveSelection() {
        let pinned = UserDefaults.standard.string(forKey: Self.pinnedKey) ?? ""
        if !pinned.isEmpty, devices.contains(where: { $0.udid == pinned }) {
            selectedUDID = pinned
            return
        }
        if let booted = devices.first(where: { $0.state.caseInsensitiveCompare("Booted") == .orderedSame }) {
            selectedUDID = booted.udid
            return
        }
        selectedUDID = devices.first?.udid ?? ""
    }

    private func remember(_ path: String) {
        var next = recentPaths.filter { $0 != path }
        next.insert(path, at: 0)
        if next.count > 5 { next = Array(next.prefix(5)) }
        recentPaths = next
        UserDefaults.standard.set(next, forKey: Self.recentKey)
    }

    private func runAction(_ label: String, work: @escaping () throws -> Void) {
        isBusy = true
        errorText = nil
        Task.detached {
            do {
                try work()
                await MainActor.run {
                    self.statusText = "\(label) ok"
                    self.isBusy = false
                    self.refresh()
                }
            } catch {
                await MainActor.run {
                    self.errorText = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    nonisolated static func dispatchDrop(udid: String, path: String) throws {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic", "mov", "mp4"].contains(ext) {
            try Simctl.addMedia(udid: udid, path: path)
            return
        }
        if ext == "app" {
            try Simctl.install(udid: udid, path: path)
            return
        }
        if ext == "apns" {
            try Simctl.push(udid: udid, path: path)
            return
        }
        if ext == "json", jsonHasAps(path: path) {
            try Simctl.push(udid: udid, path: path)
            return
        }
        if let line = firstLine(path: path), line.lowercased().hasPrefix("http") {
            try Simctl.openURL(udid: udid, url: line)
            return
        }
        try Simctl.openURL(udid: udid, url: url.absoluteString)
    }

    nonisolated static func jsonHasAps(path: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return false }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return obj["aps"] != nil
    }

    nonisolated static func firstLine(path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 4096)
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.split(whereSeparator: \.isNewline).first.map { String($0).trimmingCharacters(in: .whitespaces) }
    }
}
