import Foundation

struct ChargePoint: Identifiable {
    let status: String?
    let box: String?
    let slot: String?

    var id: String { "\(box ?? "")-\(slot ?? "")-\(status ?? "")" }
}

struct StationStatus: Identifiable {
    let ref: Int
    var name: String
    var address: String?
    var isOpen: Bool
    var available: Int?
    var total: Int?
    var points: [ChargePoint]
    var fetchedAt: Date?
    var error: String?

    var id: Int { ref }
}

struct StationPack: Identifiable {
    let id: String
    let label: String
    let refs: [Int]
}

struct Cadence: Identifiable {
    let id: String
    let label: String
    let seconds: Int

    func requestsPerDay(stationCount: Int) -> Int {
        Int((Double(stationCount) * 86_400 / Double(seconds)).rounded())
    }
}

struct NearbyStation: Identifiable {
    let ref: Int
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let isOpen: Bool
    let available: Int?
    let total: Int?
    let distanceM: Int?

    var id: Int { ref }
}

// DTOs for the unofficial Driveco mobile-app proxy. The app deliberately
// decodes only the fields it needs and ignores the rest of the response.
struct DrivecoStation: Decodable {
    let name: String?
    let address: String?
    let latitude: FlexibleDouble?
    let longitude: FlexibleDouble?
    let isOpen: Bool?
    let chargePoints: DrivecoChargePoints?

    enum CodingKeys: String, CodingKey {
        case name, address, latitude, longitude, isOpen, chargePoints
    }
}

struct DrivecoChargePoints: Decodable {
    let available: FlexibleInt?
    let total: FlexibleInt?
    let occupied: FlexibleInt?
    let unavailable: FlexibleInt?
    let details: [DrivecoPoint]?
}

struct DrivecoPoint: Decodable {
    let chargePointId: String?
    let chargeBoxName: String?
    let status: String?
}

struct DrivecoMapStation: Decodable {
    let ref: FlexibleInt?
    let name: String?
    let address: String?
    let latitude: FlexibleDouble?
    let longitude: FlexibleDouble?
    let isOpen: Bool?
    let chargePoints: DrivecoMapCounts?

    enum CodingKeys: String, CodingKey {
        case ref, name = "nom", address = "adresse", latitude, longitude, isOpen, chargePoints
    }
}

struct DrivecoMapCounts: Decodable {
    let available: FlexibleInt?
    let occupied: FlexibleInt?
    let unavailable: FlexibleInt?
}

struct DrivecoProxyError: Decodable {
    let statusCode: FlexibleInt?
    let statusMessage: String?
}

struct FlexibleInt: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int.self) {
            value = number
        } else if let text = try? container.decode(String.self), let number = Int(text) {
            value = number
        } else if let number = try? container.decode(Double.self) {
            value = Int(number)
        } else {
            throw DecodingError.typeMismatch(Int.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected an integer or numeric string"))
        }
    }
}

struct FlexibleDouble: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
        } else if let text = try? container.decode(String.self), let number = Double(text) {
            value = number
        } else {
            throw DecodingError.typeMismatch(Double.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected a number or numeric string"))
        }
    }
}
