import Foundation
import SQLite3

final class SQLiteDatabase: @unchecked Sendable {
    private var db: OpaquePointer?
    private let path: String
    
    init(path: String) throws {
        self.path = path
        try open()
    }
    
    deinit {
        close()
    }
    
    private func open() throws {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        let result = sqlite3_open_v2(path, &db, flags, nil)
        if result != SQLITE_OK {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close_v2(db)
            db = nil
            throw StorageError.databaseError(code: result, message: "Failed to open database at \(path): \(msg)")
        }
    }
    
    func close() {
        if db != nil {
            sqlite3_close_v2(db)
            db = nil
        }
    }
    
    var connection: OpaquePointer? {
        return db
    }
    
    func execute(_ sql: String) throws {
        guard let db = db else {
            throw StorageError.databaseError(code: SQLITE_ERROR, message: "Database is not open")
        }
        var errorMsg: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMsg)
        if result != SQLITE_OK {
            let msg = errorMsg.map { String(cString: $0) } ?? "Unknown error"
            if let ptr = errorMsg {
                sqlite3_free(ptr)
            }
            throw StorageError.databaseError(code: result, message: "SQL execution failed: \(msg) (SQL: \(sql))")
        }
    }
    
    func prepare(_ sql: String) throws -> SQLiteStatement {
        guard let db = db else {
            throw StorageError.databaseError(code: SQLITE_ERROR, message: "Database is not open")
        }
        var stmt: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        if result != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(db))
            throw StorageError.databaseError(code: result, message: "Failed to prepare statement: \(msg) (SQL: \(sql))")
        }
        return SQLiteStatement(stmt: stmt, db: self)
    }
    
    func lastInsertRowID() -> Int64 {
        guard let db = db else { return 0 }
        return sqlite3_last_insert_rowid(db)
    }
    
    func changes() -> Int {
        guard let db = db else { return 0 }
        return Int(sqlite3_changes(db))
    }
    
    func getErrorMessage() -> String {
        guard let db = db else { return "Database is not open" }
        return String(cString: sqlite3_errmsg(db))
    }
    
    func transaction<T>(_ block: () throws -> T) throws -> T {
        try execute("BEGIN TRANSACTION;")
        do {
            let result = try block()
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }
}

final class SQLiteStatement {
    fileprivate var stmt: OpaquePointer?
    private let db: SQLiteDatabase
    
    fileprivate init(stmt: OpaquePointer?, db: SQLiteDatabase) {
        self.stmt = stmt
        self.db = db
    }
    
    deinit {
        finalize()
    }
    
    func finalize() {
        if stmt != nil {
            sqlite3_finalize(stmt)
            stmt = nil
        }
    }
    
    func reset() {
        if let stmt = stmt {
            sqlite3_reset(stmt)
        }
    }
    
    func clearBindings() {
        if let stmt = stmt {
            sqlite3_clear_bindings(stmt)
        }
    }
    
    // MARK: - Bindings (1-based index)
    
    func bindInt(_ value: Int, at index: Int) throws {
        guard let stmt = stmt else { throw StorageError.databaseError(code: SQLITE_ERROR, message: "Statement is finalized") }
        let result = sqlite3_bind_int(stmt, Int32(index), Int32(value))
        if result != SQLITE_OK {
            throw StorageError.databaseError(code: result, message: "Failed to bind int: \(db.getErrorMessage())")
        }
    }
    
    func bindInt64(_ value: Int64, at index: Int) throws {
        guard let stmt = stmt else { throw StorageError.databaseError(code: SQLITE_ERROR, message: "Statement is finalized") }
        let result = sqlite3_bind_int64(stmt, Int32(index), value)
        if result != SQLITE_OK {
            throw StorageError.databaseError(code: result, message: "Failed to bind int64: \(db.getErrorMessage())")
        }
    }
    
    func bindDouble(_ value: Double, at index: Int) throws {
        guard let stmt = stmt else { throw StorageError.databaseError(code: SQLITE_ERROR, message: "Statement is finalized") }
        let result = sqlite3_bind_double(stmt, Int32(index), value)
        if result != SQLITE_OK {
            throw StorageError.databaseError(code: result, message: "Failed to bind double: \(db.getErrorMessage())")
        }
    }
    
    func bindText(_ value: String, at index: Int) throws {
        guard let stmt = stmt else { throw StorageError.databaseError(code: SQLITE_ERROR, message: "Statement is finalized") }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = sqlite3_bind_text(stmt, Int32(index), value, -1, transient)
        if result != SQLITE_OK {
            throw StorageError.databaseError(code: result, message: "Failed to bind text: \(db.getErrorMessage())")
        }
    }
    
    func bindNull(at index: Int) throws {
        guard let stmt = stmt else { throw StorageError.databaseError(code: SQLITE_ERROR, message: "Statement is finalized") }
        let result = sqlite3_bind_null(stmt, Int32(index))
        if result != SQLITE_OK {
            throw StorageError.databaseError(code: result, message: "Failed to bind null: \(db.getErrorMessage())")
        }
    }
    
    // MARK: - Step
    
    func step() throws -> Bool {
        guard let stmt = stmt else { throw StorageError.databaseError(code: SQLITE_ERROR, message: "Statement is finalized") }
        let result = sqlite3_step(stmt)
        if result == SQLITE_ROW {
            return true
        } else if result == SQLITE_DONE {
            return false
        } else {
            throw StorageError.databaseError(code: result, message: "Statement stepping failed: \(db.getErrorMessage())")
        }
    }
    
    // MARK: - Column Extraction (0-based index)
    
    func columnInt(at index: Int) -> Int {
        guard let stmt = stmt else { return 0 }
        return Int(sqlite3_column_int(stmt, Int32(index)))
    }
    
    func columnInt64(at index: Int) -> Int64 {
        guard let stmt = stmt else { return 0 }
        return sqlite3_column_int64(stmt, Int32(index))
    }
    
    func columnDouble(at index: Int) -> Double {
        guard let stmt = stmt else { return 0.0 }
        return sqlite3_column_double(stmt, Int32(index))
    }
    
    func columnText(at index: Int) -> String? {
        guard let stmt = stmt else { return nil }
        guard let textVal = sqlite3_column_text(stmt, Int32(index)) else { return nil }
        return String(cString: textVal)
    }
    
    func columnType(at index: Int) -> Int32 {
        guard let stmt = stmt else { return SQLITE_NULL }
        return sqlite3_column_type(stmt, Int32(index))
    }
}

