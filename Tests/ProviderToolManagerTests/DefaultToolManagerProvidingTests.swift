import KitAgentTool
import Foundation
import os
import Testing
@testable import ProviderToolManager

private struct ContextConversationTool: SuperAgentTool {
    let name = "context_conversation"

    func description(for language: LanguagePreference) -> String { "Context conversation" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        "legacy path"
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: context.conversationID.uuidString)
    }
}

/// 统计执行次数的工具：每次执行返回递增序号，用于断言是否真实执行。
private final class CountingConversationTool: SuperAgentTool {
    let name = "counting_conversation"
    private let executionCount = OSAllocatedUnfairLock(initialState: 0)

    var count: Int { executionCount.withLock { $0 } }

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .high }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String { "" }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        let value = executionCount.withLock { $0 += 1; return $0 }
        return ToolCallResult(content: "exec-\(value)")
    }
}

@MainActor
struct DefaultToolManagerProvidingTests {

    @Test("execute 成功返回内容并缓存结果")
    func executeSuccess() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")

        let call = makeToolCall(name: "read", arguments: ["path": "/tmp/a.txt"])
        let result = await manager.execute(call, conversationID: UUID(), turnID: nil)

        #expect(!result.isError)
        #expect(result.content == "read /tmp/a.txt")
        #expect(result.duration != nil)

