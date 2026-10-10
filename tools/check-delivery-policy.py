#!/usr/bin/env python3
"""Check delivery-policy wiring. This does not certify a release or hardware."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

POLICY_ID = "dshanpi-delivery-v1"
ROLES = {"armbianos", "dshanpi-build", "dspi-config"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def repository_file(root, name):
    path = Path(name)
    require(not path.is_absolute() and ".." not in path.parts, "unsafe policy entry: " + name)
    full = root / path
    require(full.is_file(), "missing policy entry: " + name)
    return full


def check(root):
    manifest = json.loads(repository_file(root, ".delivery-policy.json").read_text())
    require(manifest.get("schema_version") == 1, "unsupported policy manifest")
    require(manifest.get("policy_id") == POLICY_ID, "wrong delivery policy ID")
    require(manifest.get("role") in ROLES, "unknown repository role")
    policy = repository_file(root, "DELIVERY_POLICY.md").read_bytes()
    require(hashlib.sha256(policy).hexdigest() == manifest.get("sha256"), "delivery policy SHA-256 mismatch")
    text = policy.decode()
    require(POLICY_ID in text, "policy document lost its identity")
    require(set(re.findall(r"^## (G\d+) ", text, re.M)) == {f"G{i:02}" for i in range(1, 14)},
            "delivery policy must retain all thirteen gates, including G12 kernel headers and G13 ownership/handoff")
    for value in ("https://apt.100ask.net", "dshanpi/ArmBianOS", "dshanpi-a1", "dshanpi-a1-cm5", "dshanpi-r1", "avaota-a1"):
        require(value in text, "delivery policy lost required endpoint/product: " + value)
    references = manifest.get("references", [])
    require({"AGENTS.md", ".github/PULL_REQUEST_TEMPLATE.md"}.issubset(references), "missing agent/PR policy entry")
    for name in references:
        require("DELIVERY_POLICY.md" in repository_file(root, name).read_text(), "policy not linked from " + name)
    hooks = manifest.get("hooks", [])
    require(bool(hooks) and any(name.startswith(".github/workflows/") for name in hooks), "missing CI policy gate")
    require(any(not name.startswith(".github/") for name in hooks), "missing local policy gate")
    for name in hooks:
        require("check-delivery-policy.py" in repository_file(root, name).read_text(), "policy gate not wired in " + name)
    repository_file(root, "tools/check-repository-hygiene.py")
    hygiene_hooks = manifest.get("hygiene_hooks", [])
    require(bool(hygiene_hooks), "missing repository hygiene CI hook")
    for name in hygiene_hooks:
        require(name.startswith(".github/workflows/"), "hygiene hook must include CI")
        require("check-repository-hygiene.py" in repository_file(root, name).read_text(),
                "repository hygiene gate not wired in " + name)
    return manifest, policy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--peer", type=Path, action="append", default=[])
    args = parser.parse_args()
    manifest, policy = check(args.root)
    checker = repository_file(args.root, "tools/check-delivery-policy.py").read_bytes()
    for peer in args.peer:
        _, peer_policy = check(peer)
        require(peer_policy == policy, "cross-repository policy drift: " + str(peer))
        require(repository_file(peer, "tools/check-delivery-policy.py").read_bytes() == checker,
                "cross-repository policy checker drift: " + str(peer))
        require(repository_file(peer, "tools/check-repository-hygiene.py").read_bytes() ==
                repository_file(args.root, "tools/check-repository-hygiene.py").read_bytes(),
                "cross-repository hygiene checker drift: " + str(peer))
    print(f"Delivery policy wiring passed: {manifest['role']} ({POLICY_ID}); not a release/hardware verdict")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError) as error:
        print("Delivery policy gate failed: " + str(error), file=sys.stderr)
        sys.exit(1)
