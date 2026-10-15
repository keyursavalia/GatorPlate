import SwiftUI

/// Searchable campus building list with checkmarks, for alert filters (up to `AppConfig.alertFilterMaxPlaces`).
struct PlacesPickerSheet: View {
    let onDone: ([String]) -> Void

    @State private var selection: [String]
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    init(selected: [String], onDone: @escaping ([String]) -> Void) {
        self.onDone = onDone
        _selection = State(initialValue: selected)
    }

    var body: some View {
        NavigationStack {
            List(buildings) { building in
                let isSelected = selection.contains(building.id)
                Button {
                    if isSelected {
                        selection.removeAll { $0 == building.id }
                    } else if selection.count < AppConfig.alertFilterMaxPlaces {
                        selection.append(building.id)
                    }
                } label: {
                    HStack {
                        Text(building.name).foregroundStyle(.primary)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.Palette.brandPurple)
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(.rect)
                }
                .frame(minHeight: Theme.Size.minTapTarget)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            .searchable(text: $query, prompt: "Search buildings")
            .navigationTitle("Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(selection)
                        dismiss()
                    }
                }
            }
        }
    }

    private var buildings: [CampusBuilding] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let matches = trimmed.isEmpty ? CampusBuilding.all : CampusBuilding.all.filter {
            $0.name.localizedStandardContains(trimmed) || $0.shortName.localizedStandardContains(trimmed)
        }
        return matches.sorted { $0.name < $1.name }
    }
}
