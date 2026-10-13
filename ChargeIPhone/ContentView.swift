import SwiftUI

private enum Palette {
    static let background = Color(red: 13 / 255, green: 17 / 255, blue: 23 / 255)
    static let card = Color(red: 22 / 255, green: 27 / 255, blue: 34 / 255)
    static let line = Color(red: 33 / 255, green: 38 / 255, blue: 45 / 255)
    static let muted = Color(red: 139 / 255, green: 148 / 255, blue: 158 / 255)
    static let green = Color(red: 63 / 255, green: 185 / 255, blue: 80 / 255)
    static let red = Color(red: 248 / 255, green: 81 / 255, blue: 73 / 255)
    static let amber = Color(red: 210 / 255, green: 153 / 255, blue: 34 / 255)
}

struct ContentView: View {
    @EnvironmentObject private var model: ChargeModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showStations = false

    private var accent: Color {
        guard model.countedStations > 0 else { return Palette.muted }
        if model.totalAvailable == 0 { return Palette.red }
        if model.totalAvailable >= 2 || Double(model.totalAvailable) / Double(max(model.totalPlugs, 1)) >= 0.5 {
            return Palette.green
        }
        return Palette.amber
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    dashboardContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showStations) {
                StationPickerView()
                    .environmentObject(model)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .task(id: model.cadenceID) {
                if model.lastRefreshAt == nil { await model.refresh() }
                while !Task.isCancelled {
                    let delay = UInt64(model.currentCadence.seconds) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    guard !Task.isCancelled else { return }
                    if scenePhase == .active { await model.refresh() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let age = Date().timeIntervalSince(model.lastRefreshAt ?? .distantPast)
                if age >= Double(model.currentCadence.seconds) {
                    Task { await model.refresh() }
                }
            }
        }
        .tint(Palette.green)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(model.errorMessage == nil ? Palette.green : Palette.amber)
                .frame(width: 9, height: 9)
            Text(model.isRefreshing ? "interrogation de Driveco…" : "connexion directe à Driveco")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(model.errorMessage == nil ? Palette.green : Palette.amber)
            Spacer()
            Button {
                Task { await model.refresh() }
            } label: {
                Image(systemName: model.isRefreshing ? "arrow.2.circlepath" : "arrow.clockwise")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
            }
            .disabled(model.isRefreshing)
            .accessibilityLabel("Interroger Driveco maintenant")
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        Text(model.title)
            .font(.system(size: 19, weight: .semibold))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

        cadencePicker

        VStack(spacing: 12) {
            Text(model.countedStations == 0 ? "–" : "\(model.totalAvailable)")
                .font(.system(size: 112, weight: .bold, design: .rounded))
                .tracking(-7)
                .foregroundStyle(accent)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Text(model.totalPlugs > 0 ? "PLACES LIBRES SUR \(model.totalPlugs)" : "PLACES LIBRES")
                .font(.system(size: 12, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
            availabilityBar
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)

        if model.stations.contains(where: { $0.isOpen == false }) {
            Label("Une station est indiquée comme fermée", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.amber)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        VStack(spacing: 0) {
            ForEach(model.stations) { station in stationCard(station) }
        }

        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(Palette.amber)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
        }

        TimelineView(.periodic(from: .now, by: 20)) { context in
            Text(refreshSummary(at: context.date))
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        packPicker

        Button { showStations = true } label: {
            Label("Choisir station par station", systemImage: "arrow.left.arrow.right")
        }
        .buttonStyle(SecondaryButtonStyle())

        Text("Les relevés automatiques s’arrêtent quand iOS suspend l’app. L’API Driveco utilisée n’est pas publique ni documentée.")
            .font(.system(size: 11))
            .foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)
            .padding(.top, 3)
    }

    private var cadencePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ACTUALISATION · APP OUVERTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Palette.muted)
                .padding(.leading, 4)
            Menu {
                ForEach(ChargeModel.cadences) { cadence in
                    Button {
                        model.selectCadence(cadence)
                    } label: {
                        let cost = cadence.requestsPerDay(stationCount: model.selectedRefs.count)
                        if cadence.id == model.cadenceID {
                            Label("Toutes les \(cadence.label) · \(cost) req./jour", systemImage: "checkmark")
                        } else {
                            Text("Toutes les \(cadence.label) · \(cost) req./jour")
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Toutes les ~\(model.currentCadence.label)")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.bold()).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 52)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
            }
        }
    }

    private var packPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STATIONS SUIVIES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Palette.muted)
                .padding(.leading, 4)
            Menu {
                ForEach(ChargeModel.packs) { pack in
                    Button {
                        Task { await model.selectPack(pack) }
                    } label: {
                        if model.selectedPack?.id == pack.id {
                            Label(pack.label, systemImage: "checkmark")
                        } else {
                            Text(pack.label)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(model.selectedPack?.label ?? "Personnalisé · \(model.selectedRefs.map(String.init).joined(separator: ", "))")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.bold()).foregroundStyle(Palette.muted)
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 52)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line, lineWidth: 1))
            }
            .disabled(model.isRefreshing)
        }
    }

    private var availabilityBar: some View {
        HStack(spacing: 5) {
            ForEach(model.stations.flatMap(\.points)) { point in
                Capsule().fill(pointColor(point.status)).frame(height: 9)
            }
        }
    }

    private func stationCard(_ station: StationStatus) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(shortName(station.name))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text(station.error == nil ? (station.available.map(String.init) ?? "–") : "!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(station.error != nil ? Palette.amber : ((station.available ?? 0) > 0 ? Palette.green : Palette.red))
            }
            if let error = station.error {
                Text(error).font(.system(size: 12)).foregroundStyle(Palette.amber)
            } else if let available = station.available, let total = station.total {
                Text("\(available)/\(total) points · \(ageText(since: station.fetchedAt))")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            } else {
                Text("en attente du premier relevé").font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            if !station.points.isEmpty { pointBadges(station.points) }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }

    private func pointBadges(_ points: [ChargePoint]) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) {
                ForEach(points) { point in pointBadge(point) }
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(points) { point in pointBadge(point) }
            }
        }
    }

    private func pointBadge(_ point: ChargePoint) -> some View {
        HStack(spacing: 5) {
            Circle().fill(pointColor(point.status)).frame(width: 7, height: 7)
            Text([point.box, point.slot].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(pointColor(point.status))
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Palette.line, in: RoundedRectangle(cornerRadius: 6))
    }

    private func refreshSummary(at now: Date) -> String {
        guard let last = model.lastRefreshAt else {
            return model.isRefreshing ? "Premier relevé en cours…" : "Pas encore de relevé"
        }
        let age = max(0, Int(now.timeIntervalSince(last)))
        return model.isRefreshing ? "Relevé Driveco en cours… · dernier relevé \(ageText(seconds: age))" : "Dernier relevé : \(ageText(seconds: age)) · auto tant que l’app reste active"
    }

    private func ageText(since date: Date?) -> String {
        guard let date else { return "jamais relevée" }
        return ageText(seconds: max(0, Int(Date().timeIntervalSince(date))))
    }

    private func ageText(seconds: Int) -> String {
        if seconds < 60 { return "il y a \(seconds) s" }
        if seconds < 3600 { return "il y a \(Int((Double(seconds) / 60).rounded())) min" }
        return "il y a \(Int((Double(seconds) / 3600).rounded())) h"
    }

    private func shortName(_ name: String) -> String {
        name.replacingOccurrences(of: " - powered by DRIVECO", with: "")
    }

    private func pointColor(_ status: String?) -> Color {
        return switch status {
        case "available": Palette.green
        case "occupied": Palette.red
        case "unavailable": Color(red: 58 / 255, green: 65 / 255, blue: 73 / 255)
        default: Palette.muted
        }
    }
}

