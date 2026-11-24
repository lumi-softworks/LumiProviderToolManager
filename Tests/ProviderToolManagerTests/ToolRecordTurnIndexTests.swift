import Foundation
import SQLite3
import Testing
@testable import ProviderToolManager

/// 按 turn 删除与查询必须走 `ZTURNID` 索引，不能随记录总量线性变慢。
///
/// 断言查询计划而不是耗时：计划是确定性的，耗时随机器负载抖动。
@Suite("记录表的 turn 索引")
struct ToolRecordTurnIndexTests {

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ToolRecordTurnIndex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func queryPlan(in databaseURL: URL, sql: String) throws -> String {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            return ""
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "EXPLAIN QUERY PLAN \(sql)", -1, &statement, nil) == SQLITE_OK else {
            return ""
        }
        defer { sqlite3_finalize(statement) }

        var rows: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 3) {
                rows.append(String(cString: text))
            }
        }
        return rows.joined(separator: " | ")
    }

    private func assertUsesTurnIndex(plan: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(
            plan.contains("USING INDEX") || plan.contains("COVERING INDEX"),
            "按 turn 的查询未使用索引：\(plan)",
            sourceLocation: sourceLocation
        )
        #expect(!plan.contains("SCAN ZTOOL"), "按 turn 的查询仍在全表扫描：\(plan)", sourceLocation: sourceLocation)
    }

    @Test("tool_calls 表按 turn 过滤走索引")
    func callRecordsUseTurnIndex() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolCallRecordStore(databaseRootURL: directory)
        for index in 0..<50 {
            await store.record(
                toolCallID: "call-\(index)",
                toolName: "read_file",
                toolDisplayName: "读取文件",
                turnID: UUID(),
                conversationID: UUID(),
                createdAt: Date(),
                startedAt: Date(),
                completedAt: Date(),
                duration: 0.1,
                argumentsJSON: "{}",
                resultContent: "out",
                resultIsError: false,
                riskLevel: "low"
            )
        }

        let plan = try queryPlan(
            in: directory.appendingPathComponent("tool_calls.sqlite"),
            sql: "SELECT Z_PK FROM ZTOOLCALLRECORDMODEL WHERE ZTURNID IN ('a', 'b')"
        )
        assertUsesTurnIndex(plan: plan)
    }

    @Test("tool_jobs 表按 turn 过滤走索引")
    func jobRecordsUseTurnIndex() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = ToolJobRecordStore(databaseRootURL: directory)
        for index in 0..<50 {
            await store.upsert(ToolJobRecord(
                id: "job-\(index)",
                toolCallID: "call-\(index)",
                conversationID: UUID(),
                turnID: UUID(),
                toolName: "run_command",
                argumentsJSON: "{}",
                argumentsHash: "hash",
                status: .completed,
                createdAt: Date(),
                startedAt: Date(),
                updatedAt: Date(),
                latestOutput: "out"
            ))
        }

        let plan = try queryPlan(
            in: directory.appendingPathComponent("tool_jobs.sqlite"),
            sql: "SELECT Z_PK FROM ZTOOLJOBRECORDMODEL WHERE ZTURNID IN ('a', 'b')"
        )
        assertUsesTurnIndex(plan: plan)
    }
}
