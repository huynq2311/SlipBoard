import Foundation
import SQLite3

final class SQLiteFTSIndex: FTSIndexProtocol, @unchecked Sendable {
    private let db: SQLiteDatabase
    
    init(db: SQLiteDatabase) {
        self.db = db
    }
    
    func insert(clipID: String, normalizedText: String, note: String) throws {
        let sql = "INSERT INTO clips_fts (clip_id, normalized_text, note) VALUES (?, ?, ?);"
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        try stmt.bindText(clipID, at: 1)
        try stmt.bindText(normalizedText, at: 2)
        try stmt.bindText(note, at: 3)
        _ = try stmt.step()
    }
    
    func update(clipID: String, normalizedText: String, note: String) throws {
        try delete(clipID: clipID)
        try insert(clipID: clipID, normalizedText: normalizedText, note: note)
    }
    
    func delete(clipID: String) throws {
        let sql = "DELETE FROM clips_fts WHERE clip_id = ?;"
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        try stmt.bindText(clipID, at: 1)
        _ = try stmt.step()
    }
    
    func clearNotes() throws {
        let sql = "UPDATE clips_fts SET note = '';"
        try db.execute(sql)
    }
    
    func clearAll() throws {
        let sql = "DELETE FROM clips_fts;"
        try db.execute(sql)
    }
    
    func search(query: String) throws -> [(clipID: String, matchScore: Double)] {
        let sanitized = sanitizeQuery(query)
        if sanitized.isEmpty {
            return []
        }
        
        do {
            return try executeSearch(sanitized)
        } catch {
            let fallbackQuery = cleanForFallback(query)
            if !fallbackQuery.isEmpty {
                do {
                    return try executeSearch(fallbackQuery)
                } catch {
                    return []
                }
            }
            return []
        }
    }
    
    private func sanitizeQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        let components = trimmed.components(separatedBy: .whitespacesAndNewlines)
        var tokens = [String]()
        
        for component in components {
            var token = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else { continue }
            
            var isPrefix = false
            if token.hasSuffix("*") {
                isPrefix = true
                token.removeLast()
            }
            
            token = token.replacingOccurrences(of: "\"", with: "\"\"")
            
            let charsToRemove = CharacterSet(charactersIn: ":()+ -^")
            token = token.components(separatedBy: charsToRemove).joined()
            
            guard !token.isEmpty else { continue }
            
            if isPrefix && token.count >= 2 {
                tokens.append("\"\(token)\"*")
            } else {
                tokens.append("\"\(token)\"")
            }
        }
        
        return tokens.joined(separator: " AND ")
    }
    
    private func cleanForFallback(_ query: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = query.unicodeScalars.filter { allowed.contains($0) }
        let cleaned = String(String.UnicodeScalarView(filtered))
        
        let components = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.map { "\"\($0)\"" }.joined(separator: " AND ")
    }
    
    private func executeSearch(_ queryStr: String) throws -> [(clipID: String, matchScore: Double)] {
        let sql = """
        SELECT c.id, bm25(clips_fts) as score
        FROM clips_fts
        JOIN clips c ON c.id = clips_fts.clip_id
        WHERE clips_fts MATCH ?
        ORDER BY
            c.is_pinned DESC,
            score ASC,
            c.last_copied_at DESC,
            c.total_copy_count DESC;
        """
        
        let stmt = try db.prepare(sql)
        defer { stmt.finalize() }
        
        try stmt.bindText(queryStr, at: 1)
        
        var results = [(clipID: String, matchScore: Double)]()
        while try stmt.step() {
            if let clipID = stmt.columnText(at: 0) {
                let score = stmt.columnDouble(at: 1)
                results.append((clipID, score))
            }
        }
        return results
    }
}
