import SwiftUI

/// Searchable list of campus buildings, plus "Drop a pin on the map". The list is the accessible path;
/// the map is optional.
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
                Section("Buildings") {
                    if buildings.isEmpty {
                        Text("No building matches \"\(query)\".")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(buildings) { building in
                        Button {
                            onSelect(.building(building))
                            dismiss()
                        } label: {
                            row(for: building)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search buildings")
            .navigationTitle("Where's the food?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
                    .foregroundStyle(Theme.Palette.brandPurple)
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

    /// Nearest first when the user's location is known, otherwise alphabetical.
    private var buildings: [CampusBuilding] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matches = trimmed.isEmpty ? CampusBuilding.all : CampusBuilding.all.filter {
            $0.name.localizedStandardContains(trimmed) || $0.shortName.localizedStandardContains(trimmed)
        }
        guard let userCoordinate else { return matches.sorted { $0.name < $1.name } }
        return matches.sorted { $0.coordinate.distance(to: userCoordinate) < $1.coordinate.distance(to: userCoordinate) }
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
