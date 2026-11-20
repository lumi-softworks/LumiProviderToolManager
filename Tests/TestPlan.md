# TestPlan — ProviderToolManager

## 包概述

ProviderToolManager 的实现包，包含 14 个主要类型；当前测试覆盖 61 条用例。

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 61

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `DefaultToolManagerObserverHandle`
- `DefaultToolInteractionPayload`
- `ToolArgumentCoding`
- `ToolAuthorizationDecision`
- `ToolCallRecord`
- `ToolCallRecordModel`
- `ToolCallRecordStore`
- `ToolExecutionPolicy`
- `ToolJobStatus`
- `ToolOutputStream`
- `ToolJobObserverHandle`
- `ToolJobRecord`
- `ToolJobRecordModel`
- `ToolJobRecordStore`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **DefaultToolManagerProviding**（17 条）：由 `executeSuccess`、`executePassesConversationContext`、`executeNotifiesObservers` 等用例锁定；授权结果复用必须按会话/回合作用域隔离（**#177**），改动该模块时优先跑对应测试文件。
- **ToolCallRecordStore**（7 条）：由 `recordAndFetch`、`deleteAll`、`count` 等用例锁定；另有上下文不可用时的安全降级，以及退出冲刷缓冲的停机语义（**#1163**），改动该模块时优先跑对应测试文件。
- **ToolJobRecordStore**（22 条）：由 `upsertAndFetchLifecycle`、`queryAndDeleteByScope`、`outputIsBounded` 等用例锁定；另有启动恢复的索引/物化成本基准与上下文不可用时的安全降级，改动该模块时优先跑对应测试文件。
- **ToolJob**（4 条）：由 `terminalStatuses`、`validTransitions`、`codableRoundTrip` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ToolManagerProviding**（11 条）：由 `addAndOrder`、`addMigratesOwnership`、`groupedByPlugin` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | DefaultToolManagerProviding | execute 成功返回内容并缓存结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeSuccess` |
| 2 | DefaultToolManagerProviding | execute 将回合会话 ID 传给 Context-aware 工具 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executePassesConversationContext` |
| 3 | DefaultToolManagerProviding | execute 通过观察者发出 started 和 completed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeNotifiesObservers` |
| 4 | DefaultToolManagerProviding | 工具注册表变化通过 typed 事件发布 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolRegistrationPublishesTypedEvent` |
| 5 | DefaultToolManagerProviding | execute 工具不存在返回错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeToolNotFound` |
| 6 | DefaultToolManagerProviding | execute 工具抛错返回错误结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeToolThrows` |
| 7 | DefaultToolManagerProviding | 授权执行事件携带最终授权状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `authorizedCompletionCarriesDecision` |
| 8 | DefaultToolManagerProviding | 拒绝授权事件携带最终授权状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectedCompletionCarriesDecision` |
| 9 | DefaultToolManagerProviding | 批次遇到高风险工具后立即暂停，不执行后续调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeBatchStopsAtApproval` |
| 10 | DefaultToolManagerProviding | execute 参数非 JSON 对象返回错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `executeBadArguments` |
| 11 | DefaultToolManagerProviding | 删除会话后执行被拒绝 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `executeAfterConversationDeleted` |
| 12 | DefaultToolManagerProviding | toolCalls(for:) 无存储时返回空 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallsWithoutStore` |
| 13 | DefaultToolManagerProviding | toolCallResult 无存储且无缓存时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolCallResultNil` |
| 14 | DefaultToolManagerProviding | 不同会话复用同一 toolCallID 时不得串用授权结果（#177） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `authorizedResultNotReusedAcrossConversations` |
| 15 | DefaultToolManagerProviding | 同会话不同回合复用同一 toolCallID 时按回合隔离（#177） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `authorizedResultIsolatedPerTurn` |
| 16 | DefaultToolManagerProviding | 持久化记录按会话/回合作用域查询，跨作用域不串结果（#177） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `persistedRecordIsolatedAcrossScopes` |
| 17 | DefaultToolManagerProviding | 重启后同会话同回合的授权结果仍复用持久化记录（#177） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `persistedResultReusedWithinScope` |
| 18 | ToolCallRecordStore | record 后按 turnID / conversationID 可查询 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recordAndFetch` |
| 19 | ToolCallRecordStore | deleteAll 删除记录并阻止后续写入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteAll` |
| 20 | ToolCallRecordStore | count 反映持久化记录数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `count` |
| 21 | ToolJobRecordStore | Job Store 支持创建、更新、终态查询和结果持久化 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upsertAndFetchLifecycle` |
| 22 | ToolJobRecordStore | Job Store 支持按会话/回合查询和删除 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `queryAndDeleteByScope` |
| 23 | ToolJobRecordStore | Job Store 输出尾部保持在 64 KiB 以内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `outputIsBounded` |
| 24 | ToolJob | 终态可以识别 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `terminalStatuses` |
| 25 | ToolJob | Job 状态只能按执行生命周期向前转换 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validTransitions` |
| 26 | ToolJob | ToolJob 可以 Codable 往返并保留工具调用身份 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `codableRoundTrip` |
| 27 | ToolJob | Job ID 始终复用 ToolCall ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `jobIDUsesToolCallID` |
| 28 | ToolManagerProviding | add 与 allTools 保持注册顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `addAndOrder` |
| 29 | ToolManagerProviding | add 相同名称工具迁移归属且不重复 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `addMigratesOwnership` |
| 30 | ToolManagerProviding | toolsGroupedByPlugin 按插件分组、组内保持顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `groupedByPlugin` |
| 31 | ToolManagerProviding | remove 与 removeAll 清理分组索引 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeAndRemoveAll` |
| 32 | ToolManagerProviding | displayDescription 使用工具展示名与参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayDescription` |
| 33 | ToolManagerProviding | displayDescription 无法解析时返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayDescriptionNil` |
| 34 | ToolManagerProviding | riskLevel 解析工具自身风险 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `riskLevel` |
| 35 | ToolManagerProviding | decode 空字符串得到空字典 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `decodeEmpty` |
| 36 | ToolManagerProviding | decode 保留 JSON 原始类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodeTypes` |
| 37 | ToolManagerProviding | decode 非对象 JSON 抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodeNonObjectThrows` |
| 38 | ToolManagerProviding | encode 往返一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `encodeRoundTrip` |
| 39 | ToolCallRecordStore | 批量按 turnID 查询只返回指定 turn 的记录 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fetchRecordsForTurnIDs` |
| 40 | ToolJobRecordStore | 启动恢复的查询走覆盖索引且不整表排序 | 临时库 | 执行该用例 | 查询计划命中覆盖索引 | P0 | ✅ 已覆盖 | `startupQueryMustUseCoveringIndex` |
| 41 | ToolJobRecordStore | 启动恢复不物化终态 Job 的 resultJSON | 临时库（200 条 64KB 结果） | 执行该用例 | 终态结果不被搬入内存 | P0 | ✅ 已覆盖 | `startupRestoreMustNotMaterializeTerminalResults` |
| 42 | ToolJobRecordStore | 启动恢复完整保留终态 Job 的身份与状态 | 临时库 | 执行该用例 | 身份与状态一致 | P0 | ✅ 已覆盖 | `startupRestoreMustKeepIdentityAndStatus` |
| 43 | ToolJobRecordStore | 非终态 Job 必须完整恢复（含结果） | 临时库 | 执行该用例 | 结果不丢失 | P0 | ✅ 已覆盖 | `nonTerminalJobsMustKeepResult` |
| 44 | ToolJobRecordStore | 非终态过滤必须下推到 SQL | 生产库副本（可选） | 执行该用例 | 过滤在 SQL 层完成 | P0 | ✅ 已覆盖 | `nonTerminalFilterMustBePushedDownToSQL` |
| 45 | ToolJobRecordStore | 启动恢复的排序查询走覆盖索引 | 临时库（500 条） | 执行该用例 | 查询计划无临时排序 | P0 | ✅ 已覆盖 | `startupRestoreQueryUsesIndex` |
| 46 | ToolJobRecordStore | 按会话查询的排序必须走索引 | 临时库（500 条） | 执行该用例 | 查询计划命中索引 | P0 | ✅ 已覆盖 | `conversationQueryUsesIndex` |
| 47 | ToolJobRecordStore | 按 turn 查询的排序必须走索引 | 临时库（500 条） | 执行该用例 | 查询计划命中索引 | P0 | ✅ 已覆盖 | `turnQueryUsesIndex` |
| 48 | ToolJobRecordStore | Date 往返会丢失精度，但 Unix 偏移量补正确 | 临时库 | 执行该用例 | 时间不落在 1995 年 | P1 | ✅ 已覆盖 | `dateRoundTripLosesPrecisionButKeepsEpoch` |
| 49 | ToolJobRecordStore | 非终态读取只取那几十行：过滤下推后物化成本归零 | 生产库副本（可选） | 执行该用例 | 物化条数等于非终态数 | P1 | ✅ 已覆盖 | `pushedDownFilterRemovesMaterializationCost` |
| 50 | ToolJobRecordStore | 启动查询走覆盖索引，不全表扫描 | 生产库副本（可选） | 执行该用例 | 查询计划无全表扫描 | P1 | ✅ 已覆盖 | `queryUsesCoveringIndex` |
| 51 | ToolJobRecordStore | 终态 Job 的结果不再在启动时被物化 | 生产库副本（可选） | 执行该用例 | 终态结果条数为 0 | P1 | ✅ 已覆盖 | `terminalResultsAreNotMaterialized` |
| 52 | ToolJobRecordStore | 恢复的 Job 条数随库增长，终态结果不被物化 | 生产库副本（可选） | 执行该用例 | 条数随库增长且无结果物化 | P1 | ✅ 已覆盖 | `restoredCountGrowsWithLibrarySize` |
| 53 | ToolJobRecordStore | 库里没有任何上限机制阻止增长（无保留策略） | 生产库副本（可选） | 执行该用例 | 终态 Job 占比接近全部 | P1 | ✅ 已覆盖 | `noRetentionPolicyExists` |
| 54 | ToolJobRecordStore | 终态 Job 占绝大多数，启动恢复只需非终态 | 生产库副本（可选） | 执行该用例 | 终态占比极高 | P1 | ✅ 已覆盖 | `terminalJobsDominate` |
| 55 | ToolJobRecordStore | resultJSON 是 Job 库的存储成本主体 | 生产库副本（可选） | 执行该用例 | resultJSON 总量占比最高 | P2 | ✅ 已覆盖 | `resultJSONDominatesStorageCost` |
| 56 | ToolJobRecordStore | 启动恢复耗时趋势（仅观测，不作断言依据） | 生产库副本（可选） | 执行该用例 | 打印耗时趋势 | P2 | ✅ 已覆盖 | `startupTimingForObservation` |
| 57 | ToolJobRecordStore | 累计输出超过 Int32.max 时重启恢复不截断 | 临时库 | 写入 3_000_000_000 字节后走原生 SQL 恢复 | 恢复值仍为 3_000_000_000 | P0 | ✅ 已覆盖 | `largeOutputByteCountSurvivesStartupRestore` |
| 58 | ToolCallRecordStore | 上下文不可用时所有接口安全降级且不崩溃 | 注入 `nil` ModelContext | 依次调用 record/flush/各查询/deleteAll | 均安全返回空结果，不崩溃 | P0 | ✅ 已覆盖 | `unavailableContextDegradesToNoOp` |
| 59 | ToolJobRecordStore | 上下文不可用时所有接口安全降级且不崩溃 | 注入 `nil` ModelContext | 依次调用 upsert/各查询/deleteAll | 均安全返回空结果，不崩溃 | P0 | ✅ 已覆盖 | `unavailableContextDegradesToNoOp` |
| 60 | ToolCallRecordStore | stopFlushTask 必须把缓冲中的记录落盘（**#1163**） | 临时库，写入 3 条不足一批的记录（期间不做任何读取） | 调用 `stopFlushTask` 后用独立容器读磁盘 | 独立容器读到全部 3 条 | P0 | ✅ 已覆盖 | `stopFlushTaskFlushesPendingRecords` |
| 61 | ToolCallRecordStore | stopFlushTask 后缓冲清空，重复停止无副作用 | 写入 1 条记录 | 连续两次调用 `stopFlushTask` | `count == 1`，不崩溃、不重复写入 | P1 | ✅ 已覆盖 | `stopFlushTaskIsIdempotent` |

> 说明：全部 **57 条场景**已在本包 `swift test` 中实跑通过。
>
> 变异验证（#1163）：把 `stopFlushTask()` 里的 `flush()` 移除（回到只取消定时器的旧行为）→ `stopFlushTaskFlushesPendingRecords` 转红（独立容器读不到缓冲中的记录），其余用例仍绿。变异确认转红后还原，最终 57 条全绿。
> 其中 10 条标注「生产库副本（可选）」的基准用例，未设置环境变量 `LUMI_PROD_TOOL_JOBS_SQLITE` 指向生产库副本时会提前返回（记为通过），设置后执行实际断言。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 16 / 16
- P1: 已覆盖 38 / 38
- P2: 已覆盖 3 / 3
- **合计: 57 / 57**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（16 条）
- **P1**: 其余功能性用例（38 条）
- **P2**: 稳定常量、占位、文案、空集合、纯观测基准等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 57 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderToolManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
