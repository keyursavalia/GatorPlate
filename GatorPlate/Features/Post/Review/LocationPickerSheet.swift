import SwiftUI

/// Searchable campus buildings: "Nearby" (closest first, when the user's location is known), "All buildings"
/// (A-Z), and "Drop a pin on the map". The list is the accessible path; the map is optional.
struct LocationPickerSheet: View {
    let selected: PostLocation?
    /// The user's last fix, only to sort buildings by distance. Never stored.
    let userCoordinate: Coordinate?
    let onSelect: (PostLocation) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PinDropMapView(initial: selected?.coordinate) { location in
                            onSelect(location)
                            dismiss()
                        }
                    } label: {
                        Label("Drop a pin on the map", systemImage: "mappin.and.ellipse")
                    }
                    .accessibilityHint("Pick an exact spot on campus")
                }
                if !nearby.isEmpty {
                    Section("Nearby") {
                        ForEach(nearby) { building in buildingButton(building) }
                    }
                }
                Section("All buildings") {
                    if matches.isEmpty {
                        Text("No building matches \"\(query)\".")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(matches.sorted { $0.name < $1.name }) { building in buildingButton(building) }
                }
            }
            .searchable(text: $query, prompt: "Search buildings")
            .scrollDismissesKeyboard(.interactively)
            .environment(\.listAccent, Theme.Palette.accent)
            .navigationTitle("Where's the food?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func buildingButton(_ building: CampusBuilding) -> some View {
        Button {
            onSelect(.building(building))
            dismiss()
        } label: {
            row(for: building)
        }
        .foregroundStyle(Color.primary)
    }

    private func row(for building: CampusBuilding) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(building.name)
                if let distance = distanceText(to: building) {
                    Text(distance).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if case .building(let current) = selected, current == building {
                Image(systemName: "checkmark")
                    .foregroundStyle(Theme.Palette.accent)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected(building) ? .isSelected : [])
    }

    private func isSelected(_ building: CampusBuilding) -> Bool {
        if case .building(let current) = selected { return current == building }
        return false
    }

    private static let nearbyCount = 3

    private var matches: [CampusBuilding] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? CampusBuilding.all : CampusBuilding.all.filter {
            $0.name.localizedStandardContains(trimmed) || $0.shortName.localizedStandardContains(trimmed)
        }
    }

    /// The closest few, only when the user's location is known.
    private var nearby: [CampusBuilding] {
        guard let userCoordinate else { return [] }
        let sorted = matches.sorted {
            $0.coordinate.distance(to: userCoordinate) < $1.coordinate.distance(to: userCoordinate)
        }
        return Array(sorted.prefix(Self.nearbyCount))
    }

    private func distanceText(to building: CampusBuilding) -> String? {
        guard let userCoordinate else { return nil }
        let meters = Measurement(value: building.coordinate.distance(to: userCoordinate), unit: UnitLength.meters)
        return meters.formatted(.measurement(width: .abbreviated, usage: .road)) + " away"
    }
}

#Preview {
    LocationPickerSheet(selected: nil, userCoordinate: SFSUCampus.homeCoordinate) { _ in }
}
