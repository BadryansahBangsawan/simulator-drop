import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError = ""

    var body: some View {
        Form {
            Section("Simulator") {
                if let selected = state.selectedDevice {
                    Text("Pinned: \(selected.name)")
                    Text(selected.udid)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("No device pinned")
                        .foregroundStyle(.secondary)
                }
                Button("Clear pin") {
                    UserDefaults.standard.removeObject(forKey: AppState.pinnedKey)
                    state.selectedUDID = ""
                    state.refresh()
                }
            }
            Section("Login") {
                Toggle("Open at Login", isOn: Binding(
                    get: { openAtLogin },
                    set: { toggleLogin($0) }
                ))
                if !loginError.isEmpty {
                    Label(loginError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: FunTheme.panelWidth)
        .padding(12)
        .onAppear {
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func toggleLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = ""
        } catch {
            loginError = error.localizedDescription
        }
        openAtLogin = SMAppService.mainApp.status == .enabled
    }
}
