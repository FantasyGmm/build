# CM5 device-tree guide / CM5 设备树指南

## 中文

### 分层与编译结果

内核设备树入口是：

`patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-dshanpi-a1-cm5.dts`

它按以下顺序组合，后加载的文件可覆盖前面的属性：

1. `rk3576.dtsi`：Rockchip RK3576 SoC 定义。
2. `rk3576-100ask-a1-cm5-common.dtsi`：CM5 通用电源、PMIC、存储、网络、USB、音频、SDIO 等。
3. `rk3576-100ask-a1-cm5-ov13850-3cam.dtsi`：三路 OV13850 的 I2C、MIPI CSI、RKCIF/RKISP 数据链路。
4. `rk3576-100ask-a1-cm5-1024-768-mipi.dtsi`：1024×768 DSI 屏、背光和旧版触摸描述。
5. `rk3576-100ask-a1-cm5-base-v1.dtsi`：依据 2026-09-18 CM5 底板原理图做最终覆盖。

最终 DTB 为 `rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb`。板级配置通过独立的 `LINUXFAMILY=rk3576-dshanpi-a1-cm5` 和补丁层生成它，不会覆盖原 A1 的 `rk35xx` 内核包。

### 已适配的关键硬件

- GT911：旧的 I2C4/GPIO4_C6 实例被禁用；CM5 使用 I2C9_M1、GPIO3_D0 中断、GPIO0_C1 复位。
- AIC8800D80：SDIO 电源时序、GPIO4_B0 复位、固件路径、三个 DKMS 模块及 UART7 蓝牙配置。
- 三路 OV13850：I2C2/FPC4、I2C3/FPC6、I2C5/FPC7，分别接入 DCPHY0、DPHY1、DPHY4，再进入 MIPI0/1/3、RKCIF 和 RKISP。
- 显示：四 lane MIPI DSI，1024×768，PWM0 背光。
- 音频：ES8388 耳机/扬声器/双麦路由，GPIO4_B5 插拔检测，GPIO4_B4 模拟开关门控；释放 GPIO1_D0 给 SAI2。
- USB/PCIe：默认启用 USB2 OTG1 hub 路径并禁用 PCIe1，两者不可同时启用；PCIe0 保留。
- 其他：双千兆网口、UFS/eMMC/SD、USB-C/DP、PWM 风扇、WS2812、BT SCO。

### 修改规则

1. 先确认原理图网络名、电源域、电平、复用组和设备树 binding。
2. SoC 通用定义不要复制；通用硬件放 common，摄像头拓扑放 3cam，底板差异放 base-v1。
3. 修改 endpoint 时同时核对双向 `remote-endpoint`、`reg`、lane 数和 ISP/CIF 入口。
4. 若覆盖旧节点，显式 `status = "disabled"` 或 `/delete-property/`，并保留解释原因的注释。
5. 不要修改原 A1 的板文件、相机扩展、U-Boot DTS 补丁和共享 defconfig。
6. 内核 DT 与 U-Boot DT 分开维护：U-Boot 只保留启动所需的最小设备树；CM5 板 hook 在临时 `.config` 中选择它。
7. 当前 `sdio-pwrseq` 的 `clocks = <&rk806 1>` 会触发供应商树的 `#clock-cells` 非致命告警。没有硬件和 binding 证据时不要猜测性修改。

本仓库未包含所引用的 CM5 底板原理图；涉及新引脚迁移时必须由维护者提供对应 revision 的外部原理图或等价硬件证据。供应商树的自定义 binding/schema 也可能不完整，因此完整 Armbian 构建中的 DT 编译是最低门槛；若工作树具备完整 schema，再额外执行对应 DTB 的 `dtbs_check`，并逐条区分真实错误与已记录的供应商告警。

### 验证

运行 source gate、完整构建和只读镜像检查。至少确认最终 DTB 可反编译、存在 3 个 `ovti,ov13850` 节点、包含 `wifi_chip_type = "aic8800"`。具体总线/引脚变更还要用 `dtc` 或 `fdtget` 检查节点数量、`status`、pinctrl、IRQ/reset、地址以及同总线其他设备；通用镜像脚本不会推断某次改线是否正确。最后在真机逐项测试启动、显示/触摸、三摄、无线、USB/PCIe、音频和风扇。

## English

### Layers and output

The kernel entry point is `rk3576-100ask-dshanpi-a1-cm5.dts` in the dedicated CM5 kernel patch layer. It includes, in order, the RK3576 SoC DTSI, CM5 common hardware, the three-camera graph, the 1024×768 panel, and the base-v1 schematic overrides. Later includes intentionally override earlier properties. The result is `rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb` in the isolated `rk3576-dshanpi-a1-cm5` kernel namespace.

The base-v1 overrides move GT911 from I2C4 to I2C9_M1, remove the inherited HDMI GPIO conflict with SDIO D2, correct USB/PCIe selection, release SAI2 from an invalid PCIe regulator, and apply CM5 audio routing. The camera layer connects three two-lane OV13850 sensors on I2C2/I2C3/I2C5 through DCPHY0/DPHY1/DPHY4 to MIPI CSI0/1/3, RKCIF, and RKISP.

Place SoC-independent carrier differences in `base-v1`, camera graph changes in `ov13850-3cam`, and reusable module hardware in `common`. Keep endpoint pairs, lanes, clocks, power supplies, pinctrl, reset/power-down polarity, and I2C addresses consistent. Maintain the minimal U-Boot DTS separately, and select it only through the CM5 board's temporary-config hook.

The referenced carrier schematic is not stored in this repository, so require external revision-matched schematic evidence for new routing. The vendor tree currently emits a non-fatal clock-provider warning for the SDIO power-sequence clock. Do not change it without binding and hardware evidence. A full build is the minimum DT compile check; run targeted `dtbs_check` when complete vendor schemas are available. Inspect task-specific bus/pin properties in the compiled DTB and validate every affected interface on physical hardware.
