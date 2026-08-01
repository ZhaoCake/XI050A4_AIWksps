# 卡莱特 i9+ v6.1 FPGA 开发工程（纯命令行工作流模板）

基于 **XC7A50T-FGG484**（Artix-7）的纯命令行 FPGA 开发模板，为 **AI 融合开发流** 设计。
所有 Vivado 操作均通过 `vivado -mode batch` 的 Tcl 脚本完成，全程不需要打开 Vivado GUI。

> 关联资料：板卡 GitHub 例程仓库 `BigPig-Bro/xilinx/tree/main/XI050AB`（见 `reference/`）。

---

## 一、环境要求

| 项目 | 要求 |
| ---- | ---- |
| 操作系统 | Windows（PowerShell 5.1+ / 7） |
| Vivado | 2023.2（`D:\Xilinx\Vivado\2023.2\bin`，可用 `-VivadoBin` 覆盖） |
| 下载器 | 任意被 hw_server 识别的 JTAG 线（实测 Digilent 下载器可用） |
| 器件 | xc7a50tfgg484-1（Artix-7） |

## 二、目录结构

```
ai_wksps_try/
├── build.ps1 / build.bat   # 命令行入口（推荐 build.ps1）
├── config.tcl              # 板卡/工程配置（器件、顶层、路径，改板卡只动这里）
├── scripts/
│   └── build.tcl           # 工作流主脚本（所有 target 的实现）
├── rtl/                    # RTL 源码（top.v、blink.v 示例）
├── constr/                 # 引脚约束（top.xdc）
├── sim/                    # 测试平台（tb_top.v）
├── ip/                     # 本地 IP 仓库（预留，可空）
├── reference/              # 板卡参考资料（官方例程 xpr/xdc、pinout 文档，只读）
├── build/                  # 全部生成物（工程、runs、日志、报告；已 gitignore）
│   ├── bigpig_i9p/         #   Vivado 工程目录
│   ├── bigpig_i9p.runs/    #   综合/实现运行目录（产物 dcp、bit 在这里）
│   ├── logs/               #   每次构建的完整日志
│   └── reports/            #   report 目标生成的报告
└── docs/
    └── AI_WORKFLOW.md      # AI 融合开发流协议（AI 协作时必读）
```

## 三、快速开始（三步点亮 LED）

```powershell
.\build.ps1 init          # 1. 创建工程（幂等）
.\build.ps1 bitstream     # 2. 综合 + 实现 + 生成比特流（约 1~3 分钟）
.\build.ps1 program       # 3. JTAG 下载到 FPGA，板上 LED 开始流水闪烁
```

## 四、命令参考

| 命令 | 作用 | 耗时 |
| ---- | ---- | ---- |
| `init` | 创建工程并收集 rtl/、constr/、sim/、ip/ 源文件 | ~10s |
| `synth` | 综合（增量） | ~1min |
| `impl` | 实现到 route_design（不含比特流） | ~1min |
| `bitstream` | 实现并生成 `.bit`（日常最常用） | ~1~3min |
| `program` | JTAG 下载到 FPGA（SRAM 配置，断电丢失） | ~10s |
| `flash` | 生成 `.bin` 并烧写 SPI Flash（**覆盖 Flash！** 见警告） | ~1min |
| `sim` | 运行行为仿真（xsim） | ~1min |
| `report` | 生成时序/资源/功耗报告到 build/reports/ | ~10s |
| `clean` | 删除工程与产物（保留日志） | ~5s |
| `help` | 帮助 | - |

入口参数：

```powershell
.\build.ps1 bitstream                  # 默认 Vivado 路径
.\build.ps1 bitstream -VivadoBin D:\Xilinx\Vivado\2022.2\bin
.\build.ps1 bitstream -NoLog           # 不写日志（默认写 build/logs/）
```

也可以绕过入口直接跑 Tcl：

```bat
D:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -notrace -nojournal -source scripts\build.tcl -tclargs bitstream
```

## 五、日常开发循环（改代码 → 上板）

```
编辑 rtl/*.v 或 constr/*.xdc
    ↓
.\build.ps1 bitstream     # 自动检测源码变化，只重跑受影响阶段
    ↓
.\build.ps1 program       # 下载，观察板上现象
    ↓
（改）回到第一步
```

脚本通过 **mtime 对比源码与产物** 判断是否需要重跑：源码比产物新则自动 reset 并重综合/重实现；产物是最新则秒级跳过。修改 `rtl/top.v`、`blink.v`、`constr/top.xdc` 都会触发正确重建。

## 六、常见问题

**Q1：为什么脚本输出全是英文？**
Windows 中文系统下，Vivado 的 Tcl 默认按系统代码页（GBK）读取/输出，UTF-8 的中文会导致字节错位（甚至破坏 `[llength ...]` 这类命令替换，导致计数、分支判断出错）。为彻底规避，所有被 Vivado 处理的文件（`.tcl`、`.v`、`.xdc`）均保持 ASCII；中文只出现在 Markdown 文档里。

**Q2：JTAG 连接失败？**
`program` 会打印 `ERROR: failed to connect JTAG ...`。检查：板卡供电、下载线、驱动（Vivado 安装时包含 Digilent 驱动，Windows 设备管理器应能看到 `Digilent USB Device`）。可用 `hw_server` 单独确认：`vivado -mode batch` 里跑 `open_hw_manager; connect_hw_server; open_hw_target`。

**Q3：为什么修改源码后 bitstream 没有重跑？**
正常情况下不会发生（脚本用 mtime 检测）。若你手动 `touch` 了旧文件或工具保留了原时间戳，可执行 `clean` 后重新 `bitstream` 强制全量构建。

**Q4：如何添加新模块/IP？**
- 新 RTL：放到 `rtl/` 下任意子目录，下次 `init` 会自动收集（或在 GUI 里 add_files 后继续用命令行）。
- 新 IP：把 `.xci` 放入 `ip/`，`init` 会自动添加并启用本地 IP 仓库。
- 新引脚：在 `constr/top.xdc` 中按现有格式追加 `set_property`（端口名须与顶层一致）。

**Q5：flash 目标的风险？**
`flash` 会**覆盖板上 SPI Flash（MX25L128）全部内容**。出厂固件不可恢复，请先备份原始 Flash 内容再操作。日常调试用 `program`（SRAM）即可，不要轻易烧 Flash。

**Q6：如何适配其它板卡？**
只需改 `config.tcl` 顶部的 `part`、`top`、`proj_name` 和目录路径，其余脚本无需改动。

## 七、AI 融合开发流

本项目定位为 AI 协作开发模板：AI 负责编写/修改 RTL、约束、测试平台，并读取日志与报告迭代修复；你负责上板验证与决策。AI 的操作边界与反馈协议见 **[docs/AI_WORKFLOW.md](docs/AI_WORKFLOW.md)**。
