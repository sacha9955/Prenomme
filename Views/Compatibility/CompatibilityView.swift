import SwiftUI

struct CompatibilityView: View {
    @State private var lastName = ""
    @State private var candidates: [FirstName] = []
    @State private var scores: [Int: CompatibilityScore] = [:]
    @State private var showPaywall = false
    @State private var isLoading = false
    @State private var candidateGender: Gender? = nil

    private let purchase = PurchaseManager.shared
    private let analyzer = PhoneticAnalyzer.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !purchase.isPro {
                        compatibilityProBanner
                    }
                    lastNameField
                    if !lastName.trimmingCharacters(in: .whitespaces).isEmpty {
                        candidateSection
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Compatibilité")
            .navigationDestination(for: FirstName.self) { name in
                NameDetailView(name: name)
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .task(id: lastName) { await searchNames() }
        }
    }

    // MARK: — Pro banner

    private var compatibilityProBanner: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color(red: 0.79, green: 0.48, blue: 0.39))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scores détaillés avec Pro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Allitération, rythme, élision et suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(red: 0.79, green: 0.48, blue: 0.39).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Last name input

    private var lastNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nom de famille")
                .font(.headline)
                .padding(.horizontal)
            TextField("ex. Martin, Dubois…", text: $lastName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .padding(.horizontal)
        }
        .padding(.top, 16)
    }

    // MARK: — Candidate list

    private var filteredCandidates: [FirstName] {
        guard let g = candidateGender else { return candidates }
        return candidates.filter { $0.gender == g }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prénoms compatibles")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(filteredCandidates.count) prénom\(filteredCandidates.count > 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            candidateGenderFilter

            if !isLoading && filteredCandidates.isEmpty {
                Text(candidates.isEmpty
                     ? "Aucun prénom trouvé pour ce nom."
                     : "Aucun résultat pour ce filtre.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(filteredCandidates) { name in
                    if let s = scores[name.id] {
                        ScoreCard(
                            name: name,
                            score: s,
                            isPro: purchase.isPro,
                            onUpgrade: { showPaywall = true }
                        )
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private var candidateGenderFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                candidateChip(nil, label: "Tous")
                ForEach(Gender.allCases, id: \.rawValue) { g in
                    candidateChip(g, label: g.label)
                }
            }
            .padding(.horizontal)
        }
    }

    private func candidateChip(_ gender: Gender?, label: String) -> some View {
        Button {
            candidateGender = gender
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(candidateGender == gender ? candidateChipColor(gender) : Color(.systemGray5))
                .foregroundStyle(candidateGender == gender ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func candidateChipColor(_ gender: Gender?) -> Color {
        switch gender {
        case .female: Color(red: 0.85, green: 0.35, blue: 0.50)
        case .male:   Color(red: 0.30, green: 0.50, blue: 0.80)
        case .unisex: Color(red: 0.35, green: 0.60, blue: 0.35)
        case nil:     Color.accentColor
        }
    }

    // MARK: — Data

    private func searchNames() async {
        let ln = lastName.trimmingCharacters(in: .whitespaces)
        guard !ln.isEmpty else {
            candidates = []
            scores = [:]
            return
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        isLoading = true
        let result = await Task.detached(priority: .userInitiated) {
            let analyzer = PhoneticAnalyzer.shared
            let all = (try? NameDatabase.shared.all()) ?? []
            let scoredAll = all.map { ($0, analyzer.score(firstName: $0.name, lastName: ln)) }
            let top20 = scoredAll.sorted { $0.1.global > $1.1.global }.prefix(20)
            let top20Ids = Set(top20.map(\.0.id))
            let topUnisex = scoredAll
                .filter { $0.0.gender == .unisex && !top20Ids.contains($0.0.id) }
                .sorted { $0.1.global > $1.1.global }
                .prefix(5)
            let combined = Array(top20) + Array(topUnisex)
            var newScores: [Int: CompatibilityScore] = [:]
            for (name, s) in combined { newScores[name.id] = s }
            return (combined.map(\.0), newScores)
        }.value
        guard !Task.isCancelled else {
            isLoading = false
            return
        }
        candidates = result.0
        scores = result.1
        isLoading = false
    }
}

// MARK: — ScoreCard

private struct ScoreCard: View {
    let name: FirstName
    let score: CompatibilityScore
    let isPro: Bool
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if isPro {
                Divider()
                details
            } else {
                lockedBanner
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(genderColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(String(name.name.prefix(1)))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(genderColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.name)
                    .font(.headline)
                Text("\(name.name) \(score.lastName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(score.verdict)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(verdictColor)
                Text(String(format: "%.0f%%", score.global * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var details: some View {
        VStack(spacing: 10) {
            ScoreRow(label: "Allitération",
                     value: score.alliteration,
                     icon: "textformat.characters")
            ScoreRow(label: "Rythme",
                     value: score.rhythm,
                     icon: "waveform")
            HStack {
                Label("Élision", systemImage: "speaker.wave.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: score.elisionRisk ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(score.elisionRisk ? .orange : .green)
                Text(score.elisionRisk ? "Risque" : "OK")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(score.elisionRisk ? .orange : .green)
            }
            HStack {
                Label("Consonnes", systemImage: "bolt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: score.hardClash ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(score.hardClash ? .orange : .green)
                Text(score.hardClash ? "Choc" : "OK")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(score.hardClash ? .orange : .green)
            }
            HStack {
                Label("Rime finale", systemImage: "music.note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: score.endingRhyme ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(score.endingRhyme ? .orange : .green)
                Text(score.endingRhyme ? "Rime" : "OK")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(score.endingRhyme ? .orange : .green)
            }
        }
        .padding(14)
    }

    private var lockedBanner: some View {
        Button(action: onUpgrade) {
            HStack {
                Image(systemName: "lock.fill")
                Text("Scores détaillés — Pro")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(12)
            .foregroundStyle(.secondary)
            .background(Color(.systemGray6))
        }
        .buttonStyle(.plain)
    }

    private var genderColor: Color {
        switch name.gender {
        case .female: Color(red: 0.85, green: 0.35, blue: 0.50)
        case .male:   Color(red: 0.30, green: 0.50, blue: 0.80)
        case .unisex: Color(red: 0.35, green: 0.60, blue: 0.35)
        }
    }

    private var verdictColor: Color {
        switch score.verdict {
        case "Excellent": .green
        case "Bon":       Color(red: 0.3, green: 0.6, blue: 0.3)
        case "Moyen":     .orange
        default:          .red
        }
    }
}

private struct ScoreRow: View {
    let label: String
    let value: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.subheadline.weight(.semibold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * value)
                }
                .frame(height: 6)
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        switch value {
        case 0.7...: .green
        case 0.4...: .orange
        default:     .red
        }
    }
}
