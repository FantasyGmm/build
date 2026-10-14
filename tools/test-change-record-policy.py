#!/usr/bin/env python3
"""Unit tests for the change-record policy validator."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

CHECKER = Path(__file__).with_name("check-change-record.py")
SPEC = importlib.util.spec_from_file_location("check_change_record", CHECKER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

VALID = """---
record_id: CR-2026-10-14-gate-test
date: 2026-10-14
repository: test-role
requirements:
  - REQ-GATE-001
---
# Test record

## 需求与范围
验证结构化记录的正常路径，并限定只测试记录解析器。

## 业务逻辑
输入记录先校验元数据，再校验必需章节和测试结果。

## 流程
```mermaid
flowchart TD
  A[record] --> B[validate]
  B --> C[PASS]
```

## 安全与失败分支
缺少字段或流程时直接失败，不修改仓库中的任何文件。

## 测试报告
| 类型 | 命令/检查 | 结果 | 证据 |
| --- | --- | --- | --- |
| unit | validate_record | PASS | unittest |

## 未完成项
本单元测试不声称业务功能或任何物理硬件已经通过。

## 交付影响
仅验证门禁解析行为，不生成软件包、镜像或公开发行。
"""


class ChangeRecordTests(unittest.TestCase):
    def validate(self, text):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "CR-2026-10-14-gate-test.md"
            path.write_text(text)
            return MODULE.validate_record(path, "test-role")

    def test_valid_record(self):
        self.assertEqual(self.validate(VALID), "CR-2026-10-14-gate-test")

    def test_requires_mermaid(self):
        with self.assertRaisesRegex(ValueError, "Mermaid"):
            self.validate(VALID.replace("```mermaid", "```text"))

    def test_rejects_placeholder(self):
        with self.assertRaisesRegex(ValueError, "placeholder"):
            self.validate(VALID.replace("仅验证门禁解析行为", "TODO 仅验证门禁解析行为"))


if __name__ == "__main__":
    unittest.main()
