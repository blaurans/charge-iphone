import Combine
import Foundation

@MainActor
final class ChargeModel: ObservableObject {
    static let packs = [
        StationPack(id: "blagnac", label: "Blagnac", refs: [1417, 1418]),
        StationPack(id: "st-martin", label: "Saint-Martin", refs: [1646, 1570])
    ]
    static let cadences = [
        Cadence(id: "1min", label: "1 min", seconds: 60),
        Cadence(id: "4min", label: "4 min", seconds: 240)
    ]

    @Published private(set) var stations: [StationStatus] = []
    @Published private(set) var nearbyStations: [NearbyStation] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingStations = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var stationOrigin = ""
    @Published private(set) var lastRefreshAt: Date?
    @Published private(set) var selectedRefs: [Int]
    @Published private(set) var cadenceID: String

    private let proxyURL = URL(string: "https://m.driveco.app/api/driveco")!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    private var mapCache: [NearbyStation] = []
    private var mapFetchedAt: Date?

    private static let refsKey = "charge.selectedStationRefs"
    private static let cadenceKey = "charge.cadence"

    init() {
        let storedRefs = UserDefaults.standard.array(forKey: Self.refsKey) as? [Int]
        selectedRefs = storedRefs?.isEmpty == false ? storedRefs! : Self.packs[0].refs
        let storedCadence = UserDefaults.standard.string(forKey: Self.cadenceKey) ?? "4min"
        cadenceID = Self.cadences.contains(where: { $0.id == storedCadence }) ? storedCadence : "4min"
        stations = selectedRefs.map { Self.placeholder(for: $0) }
    }

    var currentCadence: Cadence {
        Self.cadences.first(where: { $0.id == cadenceID }) ?? Self.cadences[1]
    }

    var selectedPack: StationPack? {
        Self.packs.first(where: { Set($0.refs) == Set(selectedRefs) })
    }

    var title: String {
        if let selectedPack { return selectedPack.label }
        if selectedRefs.count == 1, let station = stations.first { return shortName(station.name) }
        return "\(selectedRefs.count) stations personnalisées"
    }

    var totalAvailable: Int {
        stations.reduce(0) { $0 + (($1.error == nil) ? ($1.available ?? 0) : 0) }
    }

    var totalPlugs: Int {
        stations.reduce(0) { $0 + (($1.error == nil) ? ($1.total ?? 0) : 0) }
    }

