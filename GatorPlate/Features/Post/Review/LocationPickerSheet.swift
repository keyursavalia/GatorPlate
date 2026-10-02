import MapKit
import SwiftUI

/// Searchable list of campus buildings, plus an optional pin drop inside the campus region.
struct LocationPickerSheet: View {
    let viewModel: ReviewViewModel

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var buildings: [CampusBuilding] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return CampusBuildings.all }
        return CampusBuildings.all.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.shortName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PinDropView { coordinate in
                            let accepted = viewModel.dropPin(coordinate)
                            if accepted { dismiss() }
                            return accepted
                        }
                    } label: {
                        Label("Drop pin on map", systemImage: "mappin.and.ellipse")
                            .frame(minHeight: Theme.minTapTarget)
                    }
                    .accessibilityHint("Pick a spot on the campus map instead of a building")
                } footer: {
                    Text("Pins must be inside the SFSU campus.")
                }
                Section("Buildings") {
                    ForEach(buildings) { building in
                        Button {
                            viewModel.selectBuilding(building.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(building.name).foregroundStyle(.primary)
                                    if building.shortName != building.name {
                                        Text(building.shortName).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if viewModel.draft.buildingId == building.id {
                                    Image(systemName: "checkmark").foregroundStyle(Color.brandPurple)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: Theme.minTapTarget)
                        }
                        .accessibilityValue(viewModel.draft.buildingId == building.id ? "Selected" : "")
                    }
                    if buildings.isEmpty {
                        Text("No buildings match \"\(searchText)\".")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search buildings")
            .navigationTitle("Where is the food?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

/// Campus-locked map: tap to place a pin, then confirm. Taps outside the campus region are refused.
private struct PinDropView: View {
    /// Returns false when the coordinate is rejected.
    let onConfirm: (Coordinate) -> Bool

    @State private var candidate: Coordinate?
    @State private var message: String?

    var body: some View {
        MapReader { proxy in
            Map(initialPosition: .camera(SFSUCampus.overviewCamera), bounds: SFSUCampus.cameraBounds) {
                if let candidate {
                    Marker("Food here", systemImage: "fork.knife", coordinate: candidate.clCoordinate)
                        .tint(Color.brandPurple)
                }
            }
            .onTapGesture(coordinateSpace: .local) { point in
                guard let tapped = proxy.convert(point, from: .local) else { return }
                let coordinate = Coordinate(tapped)
                if SFSUCampus.contains(coordinate) {
                    candidate = coordinate
                    message = nil
                } else {
                    candidate = nil
                    message = "That spot is off campus. Tap inside the campus map."
                }
            }
        }
        .accessibilityLabel("Campus map")
        .accessibilityHint("Tap to place a pin. To choose by name instead, go back and pick a building.")
        .navigationTitle("Drop a pin")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.s) {
                if let message { Banner(kind: .warning, message: message) }
                PrimaryButton(title: candidate == nil ? "Tap the map to place a pin" : "Use this spot") {
                    if let candidate, !onConfirm(candidate) {
                        message = "That spot is off campus. Tap inside the campus map."
                    }
                }
                .disabled(candidate == nil)
                .opacity(candidate == nil ? 0.4 : 1)
            }
            .padding(Theme.Spacing.l)
            .background(.bar)
        }
    }
}
