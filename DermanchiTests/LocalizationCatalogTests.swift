import XCTest
@testable import Dermanchi

/// Yeni dil əlavə edəndə (və ya yeni mətn yazanda) tərcümənin yarımçıq qalmasının qarşısını alır.
final class LocalizationCatalogTests: XCTestCase {
    private let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private var catalogURL: URL { root.appending(path: "Dermanchi/Resources/Localizable.xcstrings") }

    private func loadCatalog() throws -> (source: String, strings: [String: [String: Any]]) {
        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
        return (json["sourceLanguage"] as? String ?? "", strings)
    }

    private func localizations(_ entry: [String: Any]) -> [String: [String: Any]] {
        entry["localizations"] as? [String: [String: Any]] ?? [:]
    }

    /// Bir tərcümənin bütün mətn parçaları (adi, cəm və əvəzetmə variantları).
    private func values(of localization: [String: Any]) -> [String] {
        var result: [String] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let unit = dict["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
                    result.append(value)
                }
                dict.values.forEach(walk)
            }
        }
        walk(localization)
        return result
    }

    // MARK: - Kataloq tamlığı

    func testCatalogSourceLanguageIsTheFallbackLanguage() throws {
        XCTAssertEqual(try loadCatalog().source, AppLanguage.fallback.code)
    }

    func testEveryKeyIsTranslatedIntoEverySupportedLanguage() throws {
        let (_, strings) = try loadCatalog()
        var problems: [String] = []
        for (key, entry) in strings {
            let available = localizations(entry)
            for language in AppLanguage.supported {
                guard let localization = available[language.code] else {
                    problems.append("[\(language.code)] çatışmır: \(key)")
                    continue
                }
                let texts = values(of: localization)
                if texts.isEmpty || texts.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                    problems.append("[\(language.code)] boşdur: \(key)")
                }
                if (localization["stringUnit"] as? [String: Any])?["state"] as? String == "needs_review" {
                    problems.append("[\(language.code)] yoxlanmalıdır: \(key)")
                }
            }
        }
        XCTAssertEqual(problems.sorted(), [], "Tərcümə yarımçıqdır")
    }

    func testCatalogHasNoLanguageThatIsNotRegistered() throws {
        let (_, strings) = try loadCatalog()
        let registered = Set(AppLanguage.supported.map(\.code))
        let inCatalog = Set(strings.values.flatMap { localizations($0).keys })
        XCTAssertEqual(inCatalog.subtracting(registered), [],
                       "Kataloqda tərcümə var, amma dil AppLanguage.supported siyahısında yoxdur")
    }

    func testPlaceholdersMatchAcrossLanguages() throws {
        let (_, strings) = try loadCatalog()
        var problems: [String] = []
        for (key, entry) in strings {
            guard let source = localizations(entry)[AppLanguage.fallback.code],
                  source["variations"] == nil, source["substitutions"] == nil,
                  let sourceText = values(of: source).first else { continue }
            for language in AppLanguage.supported where language.code != AppLanguage.fallback.code {
                guard let localization = localizations(entry)[language.code],
                      localization["variations"] == nil, localization["substitutions"] == nil,
                      let text = values(of: localization).first else { continue }
                if placeholders(in: sourceText) != placeholders(in: text) {
                    problems.append("[\(language.code)] yer tutucular uyğun deyil: \(key)")
                }
            }
        }
        XCTAssertEqual(problems.sorted(), [])
    }

    private func placeholders(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?(?:@|lld|d|f)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range)
            .map { String(text[Range($0.range, in: text)!]).replacingOccurrences(of: "\\d+\\$", with: "", options: .regularExpression) }
            .sorted()
    }

    func testBuiltBundleContainsEverySupportedLanguage() {
        for language in AppLanguage.supported {
            XCTAssertNotNil(L10n.bundle(for: language), "\(language.code).lproj bundle-da yoxdur")
        }
    }

    // MARK: - Kod ↔ kataloq

    func testEveryLiteralKeyInSourcesExistsInCatalog() throws {
        let (_, strings) = try loadCatalog()
        let catalogKeys = Set(strings.keys.map(normalize))
        var missing: [String] = []
        for (file, keys) in try sourceKeys() {
            for key in keys where !catalogKeys.contains(normalize(key)) {
                missing.append("\(file): \(key)")
            }
        }
        XCTAssertEqual(missing.sorted(), [], "Koddakı bu açarlar Localizable.xcstrings-də yoxdur")
    }

    func testEveryCatalogKeyIsUsedInSources() throws {
        let (_, strings) = try loadCatalog()
        let used = Set(try sourceKeys().flatMap(\.1).map(normalize))
        let unused = strings.keys.filter { !used.contains(normalize($0)) }
        XCTAssertEqual(unused.sorted(), [], "Kataloqda var, amma kodda istifadə olunmur")
    }

    func testNoAzerbaijaniTextIsHardcodedInSources() throws {
        let allowed = ["Dərmanchı", "Azərbaycanca"]
        var offenders: [String] = []
        for file in try swiftSources() {
            for literal in stringLiterals(in: try String(contentsOf: file, encoding: .utf8)) {
                var text = literal
                allowed.forEach { text = text.replacingOccurrences(of: $0, with: "") }
                if text.range(of: "[əğıöüçşƏĞİÖÜÇŞ]", options: .regularExpression) != nil {
                    offenders.append("\(file.lastPathComponent): \(literal)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "Mətnlər kodda yox, Localizable.xcstrings-də olmalıdır")
    }

    /// `Text(cond ? "a" : "b")` — iki xam literal `String` sayılır, `LocalizedStringKey` yox, ona görə tərcümə olunmur.
    /// İnsan mətni `tr("...")` ilə yazılmalıdır. SF Symbol adları (`moon.zzz.fill`) və yalnız rəqəm/işarədən
    /// ibarət literallar bura düşmür.
    func testNoRawHumanTextInTernaryBranches() throws {
        var offenders: [String] = []
        for file in try swiftSources() {
            let text = try String(contentsOf: file, encoding: .utf8)
                .components(separatedBy: "\n").map(withoutLineComment).joined(separator: "\n")
            for literal in ternaryLiterals(in: text) {
                let looksLikeIdentifier = literal.range(of: #"^[a-z0-9._]*$"#, options: .regularExpression) != nil
                if !looksLikeIdentifier, literal.contains(where: \.isLetter) {
                    offenders.append("\(file.lastPathComponent): \(literal)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "Ternary-də mətn üçün tr(\"...\") istifadə et")
    }

    /// `cond ? "a" : "b"` ifadəsindəki literallar. `??`, `title: "x"` və `case .a: "x"` sayılmır.
    private func ternaryLiterals(in text: String) -> [String] {
        var result: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard text[index] == "\"" else { index = text.index(after: index); continue }
            guard let literal = readLiteral(in: text, from: text.index(after: index)) else { break }
            if isTernaryBranch(literalStart: index, in: text) { result.append(literal.text) }
            index = literal.end
        }
        return result
    }

    private func isTernaryBranch(literalStart: String.Index, in text: String) -> Bool {
        var cursor = literalStart
        while cursor > text.startIndex {
            let before = text.index(before: cursor)
            if text[before].isWhitespace { cursor = before; continue }
            let marker = text[before]
            guard cursor > text.startIndex, before > text.startIndex else { return false }
            let beforeMarker = text[text.index(before: before)]
            if marker == "?" { return beforeMarker != "?" }
            // Ternary-nin ikinci qolu: boşluqdan sonra gələn ` : "..."`.
            if marker == ":" { return beforeMarker.isWhitespace }
            return false
        }
        return false
    }

    // MARK: - Mənbə kodunu oxumaq

    private func swiftSources() throws -> [URL] {
        ["Dermanchi", "DermanchiWidget"].flatMap { directory -> [URL] in
            let url = root.appending(path: directory)
            let all = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
            return all.filter { $0.pathExtension == "swift" }
        }
    }

    private static let callPattern = try! NSRegularExpression(pattern:
        #"(?<![A-Za-z_.])(?:tr|Text|Label|Button|Section|Picker|DatePicker|Toggle|LabeledContent|Tab|ContentUnavailableView)\(\s*""#
        + #"|\.(?:navigationTitle|alert|configurationDisplayName|description)\(\s*""#
        + #"|\btitle:\s*""#
        + #"|LocalizedStringResource\s*=\s*""#)

    /// `(fayl, [açarlar])`
    private func sourceKeys() throws -> [(String, [String])] {
        try swiftSources().map { file in
            let text = try String(contentsOf: file, encoding: .utf8)
                .components(separatedBy: "\n").map(withoutLineComment).joined(separator: "\n")
            var keys: [String] = []
            for match in Self.callPattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range, in: text) else { continue }
                if let literal = readLiteral(in: text, from: range.upperBound) { keys.append(literal.text) }
            }
            return (file.lastPathComponent, keys)
        }
    }

    /// Açılış dırnağından sonra başlayan sətir literalını oxuyur. `\( ... )` interpolyasiyası `%` ilə əvəz olunur.
    /// Bağlanış dırnağından sonrakı mövqeyi də qaytarır.
    private func readLiteral(in text: String, from start: String.Index) -> (text: String, end: String.Index)? {
        var result = ""
        var index = start
        while index < text.endIndex {
            let ch = text[index]
            if ch == "\"" { return (result, text.index(after: index)) }
            if ch == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else { return nil }
                if text[next] == "(" {
                    var depth = 1
                    index = text.index(after: next)
                    while index < text.endIndex, depth > 0 {
                        if text[index] == "(" { depth += 1 }
                        if text[index] == ")" { depth -= 1 }
                        index = text.index(after: index)
                    }
                    result += "%"
                    continue
                }
                result.append(text[next])
                index = text.index(after: next)
                continue
            }
            result.append(ch)
            index = text.index(after: index)
        }
        return nil
    }

    /// Mənbədəki bütün sətir literalları (`//` şərhləri xaric).
    private func stringLiterals(in text: String) -> [String] {
        var literals: [String] = []
        for rawLine in text.components(separatedBy: "\n") {
            let line = withoutLineComment(rawLine)
            var index = line.startIndex
            while let open = line[index...].firstIndex(of: "\"") {
                guard let literal = readLiteral(in: line, from: line.index(after: open)) else { break }
                literals.append(literal.text)
                index = literal.end
            }
        }
        return literals
    }

    private func withoutLineComment(_ line: String) -> String {
        var inString = false
        var previous: Character?
        for index in line.indices {
            let ch = line[index]
            if ch == "\"", previous != "\\" { inString.toggle() }
            if !inString, ch == "/", previous == "/" {
                return String(line[..<line.index(before: index)])
            }
            previous = ch
        }
        return line
    }

    /// `%@`, `%lld`, `%1$@` və s. → `%`
    private func normalize(_ key: String) -> String {
        key.replacingOccurrences(of: #"%(?:\d+\$)?(?:@|lld|d|f)"#, with: "%", options: .regularExpression)
    }
}
