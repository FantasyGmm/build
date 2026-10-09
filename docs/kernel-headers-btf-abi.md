# Preserve BTF configuration when installing kernel headers

An A1 hardware test on 2026-10-09 exposed an ABI mismatch that a successful
DKMS build and matching vermagic did not detect. The running
`6.1.115-vendor-rk35xx` kernel enabled `CONFIG_DEBUG_INFO_BTF_MODULES`, while
the installed headers disabled it. The published headers archive contained
the correct configuration; its `postinst` ran `make olddefconfig` without
`pahole` installed and Kconfig silently removed the BTF settings.

This option changes `struct module`. On the affected board the original
kernel's `pwm-fan.ko` had a `.gnu.linkonce.this_module` section of 0x380 bytes;
the AXCL and AIC DKMS modules built against the changed headers had only
0x340 bytes. AXCL reported `device[0] already exists` during PCI probe.
Attempting to unload the unbound module then produced a kernel Oops in
`__arm64_sys_delete_module`. Do not use unloading as a recovery procedure
for modules built with this mismatch.

The headers packaging callback now conditionally depends on `pahole` for
BTF-enabled kernels and rejects installation if `olddefconfig` changes the
kernel's BTF or BTF_MODULES settings. `tools/test-kernel-headers-btf.py`
exercises the generated maintainer script with preserved and silently
removed settings, including kernels built without BTF. CI runs this test.
The change applies to headers packaging for all boards; it changes no
device tree, kernel configuration, U-Boot file, or package namespace.

Existing installations require `pahole` to be configured **before**
reinstalling their exact matching headers archive. All external modules
previously built against the altered configuration must then be rebuilt
through DKMS. Verify generated BTF configuration, module structure size,
vermagic and package integrity, then boot a clean kernel before loading
the rebuilt modules. Merely installing pahole does not restore a
configuration already rewritten by olddefconfig.

Under DELIVERY_POLICY.md G03/G12, an updated headers DEB must have a new
version and a recorded mapping to the image/kernel it supports. Existing
published DEBs remain immutable. This source change alone does not claim
that updated headers packages have been published for every board.
