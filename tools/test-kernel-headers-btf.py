#!/usr/bin/env python3
"""Exercise the generated headers postinst against Kconfig ABI drift."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HeadersBtfTests(unittest.TestCase):
    def test_postinst_rejects_btf_module_layout_changes(self):
        source = (ROOT / "lib/functions/compilation/kernel-debs.sh").read_text()
        callback = source.split("function kernel_package_callback_linux_headers() {", 1)[1]
        body = callback.split("cat <<- EOT_POSTINST\n", 1)[1].split("\n\t\tEOT_POSTINST", 1)[0]
        for expected in ("", "CONFIG_DEBUG_INFO_BTF=y\nCONFIG_DEBUG_INFO_BTF_MODULES=y"):
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                env = dict(os.environ, headers_btf_expected=expected,
                           SRC_ARCH="arm64", kernel_version_family="test")
                generated = subprocess.check_output(
                    ["bash", "-c", "cat <<- EOT\n" + body + "\nEOT\n"], env=env, text=True)
                generated = generated.replace('cd "/usr/src/linux-headers-test"', 'cd "$TEST_HEADERS_DIR"')
                script = root / "postinst"
                script.write_text("#!/bin/bash\nset -e\n" + generated)
                make = root / "make"
                make.write_text("#!/bin/sh\ncase \"$*\" in *olddefconfig*) "
                                "if [ \"$TEST_DROP_BTF\" = 1 ]; then "
                                "sed -i '/^CONFIG_DEBUG_INFO_BTF/d' .config; fi;; esac\n")
                make.chmod(0o755)
                env.update(PATH=str(root) + ":" + os.environ["PATH"], TEST_HEADERS_DIR=str(root))
                for drop in ("0", "1"):
                    (root / ".config").write_text(expected + "\nCONFIG_MODULES=y\n")
                    env["TEST_DROP_BTF"] = drop
                    result = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True)
                    should_fail = bool(expected) and drop == "1"
                    self.assertEqual(result.returncode != 0, should_fail, result.stdout + result.stderr)
                    if should_fail:
                        self.assertIn("BTF/module ABI", result.stderr)


if __name__ == "__main__":
    unittest.main()
