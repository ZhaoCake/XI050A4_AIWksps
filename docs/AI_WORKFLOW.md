# AI 融合开发流协议（AI 协作必读）

本文档定义 AI 助手（以下简称 AI）在本工程中的**操作边界**与**反馈协议**，
使 AI 可以在无人值守下完成「改代码 → 编译 → 读报告 → 修复 → 上板」的闭环，
同时保证工程安全、可复现。

## 1. 角色分工

| 角色 | 职责 |
| ---- | ---- |
| 你（用户） | 定需求、做决策、上板验证硬件现象、跑 `program`/`flash` 等硬件操作 |
| AI | 编写/修改 RTL、约束、测试平台；运行构建与仿真；阅读日志和报告；定位并修复问题 |

## 2. AI 可执行的操作

```powershell
.\build.ps1 init          # 工程初始化（改目录结构/加文件后）
.\build.ps1 synth         # 综合
.\build.ps1 impl          # 实现
.\build.ps1 bitstream     # 生成比特流（AI 迭代的主命令）
.\build.ps1 sim           # 仿真（AI 自测的主命令，必须 PASS 再上板）
.\build.ps1 report        # 生成并阅读时序/资源报告
.\build.ps1 clean         # 清理（谨慎使用）
```

以及安全的文件操作：读写 `rtl/`、`constr/`、`sim/`、`config.tcl`、`scripts/build.tcl`、`docs/`、`README.md`。

## 3. AI 禁止的操作

- ❌ **禁止运行 `program` / `flash`**（涉及硬件与 Flash 覆盖，必须由用户执行）
- ❌ **禁止修改 `build/`、`reference/`**（生成物与只读参考资料）
- ❌ **禁止直接执行 GUI（`vivado` 交互模式）**
- ❌ **禁止向 `rtl/`、`constr/`、`sim/`、`scripts/` 引入非 ASCII 字符**（见第 6 节）

## 4. AI 迭代闭环（标准流程）

```
1. 理解需求 → 编写/修改 rtl/*.v 与 constr/top.xdc、sim/tb_top.v
2. 运行 .\build.ps1 sim          → 断言全 PASS 才算逻辑正确
3. 运行 .\build.ps1 bitstream    → 生成最新 .bit
4. 运行 .\build.ps1 report       → 阅读 build/reports/ 检查时序收敛、资源占用
5. 汇报给用户：改动内容、仿真结果、时序/资源摘要
6. 用户执行 .\build.ps1 program → 上板验证，反馈现象
7. 若有问题，回到 1（结合现象定位，如 LED 行为、时序违例）
```

## 5. 反馈信息约定

- **成功判据**：build.ps1 打印 `==> OK: <target>` 且退出码为 0。
- **失败判据**：打印 `==> FAILED: <target> (exit=N)` 或 `ERROR:` 行；完整日志在 `build/logs/<target>_<时间戳>.log`。
- **定位错误**：优先搜索日志中的 `ERROR:`、`CRITICAL WARNING`、`Synth 8-`/`Place 30-`/`Route 19-` 等 ID 行；综合/实现错误摘要见 `build/bigpig_i9p/bigpig_i9p.runs/synth_1/runme.log`、`impl_1/runme.log`。
- **时序检查**：读 `build/reports/timing_impl.rpt` 中 `Timing constraints` 段的 WNS/TNS；**WNS ≥ 0** 为收敛。
- **资源检查**：读 `build/reports/utilization_impl.rpt` 中的使用率，关注 BRAM/DSP 是否超限。

## 6. 编码规范（重要）

Windows 中文系统下，Vivado 的 Tcl/HDL 读取默认按系统代码页（GBK）解析，UTF-8 中文会
导致字节错位，**可能破坏命令替换与字符串常量**（本项目曾因此踩坑）。因此：

- `*.tcl`、`*.v`、`*.sv`、`*.xdc` 文件**只允许 ASCII 字符**（注释与输出全部英文）。
- Markdown 文档（README、本文件）可用中文，不受影响。
- AI 在修改代码时的注释请使用英文。

## 7. 构建系统行为（AI 需了解）

- **幂等**：产物最新时 `bitstream` 等目标秒级跳过。
- **mtime 检测**：源码（rtl/、constr/ 下所有文件）mtime 比产物新 → 自动 reset 对应 run 并全量重跑；因此**修改任何源文件后无需手动 clean**。
- **僵尸状态自愈**：若 Vivado 进程被中断（Ctrl+C、超时），run 可能残留 `Running` 状态；脚本会自动 `reset_run` 后再启动。
- **日志**：每次构建的完整 Vivado 输出在 `build/logs/`，按目标+时间戳命名，可追溯。

## 8. 常见 AI 失误与规避

| 失误 | 规避 |
| ---- | ---- |
| 修改了 top 端口名但漏改 top.xdc | 顶层与约束端口必须同步修改；综合报 `get_ports` 找不到即此问题 |
| 只改 RTL 不跑仿真就上板 | 先 `sim` 全 PASS，再 `bitstream` |
| 在注释/字符串里写中文 | 保持 ASCII；报错多为乱码或奇怪语法错误 |
| 反复 `clean` 丢失增量 | 不需要；mtime 检测已自动处理重建 |
| 直接跑 `program`/`flash` | 硬件操作一律留给用户 |