private struct StationPickerView: View {
    @EnvironmentObject private var model: ChargeModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationManager()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("Nom, ville, borne…", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    Button { location.locate() } label: {
                        Label("Ici", systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.green)
                }
                .padding(12)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 16).padding(.vertical, 10)

                if let message = location.statusMessage {
                    Text(message).font(.footnote).foregroundStyle(Palette.amber).padding(.horizontal, 16)
                }
                if let error = model.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Palette.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.bottom, 6)
                }

                List {
                    ForEach(model.nearbyStations) { station in stationRow(station) }
                        .listRowBackground(Palette.background)
                        .listRowSeparatorTint(Palette.line)
                    if model.isLoadingStations && model.nearbyStations.isEmpty {
                        HStack { ProgressView().tint(Palette.green); Text("Chargement de la carte Driveco…") }
                            .foregroundStyle(Palette.muted).listRowBackground(Palette.background)
                    } else if model.nearbyStations.isEmpty {
                        Text("Aucune station trouvée.")
                            .foregroundStyle(Palette.muted).listRowBackground(Palette.background)
                    }
                }
                .listStyle(.plain)

                Text("\(model.nearbyStations.count) stations · tri depuis \(model.stationOrigin.isEmpty ? "le site du pack" : model.stationOrigin)")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .background(Palette.background)
            .navigationTitle("Stations suivies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Terminé") { dismiss() } }
            }
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                await loadStations()
            }
            .onChange(of: location.coordinates) { _, _ in Task { await loadStations() } }
        }
    }

    private func stationRow(_ station: NearbyStation) -> some View {
        let selected = model.selectedRefs.contains(station.ref)
        return Button {
            Task {
                await model.toggleStation(station)
                if model.errorMessage == nil { dismiss() }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.name.replacingOccurrences(of: " - powered by DRIVECO", with: ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(station.isOpen ? .white : Palette.muted)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 5) {
                        if let address = station.address { Text(address) }
                        if let distance = station.distanceM {
                            Text("·")
                            Text(distance < 950 ? "\(Int((Double(distance) / 10).rounded()) * 10) m" : String(format: "%.1f km", Double(distance) / 1000))
                        }
                    }
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                if let available = station.available {
                    Text("\(available)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(available > 0 ? Palette.green : Palette.muted)
                        .frame(minWidth: 34, minHeight: 34)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 10))
                }
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Palette.green : Palette.muted)
                    .font(.system(size: 20))
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isRefreshing)
    }

    private func loadStations() async {
        await model.loadStations(query: query,
                                 latitude: location.coordinates?.latitude,
                                 longitude: location.coordinates?.longitude)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
