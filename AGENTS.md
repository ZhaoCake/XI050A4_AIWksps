# Colorlight i9+ v6.1 FPGA 工程（纯命令行 Vivado 工作流）

基于 XC7A50T-FGG484（Artix-7）的纯命令行 FPGA 模板，专为 AI 协作开发设计：改 RTL → `sim` 验证 → `bitstream` → 用户 `program` 上板。协作协议详见 `docs/AI_WORKFLOW.md`（必读）。

## Commands

**Windows**（原版入口，PowerShell）：`.\build.ps1 <target>`，等价 `build.bat`。

**Linux**（`build.sh`，bash 编写，fish/zsh 均可直接调用）：`./build.sh <target>`。参数同名：`-VivadoBin <path>`（或 `$VIVADO_BIN`、`$XILINX_VIVADO`、PATH）、`-NoLog`。Vivado 发现顺序：`-VivadoBin` > `$VIVADO_BIN` > `$XILINX_VIVADO/bin` > PATH。本机实测：Vivado 2025.2 位于 `/home/cake/Xilinx/2025.2/Vivado`（`XILINX_VIVADO` 已设置）。

```bash
./build.sh init          # 创建工程并收集 rtl/ constr/ sim/ ip/ 源文件（幂等）
./build.sh sim           # 行为仿真（xsim）—— 修改逻辑后必须先 PASS 再上板
./build.sh bitstream     # 综合+实现+.bit（日常主命令；mtime 增量，自动只重跑受影响阶段）
./build.sh synth         # 仅综合
./build.sh impl          # 实现到 route_design（无 bitstream）
./build.sh report        # 时序/资源/功耗报告 → build/reports/
./build.sh program       # JTAG 下载（SRAM）—— ⚠️ 仅用户可运行
./build.sh flash         # 烧 SPI Flash（覆盖！）—— ⚠️ 仅用户可运行
./build.sh clean         # 删工程与产物（保留 build/logs/）
```

## Architecture

- `config.tcl` — 板卡/工程唯一配置（part、top、proj_name、目录、仿真 runtime）；换板卡只改这里
- `scripts/build.tcl` — 工作流主脚本：每个 target 是一个 Tcl proc，末尾 dispatch；全部路径由脚本位置推导，与 cwd 无关
- `build.ps1` / `build.bat` — CLI 入口：定位 vivado、日志 tee 到 build/logs/、透传退出码（0=OK）
- `rtl/` — RTL 源码（顶层固定 `top`，当前为 blink LED 示例：`top.v` + `blink.v`）
- `constr/top.xdc` — 引脚约束（顶层端口与 XDC 必须同步）
- `sim/` — 测试平台（仿真顶层固定 `tb_top`）
- `ip/` — 本地 IP 仓库（可选，放入 .xci 即可被 init 收集）
- `reference/` — 板卡官方例程/pinout（只读）；`build/` — 全部生成物（gitignored）

## Conventions

- **ASCII-only**：`*.tcl`、`*.v`、`*.sv`、`*.xdc` 只允许 ASCII（Windows GBK 代码页会破坏中文注释/字符串，曾因此踩坑）——注释用英文；中文只写进 Markdown
- 仿真自测判据：tb 打印 `PASS:`；`build.ps1` 成功打印 `==> OK: <target>` 且退出码 0；失败找 `ERROR:` / `CRITICAL WARNING` / `Synth 8-` 等行，完整日志在 `build/logs/`
- 时序判据：`build/reports/timing_impl.rpt` 的 WNS ≥ 0；资源看 `utilization_impl.rpt`（BRAM/DSP 是否超限）
- 顶层/仿真顶层分别由 `config.tcl` 的 `top` / `sim_top` 指定；新 RTL 放 rtl/ 任意子目录，改 `init` 后自动收集
- 幂等构建：mtime 检测自动 reset 重跑，改源码后**无需手动 clean**；run 残留 Running 状态脚本会自愈
- 禁止：修改 `build/`、`reference/`；直接跑 GUI；运行 `program`/`flash`

## Notes

- **本机环境（Linux/容器）关键限制**：`/home` 整个挂载为只读 btrfs，只有工作区与 `~/.cache` 等子目录可写。Vivado 启动必须写 `~/.Xilinx/.../XilinxTclStore` 缓存，因此 `build.sh` 给 vivado 进程单独设 `HOME=build/vivado_home`（gitignored）重定向；`build.ps1` 不需要也不做此事。若无 sudo 无法 bind-mount。
- **License**：Vivado 2025.2 免费（ML Standard/WebPACK）即可跑 xc7a50t 全套流程（实测 `Got license for feature 'Implementation'`），无需 license 服务器。
- 实测全流程通过（2026-08-02）：init → sim（PASS: blink works）→ bitstream（DRC 0 errors，top.bit）→ report（WNS=34.6ns 收敛）。
