#!/usr/bin/env python3
"""Require structured, reviewable change records for repository modifications."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

RECORD_DIRECTORY = Path("docs/change-records")
RECORD_PATTERN = re.compile(r"^CR-[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9][a-z0-9-]*$")
REQ_PATTERN = re.compile(r"^REQ-[A-Z0-9]+(?:-[A-Z0-9]+)*-[0-9]{3,}$")
REQUIRED_HEADINGS = (
    "需求与范围",
    "业务逻辑",
    "流程",
    "安全与失败分支",
    "测试报告",
    "未完成项",
    "交付影响",
)
PLACEHOLDERS = ("TODO", "TBD", "待填写", "待补充", "<填写", "示例内容")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read_front_matter(text, path):
    require(text.startswith("---\n"), f"{path}: missing YAML-style front matter")
    end = text.find("\n---\n", 4)
    require(end != -1, f"{path}: unterminated front matter")
    front = text[4:end]
    body = text[end + 5 :]
    fields = {}
    requirements = []
    in_requirements = False
    for line in front.splitlines():
        if line.startswith("requirements:"):
            in_requirements = True
            continue
        if in_requirements and re.fullmatch(r"  - .+", line):
            requirements.append(line[4:].strip())
            continue
        in_requirements = False
        match = re.fullmatch(r"([a-z_]+):\s*(.+)", line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    fields["requirements"] = requirements
    return fields, body


def sections(body):
    matches = list(re.finditer(r"^## (.+?)\s*$", body, re.M))
    result = {}
    for index, match in enumerate(matches):
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        result[match.group(1)] = body[start:end].strip()
    return result


def validate_record(path, expected_repository=None):
    text = path.read_text(encoding="utf-8")
    require(not any(marker in text for marker in PLACEHOLDERS), f"{path}: contains placeholder text")
    fields, body = read_front_matter(text, path)
    record_id = fields.get("record_id", "")
    require(RECORD_PATTERN.fullmatch(record_id), f"{path}: invalid record_id")
    require(path.stem == record_id, f"{path}: filename must match record_id")
    require(re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", fields.get("date", "")),
            f"{path}: invalid date")
    repository = fields.get("repository", "")
    require(repository, f"{path}: missing repository")
    if expected_repository:
        require(repository == expected_repository,
                f"{path}: repository must be {expected_repository}, got {repository}")
    requirements = fields["requirements"]
    require(requirements, f"{path}: requirements must not be empty")
    require(all(REQ_PATTERN.fullmatch(value) for value in requirements),
            f"{path}: malformed requirement ID")
    parsed = sections(body)
    require(set(REQUIRED_HEADINGS).issubset(parsed),
            f"{path}: missing required headings: " +
            ", ".join(name for name in REQUIRED_HEADINGS if name not in parsed))
    for name in REQUIRED_HEADINGS:
        require(len(parsed[name]) >= 20, f"{path}: section '{name}' is too short")
    require(re.search(r"```mermaid\s+.+?```", parsed["流程"], re.S),
            f"{path}: flow section must contain a Mermaid diagram")
    report = parsed["测试报告"]
    require("| 类型 |" in report and "| 命令/检查 |" in report and "| 结果 |" in report and "| 证据 |" in report,
            f"{path}: test report must use the required table columns")
    require(re.search(r"\b(PASS|FAIL|BLOCKED|NOT-RUN)\b", report),
            f"{path}: test report must contain an explicit result")
    return record_id


def git_output(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).splitlines()


def usable_base(root, base):
    if not base or set(base) == {"0"}:
        return None
    return base if subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", base + "^{commit}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0 else None


def changed_files(root, base):
    base = usable_base(root, base)
    if not base:
        return []
    try:
        return git_output(root, "diff", "--name-only", "--diff-filter=ACMR", base + "...HEAD")
    except subprocess.CalledProcessError:
        return git_output(root, "diff", "--name-only", "--diff-filter=ACMR", base, "HEAD")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base", default="")
    args = parser.parse_args()
    root = args.root.resolve()
    manifest = json.loads((root / ".delivery-policy.json").read_text())
    expected_repository = manifest["role"]
    directory = root / RECORD_DIRECTORY
    require(directory.is_dir(), "missing docs/change-records directory")
    paths = sorted(directory.glob("CR-*.md"))
    require(paths, "no change records found")
    seen = set()
    for path in paths:
        record_id = validate_record(path, expected_repository)
        require(record_id not in seen, "duplicate record_id: " + record_id)
        seen.add(record_id)

    changed = changed_files(root, args.base)
    if changed:
        changed_records = [
            name for name in changed
            if Path(name).parent == RECORD_DIRECTORY and Path(name).name.startswith("CR-")
        ]
        require(changed_records,
                "repository changes require a changed docs/change-records/CR-*.md file")
        for name in changed_records:
            require((root / name).is_file(), "changed record is missing: " + name)
    print(f"Change-record gate passed: {len(paths)} record(s)" +
          (f", {len(changed)} changed file(s)" if changed else ""))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError, subprocess.CalledProcessError) as error:
        print("Change-record gate failed: " + str(error), file=sys.stderr)
        sys.exit(1)
