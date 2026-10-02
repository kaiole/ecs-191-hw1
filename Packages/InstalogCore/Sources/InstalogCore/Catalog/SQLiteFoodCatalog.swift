import Foundation

/// Read-only search over the bundled USDA catalog built by `tools/build_catalog.py`.
public actor SQLiteFoodCatalog: FoodCatalog {
    public nonisolated let sourceDescription: String

    private let connection: SQLiteConnection
    private let dataType: String
    private let version: String
    private var nutrientUnits: [Int: String] = [:]
    private var derivations: [Int: String] = [:]

    private static let energyNumbers: [Int] = NutrientRegistry.definition(for: .energy)?.usdaMappings
        .map(\.nutrientNumber) ?? []

    public init(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CatalogError.unavailable("catalog file missing")
        }
        let connection = try SQLiteConnection(path: "file:\(url.path)?immutable=1", readOnly: true)
        let meta = try Self.loadMeta(connection)
        self.connection = connection
        dataType = meta["source_data_type"] ?? "SR Legacy"
        version = meta["source_version"] ?? ""
        sourceDescription = "\(meta["source"] ?? "USDA FoodData Central") \(dataType) (\(version))"
    }

    /// The catalog shipped with the package.
    public static func bundled() throws -> SQLiteFoodCatalog {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "sqlite") else {
            throw CatalogError.unavailable("catalog not bundled")
        }
        return try SQLiteFoodCatalog(url: url)
    }

    private static func loadMeta(_ connection: SQLiteConnection) throws -> [String: String] {
        let statement = try connection.prepare("SELECT key, value FROM meta")
        var meta: [String: String] = [:]
        while try statement.step() {
            if let key = statement.text(0), let value = statement.text(1) { meta[key] = value }
        }
        return meta
    }

    /// Builds an FTS5 prefix query: every token must match the start of a word.
    static func ftsQuery(for text: String) -> String? {
        let tokens = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    public func search(_ query: String, limit: Int = 50) throws -> [CatalogFoodSummary] {
        guard let match = Self.ftsQuery(for: query) else { return [] }
        let firstWord = query.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
        do {
            let statement = try connection.prepare(
                """
                SELECT f.fdc_id, f.description, f.category, f.preparation
                FROM food_search s JOIN food f ON f.fdc_id = s.rowid
                WHERE food_search MATCH ?
                ORDER BY (f.description LIKE ? || '%') DESC, (f.preparation = 'raw') DESC, bm25(food_search), length(f.description)
                LIMIT ?
                """)
            try statement.bind(.text(match), .text(firstWord), .integer(Int64(limit)))
            var rows: [(id: Int64, name: String, category: String?, preparation: String?)] = []
            while try statement.step() {
                rows.append((statement.int(0), statement.text(1) ?? "", statement.text(2), statement.text(3)))
            }
            let energy = try energyPer100Grams(for: rows.map(\.id))
            return rows.map { row in
                CatalogFoodSummary(
                    id: String(row.id), name: row.name, category: row.category, preparation: row.preparation,
                    sourceLabel: "USDA \(dataType)", energyPer100Grams: energy[row.id])
            }
        } catch let error as SQLiteError {
            throw CatalogError.queryFailed(error.message)
        }
    }

    private func energyPer100Grams(for ids: [Int64]) throws -> [Int64: Double] {
        guard !ids.isEmpty else { return [:] }
        try loadUnitsIfNeeded()
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let numbers = Self.energyNumbers.map(String.init).joined(separator: ",")
        let statement = try connection.prepare(
            "SELECT fdc_id, nutrient_id, amount FROM food_nutrient WHERE fdc_id IN (\(placeholders)) AND nutrient_id IN (\(numbers))"
        )
        try statement.bind(ids.map { .integer($0) })
        var raw: [Int64: [Int: (amount: Double, unit: String)]] = [:]
        while try statement.step() {
            let number = Int(statement.int(1))
            raw[statement.int(0), default: [:]][number] = (statement.double(2), nutrientUnits[number] ?? "")
        }
        return raw.compactMapValues { NutrientRegistry.normalizeUSDA($0)[.energy] }
    }

    private func loadUnitsIfNeeded() throws {
        guard nutrientUnits.isEmpty else { return }
        let units = try connection.prepare("SELECT id, unit FROM nutrient")
        while try units.step() { nutrientUnits[Int(units.int(0))] = units.text(1) ?? "" }
        let derivationRows = try connection.prepare("SELECT id, description FROM derivation")
        while try derivationRows.step() { derivations[Int(derivationRows.int(0))] = derivationRows.text(1) ?? "" }
    }

    public func food(id: String) throws -> FoodDefinition? {
        guard let fdcID = Int64(id) else { return nil }
        do {
            try loadUnitsIfNeeded()
            let foodRow = try connection.prepare(
                "SELECT description, category, preparation FROM food WHERE fdc_id = ?")
            try foodRow.bind(.integer(fdcID))
            guard try foodRow.step() else { return nil }
            let name = foodRow.text(0) ?? ""
            let category = foodRow.text(1)
            let preparation = foodRow.text(2)

            let nutrientRows = try connection.prepare(
                "SELECT nutrient_id, amount, derivation_id FROM food_nutrient WHERE fdc_id = ?")
            try nutrientRows.bind(.integer(fdcID))
            var raw: [Int: (amount: Double, unit: String)] = [:]
            var derivationByNumber: [Int: String] = [:]
            while try nutrientRows.step() {
                let number = Int(nutrientRows.int(0))
                raw[number] = (nutrientRows.double(1), nutrientUnits[number] ?? "")
                if !nutrientRows.isNull(2), let text = derivations[Int(nutrientRows.int(2))] {
                    derivationByNumber[number] = text
                }
            }
            let selected = NutrientRegistry.selectUSDA(raw)

            let portionRows = try connection.prepare(
                "SELECT seq, amount, description, gram_weight FROM food_portion WHERE fdc_id = ? ORDER BY seq")
            try portionRows.bind(.integer(fdcID))
            var portions: [FoodPortion] = []
            while try portionRows.step() {
                let amount = portionRows.double(1)
                let description = portionRows.text(2) ?? ""
                guard amount > 0, description != "oz" else { continue }
                portions.append(
                    FoodPortion(
                        id: "fdc-\(portionRows.int(0))", name: description, grams: portionRows.double(3) / amount))
            }

            return FoodDefinition(
                source: .usda, sourceFoodID: id, name: name, preparation: preparation, category: category,
                sourceDataType: dataType, sourceVersion: version, retrievedAt: Date(),
                nutrition: FoodNutrition(
                    basis: .per100Grams, nutrients: NutrientProfile(selected.mapValues(\.amount)), portions: portions),
                derivations: selected.compactMapValues { derivationByNumber[$0.nutrientNumber] })
        } catch let error as SQLiteError {
            throw CatalogError.queryFailed(error.message)
        }
    }
}
