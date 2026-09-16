import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: FunTheme.sectionSpacing) {
            HStack {
                Text("Simulator Drop")
                    .font(.headline)
                Spacer()
                if state.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Refresh") { state.refresh() }
                Button("Drop zone") { state.showDropZone() }
            }

            if let err = state.errorText, !err.isEmpty {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let status = state.statusText, !status.isEmpty {
                Text(status)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            if state.showEmpty {
                ExtraEmptyState(
                    title: "No simulators",
                    detail: "Boot a simulator, or install Xcode so simctl is available.",
                    actionTitle: "Refresh",
                    action: { state.refresh() }
                )
            } else if !state.devices.isEmpty {
                Picker("Device", selection: Binding(
                    get: { state.selectedUDID },
                    set: { state.pin($0) }
                )) {
                    ForEach(state.devices) { device in
                        Text(deviceLabel(device)).tag(device.udid)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
                        ForEach(state.devices) { device in
                            deviceRow(device)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            VStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
                Text("Open URL on simulator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("https://…", text: $state.pasteURL)
                        .textFieldStyle(.roundedBorder)
                    Button("Open") { state.openPastedURL() }
                        .disabled(state.selectedUDID.isEmpty)
                }
            }

            if !state.recentPaths.isEmpty {
                VStack(alignment: .leading, spacing: FunTheme.innerSpacing) {
                    Text("Recent drops")
                        .font(.headline)
                    ForEach(state.recentPaths, id: \.self) { path in
                        Button {
                            state.replay(path: path)
                        } label: {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                        .help(path)
                        .extraRowSurface()
                    }
                }
            }

            ExtraSettingsFooter()
        }
        .animation(reduceMotion ? nil : FunTheme.spring, value: state.devices.count)
        .animation(reduceMotion ? nil : FunTheme.spring, value: state.errorText)
        .animation(reduceMotion ? nil : FunTheme.spring, value: state.isBusy)
        .funPanel()
    }

    private func deviceLabel(_ device: SimDevice) -> String {
        "\(device.name) · \(device.runtime) · \(device.state)"
    }

    @ViewBuilder
    private func deviceRow(_ device: SimDevice) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                    Text("\(device.runtime) · \(device.state)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                Spacer()
            }
            HStack {
                if device.state.caseInsensitiveCompare("Booted") == .orderedSame {
                    Button("Shutdown") { state.shutdown(device) }
                } else {
                    Button("Boot") { state.boot(device) }
                        .disabled(!device.isAvailable && device.state.caseInsensitiveCompare("Booted") != .orderedSame)
                }
                Button("Open Simulator") { state.openSimulator() }
                Button(state.selectedUDID == device.udid ? "Selected" : "Select") {
                    state.pin(device.udid)
                }
                .disabled(state.selectedUDID == device.udid)
            }
            .controlSize(.small)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(state.selectedUDID == device.udid ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }
}
