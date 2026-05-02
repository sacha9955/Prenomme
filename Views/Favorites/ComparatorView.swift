import SwiftUI

struct ComparatorView: View {
    let names: [FirstName]

    @State private var lastName = ""
    @State private var selectedId: Int? = nil
    @Environment(\.dismiss) private var dismiss

    private let analyzer = PhoneticAnalyzer.shared

    private var displayNames: [FirstName] { Array(names.prefix(4)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    lastNameField
                    if displayNames.isEmpty {
                        emptyState
                    } else {
                        table
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Comparer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: — Last name input

    private var lastNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nom de famille (optionnel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            TextField("ex. Martin, Dubois…", text: $lastName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Color.appSurfaceElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.appHairline, lineWidth: 0.5)
                )
                .padding(.horizontal)
        }
        .padding(.top, 16)
    }

    // MARK: — Table

    private var table: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                labelColumn
                ForEach(displayNames) { name in
                    valueColumn(for: name)
                }
            }
            .padding(.horizontal)
        }
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // header spacer matching name header height
            Color.clear
                .frame(width: 110, height: 92)

            ForEach(Row.allCases, id: \.self) { row in
                Text(row.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, height: rowHeight(row), alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(row.isAlt ? Color.appSurface.opacity(0.5) : .clear)
            }

            // "Choisir" button spacer
            Color.clear.frame(width: 110, height: 56)
        }
    }

    private func valueColumn(for name: FirstName) -> some View {
        let isSelected = selectedId == name.id
        let score: CompatibilityScore? = lastName.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : analyzer.score(firstName: name.name, lastName: lastName.trimmingCharacters(in: .whitespaces))

        return VStack(alignment: .center, spacing: 0) {
            nameHeader(name, isSelected: isSelected)

            ForEach(Row.allCases, id: \.self) { row in
                Text(rowValue(row, name: name, score: score))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(row == .meaning ? 3 : 2)
                    .frame(width: 120, height: rowHeight(row))
                    .padding(.horizontal, 4)
                    .background(row.isAlt ? Color.appSurface.opacity(0.5) : .clear)
                    .foregroundStyle(rowColor(row, name: name, score: score))
            }

            Button {
                selectedId = isSelected ? nil : name.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    Text(isSelected ? "Sélectionné" : "Choisir")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(width: 120, height: 44)
                .background(isSelected ? genderColor(name).opacity(0.15) : Color.appSurface)
                .foregroundStyle(isSelected ? genderColor(name) : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? genderColor(name) : Color(.systemGray4), lineWidth: isSelected ? 2 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(4)
    }

    private func nameHeader(_ name: FirstName, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(genderColor(name).opacity(isSelected ? 0.25 : 0.12))
                    .frame(width: 48, height: 48)
                Text(String(name.name.prefix(1)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(genderColor(name))
            }
            Text(name.name)
                .font(.headline)
                .lineLimit(1)
        }
        .frame(width: 120, height: 92)
        .padding(.top, 6)
    }

    // MARK: — Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 44))
                .foregroundStyle(.quaternary)
            Text("Aucun prénom à comparer")
                .font(.headline)
            Text("Ajoutez des prénoms en favoris pour les comparer ici.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: — Row data

    private enum Row: CaseIterable {
        case gender, origin, meaning, syllables, rankFR, rankUS, phonetic

        var label: String {
            switch self {
            case .gender:   "Genre"
            case .origin:   "Origine"
            case .meaning:  "Signification"
            case .syllables: "Syllabes"
            case .rankFR:   "Popularité FR"
            case .rankUS:   "Popularité US"
            case .phonetic: "Score phonétique"
            }
        }

        var isAlt: Bool {
            switch self {
            case .origin, .syllables, .rankUS: true
            default: false
            }
        }
    }

    private func rowHeight(_ row: Row) -> CGFloat {
        row == .meaning ? 72 : 44
    }

    private func rowValue(_ row: Row, name: FirstName, score: CompatibilityScore?) -> String {
        switch row {
        case .gender:
            switch name.gender {
            case .female: "♀ Féminin"
            case .male:   "♂ Masculin"
            case .unisex: "⚥ Mixte"
            }
        case .origin:
            name.origin.isEmpty ? "—" : name.origin
        case .meaning:
            name.meaning.isEmpty ? "—" : name.meaning
        case .syllables:
            "\(name.syllables)"
        case .rankFR:
            name.popularityRankFR.map { "#\($0)" } ?? "—"
        case .rankUS:
            name.popularityRankUS.map { "#\($0)" } ?? "—"
        case .phonetic:
            score.map { String(format: "%.0f%%", $0.global * 100) } ?? "—"
        }
    }

    private func rowColor(_ row: Row, name: FirstName, score: CompatibilityScore?) -> Color {
        guard row == .phonetic, let s = score else { return .primary }
        switch s.global {
        case 0.8...: return .green
        case 0.6...: return Color(red: 0.3, green: 0.6, blue: 0.3)
        case 0.4...: return .orange
        default:     return .red
        }
    }

    // MARK: — Helpers

    private func genderColor(_ name: FirstName) -> Color {
        switch name.gender {
        case .female: Color.genderFemale
        case .male:   Color.genderMale
        case .unisex: Color.genderUnisex
        }
    }
}
