import SwiftUI

struct FilterSheet: View {
    @Binding var filter: NameFilter
    @Environment(\.dismiss) private var dismiss
    @State private var local: NameFilter

    private let allOrigins = NameDatabase.shared.allOrigins
    private let syllableOptions: [(Int?, String)] = [
        (nil, "Tous"),
        (1, "1"),
        (2, "2"),
        (3, "3"),
        (4, "4"),
        (5, "5+"),
    ]
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    init(filter: Binding<NameFilter>) {
        _filter = filter
        _local = State(initialValue: filter.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                genderSection
                originsSection
                syllablesSection
                initialLetterSection
                sortSection
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Réinitialiser") {
                        local = NameFilter()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        filter = local
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: — Sections

    private var genderSection: some View {
        Section("Genre") {
            Picker("Genre", selection: $local.gender) {
                Text("Tous").tag(Gender?.none)
                Text("Féminin").tag(Gender?.some(.female))
                Text("Masculin").tag(Gender?.some(.male))
                Text("Mixte").tag(Gender?.some(.unisex))
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
        }
    }

    private var originsSection: some View {
        Section("Origines") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allOrigins, id: \.self) { origin in
                        let selected = local.origins.contains(origin)
                        Button {
                            if selected {
                                local.origins.removeAll { $0 == origin }
                            } else {
                                local.origins.append(origin)
                            }
                        } label: {
                            Text(origin)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(selected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private var syllablesSection: some View {
        Section("Syllabes") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(syllableOptions, id: \.1) { value, label in
                        let selected = local.syllables == value
                        Button {
                            local.syllables = value
                        } label: {
                            Text(label)
                                .font(.subheadline)
                                .frame(minWidth: 44)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(selected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private var initialLetterSection: some View {
        Section("Initiale") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        local.initialLetter = nil
                    } label: {
                        Text("Toutes")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(local.initialLetter == nil ? Color.accentColor : Color(.systemGray5))
                            .foregroundStyle(local.initialLetter == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(alphabet, id: \.self) { letter in
                        let selected = local.initialLetter == letter
                        Button {
                            local.initialLetter = selected ? nil : letter
                        } label: {
                            Text(String(letter))
                                .font(.subheadline)
                                .frame(width: 36)
                                .padding(.vertical, 6)
                                .background(selected ? Color.accentColor : Color(.systemGray5))
                                .foregroundStyle(selected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
    }

    private var sortSection: some View {
        Section("Tri") {
            Toggle("Par popularité en France", isOn: $local.sortByPopularity)
        }
    }
}