    var countedStations: Int {
        stations.filter { $0.error == nil && $0.available != nil }.count
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var snapshots = Dictionary(uniqueKeysWithValues: stations.map { ($0.ref, $0) })
        var failures: [String] = []
        for (index, ref) in selectedRefs.enumerated() {
            if index > 0 {
                // Avoid sending a burst of requests to Driveco when a pack has
                // multiple stations. The site's watcher spaces these by 3 s.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
            }
            do {
                snapshots[ref] = try await fetchStation(ref: ref)
            } catch {
                var snapshot = snapshots[ref] ?? Self.placeholder(for: ref)
                snapshot.error = error.localizedDescription
                snapshots[ref] = snapshot
                failures.append("Station \(ref) : \(error.localizedDescription)")
            }
        }
        stations = selectedRefs.map { snapshots[$0] ?? Self.placeholder(for: $0) }
        lastRefreshAt = Date()
        errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    func selectPack(_ pack: StationPack) async {
        setStations(pack.refs)
        await refresh()
    }

    func selectCadence(_ cadence: Cadence) {
        cadenceID = cadence.id
        UserDefaults.standard.set(cadence.id, forKey: Self.cadenceKey)
    }

    func toggleStation(_ station: NearbyStation) async {
        var refs = selectedRefs
        if refs.contains(station.ref) {
            guard refs.count > 1 else {
                errorMessage = "Garde au moins une station sélectionnée."
                return
            }
            refs.removeAll { $0 == station.ref }
        } else {
            refs.append(station.ref)
        }
        setStations(refs)
        await refresh()
    }

    func loadStations(query: String, latitude: Double? = nil, longitude: Double? = nil) async {
        isLoadingStations = true
        defer { isLoadingStations = false }
        do {
            if mapCache.isEmpty || Date().timeIntervalSince(mapFetchedAt ?? .distantPast) > 900 {
                mapCache = try await fetchMap()
                mapFetchedAt = Date()
            }

            let origin: (latitude: Double, longitude: Double, label: String, fromDevice: Bool)
            if let latitude, let longitude {
                origin = (latitude, longitude, "ta position", true)
            } else if let pack = selectedPack?.id {
                let point = pack == "st-martin" ? (43.611715, 1.372879) : (43.620030, 1.386557)
                origin = (point.0, point.1, selectedPack?.label ?? "Blagnac", false)
            } else {
                origin = (43.620030, 1.386557, "Blagnac", false)
            }

            stationOrigin = origin.label
            nearbyStations = mapCache
                .filter { query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    $0.name.localizedStandardContains(query) || ($0.address ?? "").localizedStandardContains(query) }
                .map { station in
                    NearbyStation(ref: station.ref,
                                  name: station.name,
                                  address: station.address,
                                  latitude: station.latitude,
                                  longitude: station.longitude,
                                  isOpen: station.isOpen,
                                  available: station.available,
                                  total: station.total,
                                  distanceM: distance(from: origin, to: station))
                }
                .sorted {
                    if let left = $0.distanceM, let right = $1.distanceM { return left < right }
                    if $0.distanceM != nil { return true }
                    if $1.distanceM != nil { return false }
                    return $0.name.localizedCompare($1.name) == .orderedAscending
                }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            if !mapCache.isEmpty {
                // Keep a previously loaded map available if Driveco is offline.
                nearbyStations = mapCache
            }
        }
    }

    private func setStations(_ refs: [Int]) {
        selectedRefs = refs
        UserDefaults.standard.set(refs, forKey: Self.refsKey)
        let old = Dictionary(uniqueKeysWithValues: stations.map { ($0.ref, $0) })
        stations = refs.map { old[$0] ?? Self.placeholder(for: $0) }
        errorMessage = nil
    }

    private func fetchStation(ref: Int) async throws -> StationStatus {
        let station: DrivecoStation = try await proxyCall(endpoint: "/api/station/\(ref)")
        guard let points = station.chargePoints else {
            throw ClientError.message("Réponse Driveco inattendue pour la station \(ref).")
        }
        let detail = (points.details ?? []).map { point in
            let rawID = point.chargePointId ?? ""
            return ChargePoint(status: point.status,
                               box: point.chargeBoxName,
                               slot: rawID.split(separator: "*").last.map(String.init) ?? rawID)
        }
        let sumTotal = (points.available?.value ?? 0) + (points.occupied?.value ?? 0) + (points.unavailable?.value ?? 0)
        return StationStatus(ref: ref,
                             name: station.name ?? "Station \(ref)",
                             address: station.address,
                             isOpen: station.isOpen ?? true,
                             available: points.available?.value,
                             total: points.total?.value ?? (sumTotal > 0 ? sumTotal : nil),
                             points: detail,
                             fetchedAt: Date(),
                             error: nil)
    }

    private func fetchMap() async throws -> [NearbyStation] {
        let entries: [DrivecoMapStation] = try await proxyCall(endpoint: "/api/map", timeout: 60)
        return entries.compactMap { entry in
            guard let ref = entry.ref?.value, ref > 0 else { return nil }
            let counts = entry.chargePoints
            let available = counts?.available?.value ?? 0
            let occupied = counts?.occupied?.value ?? 0
            let unavailable = counts?.unavailable?.value ?? 0
            return NearbyStation(ref: ref,
                                 name: entry.name ?? "Station \(ref)",
                                 address: entry.address,
                                 latitude: entry.latitude?.value,
                                 longitude: entry.longitude?.value,
                                 isOpen: entry.isOpen ?? true,
                                 available: available,
                                 total: available + occupied + unavailable,
                                 distanceM: nil)
        }
    }

    private func proxyCall<T: Decodable>(endpoint: String, timeout: TimeInterval = 30) async throws -> T {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("fr", forHTTPHeaderField: "lang")
        request.setValue("Charge-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "endpoint": endpoint,
            "method": "GET",
            "params": [String: String]()
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ClientError.message("Réponse réseau invalide.")
        }
        guard (200..<300).contains(response.statusCode) else {
            throw ClientError.message("Driveco a renvoyé une erreur HTTP \(response.statusCode).")
        }
        if let apiError = try? decoder.decode(DrivecoProxyError.self, from: data),
           let code = apiError.statusCode?.value, code >= 400 {
            throw ClientError.message(apiError.statusMessage ?? "Erreur API Driveco (\(code)).")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ClientError.message("Réponse Driveco illisible : \(error.localizedDescription)")
        }
    }

    private func distance(from origin: (latitude: Double, longitude: Double, label: String, fromDevice: Bool), to station: NearbyStation) -> Int? {
        guard let latitude = station.latitude, let longitude = station.longitude else { return nil }
        let radius = 6_371_000.0
        let p1 = origin.latitude * .pi / 180
        let p2 = latitude * .pi / 180
        let dp = (latitude - origin.latitude) * .pi / 180
        let dl = (longitude - origin.longitude) * .pi / 180
        let rawA = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        let a = min(1, max(0, rawA))
        return Int((radius * 2 * atan2(sqrt(a), sqrt(1 - a))).rounded())
    }

    private static func placeholder(for ref: Int) -> StationStatus {
        StationStatus(ref: ref, name: "Station \(ref)", address: nil, isOpen: true,
                      available: nil, total: nil, points: [], fetchedAt: nil, error: nil)
    }

    private func shortName(_ name: String) -> String {
        name.replacingOccurrences(of: " - powered by DRIVECO", with: "")
    }
}

private enum ClientError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        if case let .message(message) = self { return message }
        return nil
    }
}
