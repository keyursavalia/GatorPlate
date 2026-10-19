import SwiftUI

extension View {
    /// Shows `prompt` as a system alert: Open Settings / Not now, or OK when the student can't change it.
    func locationPromptAlert(_ prompt: Binding<LocationPrompt?>, access: LocationAccess) -> some View {
        modifier(LocationPromptAlert(prompt: prompt, access: access))
    }
}

private struct LocationPromptAlert: ViewModifier {
    @Binding var prompt: LocationPrompt?
    let access: LocationAccess

    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        content.alert(prompt?.title ?? "", isPresented: isPresented, presenting: prompt) { prompt in
            if prompt == .restricted {
                Button("OK", role: .cancel) {}
            } else {
                Button("Open Settings") {
                    if prompt == .turnOn { access.willOpenSystemSettings() }
                    if let url = AppSettingsURL.url { openURL(url) }
                }
                Button(prompt == .turnOn ? "Not now" : "Cancel", role: .cancel) {}
            }
        } message: { prompt in
            Text(prompt.message)
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } })
    }
}