        // 结果缓存立即可查
        let cached = await manager.toolCallResult(for: call.id)
        #expect(cached?.content == "read /tmp/a.txt")
    }

    @Test("execute 将回合会话 ID 传给 Context-aware 工具")
    func executePassesConversationContext() async {
        let manager = DefaultToolManagerProviding()
        manager.add(ContextConversationTool(), pluginID: "p")
        let conversationID = UUID()

        let result = await manager.execute(
            makeToolCall(name: "context_conversation"),
            conversationID: conversationID,
            turnID: UUID()
        )

        #expect(result.content == conversationID.uuidString)
    }

    @Test("execute 通过观察者发出 started 和 completed")
    func executeNotifiesObservers() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        var events: [String] = []
        let handle = manager.addToolManagerObserver { event in
            switch event {
            case .toolsChanged:
                break
            case .started:
                events.append("started")
            case .authorizationRequired:
                events.append("authorizationRequired")
            case .completed:
                events.append("completed")
            case .authorizedCompleted:
                events.append("authorizedCompleted")
            case .batchCompleted:
                events.append("batchCompleted")
            }
        }

        _ = await manager.execute(
            makeToolCall(name: "read"),
            conversationID: UUID(),
            turnID: UUID()
        )

        #expect(events == ["started", "completed"])
        handle.cancel()
    }

    @Test("工具注册表变化通过 typed 事件发布")
    func toolRegistrationPublishesTypedEvent() {
        let manager = DefaultToolManagerProviding()
        var changes = 0
        let handle = manager.addToolManagerObserver { event in
            if case .toolsChanged = event {
                changes += 1
            }
        }

        manager.add(MockTool(name: "read"), pluginID: "p")
        manager.remove(id: "read")

        #expect(changes == 2)
        handle.cancel()
    }

    @Test("execute 工具不存在返回错误")
    func executeToolNotFound() async {
        let manager = DefaultToolManagerProviding()
        let result = await manager.execute(
            makeToolCall(name: "missing"),
            conversationID: UUID(),
            turnID: nil
        )
        #expect(result.isError)
        #expect(result.content.contains("Tool not found"))
    }

    @Test("execute 工具抛错返回错误结果")
    func executeToolThrows() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "boom", failWith: "disk full"), pluginID: "p")

        let result = await manager.execute(
            makeToolCall(name: "boom"),
            conversationID: UUID(),
            turnID: nil
        )
        #expect(result.isError)
        #expect(result.content.contains("disk full"))
    }

    @Test("授权执行事件携带最终授权状态")
    func authorizedCompletionCarriesDecision() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        var approvedState: ToolCallAuthorizationState?
        let handle = manager.addToolManagerObserver { event in
            if case let .authorizedCompleted(_, _, toolCall, _) = event {
                approvedState = toolCall.authorizationState
            }
        }

        _ = await manager.executeAuthorized(
            makeToolCall(name: "read"),
            conversationID: UUID(),
            turnID: nil
        )

        #expect(approvedState == .userApproved)
        handle.cancel()
    }

    @Test("拒绝授权事件携带最终授权状态")
    func rejectedCompletionCarriesDecision() async {
        let manager = DefaultToolManagerProviding()
        var rejectedState: ToolCallAuthorizationState?
        let handle = manager.addToolManagerObserver { event in
            if case let .authorizedCompleted(_, _, toolCall, _) = event {
                rejectedState = toolCall.authorizationState
            }
        }

        _ = await manager.rejectAuthorized(
            makeToolCall(name: "read"),
            conversationID: UUID(),
            turnID: nil
        )

        #expect(rejectedState == .userRejected)
        handle.cancel()
    }

    @Test("批次遇到高风险工具后立即暂停，不执行后续调用")
    func executeBatchStopsAtApproval() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "risky", risk: .high), pluginID: "p")
        manager.add(MockTool(name: "safe", risk: .low), pluginID: "p")
        var authorizationEventReceived = false
        let observer = manager.addToolManagerObserver { event in
            if case .authorizationRequired = event {
                authorizationEventReceived = true
            }
        }

        let results = await manager.executeBatch(
            [
                makeToolCall(name: "risky", id: "risky-1"),
                makeToolCall(name: "safe", id: "safe-1")
            ],
            policy: .requireApprovalForHighRisk,
            conversationID: UUID(),
            turnID: UUID()
        )

        #expect(results.count == 1)
        guard case .needsUserResponse = results[0] else {
            Issue.record("expected the first tool call to require user response")
            observer.cancel()
            return
        }
        #expect(authorizationEventReceived)
        observer.cancel()
    }

    @Test("execute 参数非 JSON 对象返回错误")
    func executeBadArguments() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")

        let call = ToolCall(id: "c1", name: "read", arguments: "not json{")
        let result = await manager.execute(call, conversationID: UUID(), turnID: nil)
        #expect(result.isError)
    }

    @Test("删除会话后执行被拒绝")
    func executeAfterConversationDeleted() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        let conversationID = UUID()

        await manager.deleteToolCalls(for: conversationID)
        let result = await manager.execute(
            makeToolCall(name: "read"),
            conversationID: conversationID,
            turnID: nil
        )
        #expect(result.isError)
        #expect(result.content.contains("deleted"))
    }

    @Test("toolCalls(for:) 无存储时返回空")
    func toolCallsWithoutStore() async {
        let manager = DefaultToolManagerProviding()
        let records = await manager.toolCalls(for: UUID())
        #expect(records.isEmpty)
    }

    @Test("toolCallResult 无存储且无缓存时返回 nil")
    func toolCallResultNil() async {
        let manager = DefaultToolManagerProviding()
        #expect(await manager.toolCallResult(for: "nope") == nil)
    }

    // MARK: - 授权结果作用域（#177）

    @Test("不同会话复用同一 toolCallID 时不得串用授权结果（#177）")
    func authorizedResultNotReusedAcrossConversations() async {
        let manager = DefaultToolManagerProviding()
        let tool = CountingConversationTool()
        manager.add(tool, pluginID: "p")

        let conversationA = UUID()
        let resultA = await manager.executeAuthorized(
            makeToolCall(name: "counting_conversation", id: "call_0"),
            conversationID: conversationA,
            turnID: UUID()
        )
        #expect(resultA.content == "exec-1")
        #expect(tool.count == 1)

        // 会话 B 使用相同 toolCallID：必须真实执行，而不是拿到 A 的结果。
        let resultB = await manager.executeAuthorized(
            makeToolCall(name: "counting_conversation", id: "call_0"),
            conversationID: UUID(),
            turnID: UUID()
        )
        #expect(resultB.content == "exec-2")
        #expect(tool.count == 2, "会话 B 必须重新执行，实际执行次数 \(tool.count)")
    }

    @Test("同会话不同回合复用同一 toolCallID 时按回合隔离（#177）")
    func authorizedResultIsolatedPerTurn() async {
        let manager = DefaultToolManagerProviding()
        let tool = CountingConversationTool()
        manager.add(tool, pluginID: "p")
        let conversationID = UUID()

        _ = await manager.executeAuthorized(
            makeToolCall(name: "counting_conversation", id: "call_0"),
            conversationID: conversationID,
            turnID: UUID()
        )
        #expect(tool.count == 1)

        // 新回合携带新 turnID：不能复用上一回合的结果。
        let result = await manager.executeAuthorized(
            makeToolCall(name: "counting_conversation", id: "call_0"),
            conversationID: conversationID,
            turnID: UUID()
        )
        #expect(result.content == "exec-2")
        #expect(tool.count == 2)
    }

    @Test("持久化记录按会话/回合作用域查询，跨作用域不串结果（#177）")
    func persistedRecordIsolatedAcrossScopes() async throws {
        let (store, dir) = try makeRecordStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = DefaultToolManagerProviding()
        manager.recordStore = store

        let conversationA = UUID()
        let turnID = UUID()
        await store.record(
            toolCallID: "call_0",
            toolName: "counting_conversation",
            toolDisplayName: "counting_conversation",
            turnID: turnID,
            conversationID: conversationA,
            createdAt: Date(),
            startedAt: Date(),
            completedAt: Date(),
            duration: 0.1,
            argumentsJSON: "{}",
            resultContent: "A-result",
            resultIsError: false,
            riskLevel: "high"
        )

        // 会话 B（无 turnID）查询同一 ID：不能拿到 A 的记录。
        #expect(await manager.toolCallResult(for: "call_0", conversationID: UUID(), turnID: nil) == nil)
        // 会话 B 携带 A 的 turnID：按会话过滤后仍不命中。
        #expect(await manager.toolCallResult(for: "call_0", conversationID: UUID(), turnID: turnID) == nil)
        // 同会话不同回合：turnID 可用时必须按回合隔离。
        #expect(await manager.toolCallResult(for: "call_0", conversationID: conversationA, turnID: UUID()) == nil)
        // 会话 A 同回合查询命中。
        let scopedA = await manager.toolCallResult(for: "call_0", conversationID: conversationA, turnID: turnID)
        #expect(scopedA?.content == "A-result")
    }

    @Test("重启后同会话同回合的授权结果仍复用持久化记录（#177）")
    func persistedResultReusedWithinScope() async throws {
        let (store, dir) = try makeRecordStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let conversationID = UUID()
        let turnID = UUID()

        let first = DefaultToolManagerProviding()
        first.recordStore = store
        let firstTool = CountingConversationTool()
        first.add(firstTool, pluginID: "p")
        let firstResult = await first.executeAuthorized(
            makeToolCall(name: "counting_conversation", id: "call_0"),
            conversationID: conversationID,
            turnID: turnID
        )
        #expect(firstResult.content == "exec-1")
        await store.stopFlushTask()

        // 新进程：内存缓存为空，只能依赖持久化记录复用。
        let second = DefaultToolManagerProviding()
        second.recordStore = store
        let secondTool = CountingConversationTool()
        second.add(secondTool, pluginID: "p")
        let reused = await second.executeAuthorized(
            makeToolCall(name: "counting_conversation", id: "call_0"),
            conversationID: conversationID,
            turnID: turnID
        )
        #expect(reused.content == "exec-1")
        #expect(secondTool.count == 0, "重启后不应重新执行，实际执行 \(secondTool.count) 次")
        await store.stopFlushTask()
    }

    @Test("按回合删除工具记录：只清掉指定回合的缓存与持久化记录，会话仍可执行")
    func deleteToolCallsForTurns() async throws {
        let (store, dir) = try makeRecordStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let manager = DefaultToolManagerProviding()
        manager.recordStore = store
        manager.add(MockTool(name: "read"), pluginID: "p")
        let conversationID = UUID()
        let otherConversationID = UUID()
        let removedTurn = UUID()
        let keptTurn = UUID()

        _ = await manager.execute(makeToolCall(name: "read", id: "call_removed"), conversationID: conversationID, turnID: removedTurn)
        _ = await manager.execute(makeToolCall(name: "read", id: "call_kept"), conversationID: conversationID, turnID: keptTurn)
        _ = await manager.execute(makeToolCall(name: "read", id: "call_no_turn"), conversationID: conversationID, turnID: nil)
        _ = await manager.execute(makeToolCall(name: "read", id: "call_other"), conversationID: otherConversationID, turnID: removedTurn)

        await manager.deleteToolCalls(forTurnIDs: [removedTurn], in: conversationID)

        #expect(await manager.toolCallResult(for: "call_removed", conversationID: conversationID, turnID: removedTurn) == nil)
        // turnID 全局唯一；别的会话恰好用了同一个 turnID 的记录不在清理范围内。
        #expect(await manager.toolCalls(for: removedTurn).map(\.conversationID) == [otherConversationID])
        #expect(await manager.toolCallResult(for: "call_kept", conversationID: conversationID, turnID: keptTurn) != nil)
        #expect(await manager.toolCallResult(for: "call_no_turn", conversationID: conversationID, turnID: nil) != nil)
        #expect(await manager.toolCallResult(for: "call_other", conversationID: otherConversationID, turnID: removedTurn) != nil)

        // 截断后同一会话仍可执行工具并缓存结果。
        let newTurn = UUID()
        let again = await manager.execute(makeToolCall(name: "read", id: "call_new"), conversationID: conversationID, turnID: newTurn)
        #expect(!again.isError)
        #expect(await manager.toolCallResult(for: "call_new", conversationID: conversationID, turnID: newTurn) != nil)
    }

    /// 每个测试使用独立临时目录，避免跨测试数据库冲突。
    private func makeRecordStore() throws -> (ToolCallRecordStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuthorizedScopeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (ToolCallRecordStore(databaseRootURL: dir), dir)
    }
}
