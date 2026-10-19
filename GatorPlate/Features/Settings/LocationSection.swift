import SwiftUI

/// Settings > Location: one switch that follows iOS. Turning it on asks iOS (first time) or explains how to allow it
/// in iOS Settings; turning it off explains that iOS controls it. Approximate location offers precise once.
struct LocationSection: View {
    let access: LocationAccess

    @State private var prompt: LocationPrompt?

    var body: some View {
        Section {
            Toggle(isOn: isOnBinding) {
                ListRow(title: "Location", systemImage: "location")
            }
            if access.isApproximate {
                Button { access.requestPreciseLocation() } label: {
                    ListRow(title: "Use precise location", systemImage: "scope")
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text(footer)
        }
        .locationPromptAlert($prompt, access: access)
    }

    private var footer: String {
        switch access.authorization {
        case .denied: "Location is off for GatorPlate in iOS Settings."
        case .restricted: "Location is restricted on this iPhone."
        case .authorized(precise: false): "Approximate location is on, so distances may be off by a block or two."
        case .authorized(precise: true): "Shows how far food is and walking times. Only while the app is open, never saved."
        case .notDetermined: "Turn on to see how far food is and walking times."
        }
    }

    private var isOnBinding: Binding<Bool> {
        Binding(get: { access.isOn },
                set: { on in Task { prompt = await access.setOn(on) } })
    }
}
