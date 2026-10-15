# 会话变更记录门禁

本规范落实 [DELIVERY_POLICY.md](../DELIVERY_POLICY.md) G14。仓库无法识别聊天工具中的“每次
对话”，因此可执行边界定义为：每个产生仓库修改的实现会话都创建或更新一份变更记录，并在
同一 PR 中提交；CI 保证任何 PR 代码差异至少携带一份记录。若一次 PR 汇总多个独立需求会话，
每个独立范围使用不同记录，不能用一份空泛总结覆盖。

## 文件与身份

文件路径为 `docs/change-records/CR-YYYY-MM-DD-<slug>.md`，文件名必须与 front matter 的
`record_id` 一致。每条需求使用稳定的 `REQ-<DOMAIN>-<NUMBER>`；已有编号必须沿用，新增
需求先分配编号，不用 commit、PR 或自然语言标题代替。

使用 [变更记录模板](../.github/CHANGE_RECORD_TEMPLATE.md)，保留全部章节：

- 需求与范围：用户目标、适用仓库/产品以及明确不做的内容。
- 业务逻辑：输入、状态、类型化映射、校验、输出和保持不变的边。
- 流程：Mermaid 表达入口、门禁、执行、成功、失败和人工恢复。
- 安全与失败分支：资源锁、固定绑定、超时、原始错误、重试及破坏性操作规则。
- 测试报告：测试类型、复现命令、PASS/FAIL/BLOCKED/NOT-RUN 和证据。
- 未完成项：没有执行或不能证明的测试，尤其是实板、公开端点及回滚。
- 交付影响：DEB/镜像/APT/Release/版本/重启/跨仓影响。

## 证据规则

记录保存可评审摘要和稳定引用。较大的原始日志保存在发行证据、CI artifact 或任务系统中，
引用任务 ID、版本、commit、包/镜像 SHA-256。不得提交密码、API Key、私钥、终端正文或个人
敏感信息。可读转换不能覆盖原始错误码或原始日志；未测项不能写成 PASS。

本门禁参考复杂硬件工作流所需的表达强度，例如入口布局、类型化选项映射、文件/平台/路线
校验、人工确认、持久任务与资源锁、固定 deviceId/USB/串口绑定、有界等待、原错误保留、
失败不自动重试及人工恢复。它约束记录质量，不表示本仓库实现了其他产品的 UI、FES Loader、
电源 GPIO、SSH PTY、Gateway 或设备 AI 功能。

## 本地与 CI

本地验证全部记录：

```sh
python3 tools/check-change-record.py
python3 tools/test-change-record-policy.py
```

评审某个 base 后的差异：

```sh
python3 tools/check-change-record.py --base origin/main
```

结构检查通过只说明记录齐全，评审者仍须核对源码、原始证据和需求不变量。
