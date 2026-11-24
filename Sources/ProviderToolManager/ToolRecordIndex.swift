import Foundation
import SQLite3

/// 记录表上的辅助索引。SwiftData 不为业务列自动建索引，按 turn 删除时
/// 没有索引就会全表扫描。
enum ToolRecordIndex {
    static func ensure(
        name: String,
        table: String,
        columns: [String],
        databaseURL: URL
    ) {
        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return
        }
        defer { sqlite3_close(database) }

        let sql = "CREATE INDEX IF NOT EXISTS \(name) ON \(table) (\(columns.joined(separator: ", ")))"
        var errorMessage: UnsafeMutablePointer<Int8>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        if let errorMessage {
            sqlite3_free(errorMessage)
        }
        guard result == SQLITE_OK else { return }
    }
}
