# OpenClaw 部署架构决策与关键假设

## 1. 基于公开资料确认到的关键假设

在开始编写部署脚本前，我已通过官方文档确认了以下关于 OpenClaw 的关键信息：

*   **部署路径假设**：OpenClaw 官方明确推荐在 Windows 上使用 WSL2 (Ubuntu) 进行部署。CLI 和 Gateway 运行在 Linux 内部，以保持运行时一致性并提高工具（Node/Bun/pnpm、Linux 二进制文件、Skills）的兼容性。
*   **安装方式与环境要求**：
    *   推荐安装方式是使用官方的 `curl -fsSL https://openclaw.ai/install.sh | bash` 脚本，它会自动处理 Node 检测、安装和 onboarding。
    *   Node 最低版本要求为 22 LTS（当前 22.16+），推荐版本为 Node 24。
*   **主流内置 Tools**：OpenClaw 已经将许多核心能力提升为 first-class tools（不再依赖 skills）。这些包括：
    *   `browser`（受管浏览器）
    *   `canvas`（可视化工作区）
    *   `nodes`（设备节点）
    *   `cron`（定时任务）
    *   `exec` / `process` / `apply_patch`（运行时与文件系统操作）
    *   `web_search` / `web_fetch`（网络工具）
*   **Skills 与 Tools 的边界**：核心系统交互（如执行命令、控制浏览器、读写文件）已内置为 Tools。Skills 现在主要用于扩展特定服务集成（如 GitHub、Google Workspace 等）或提供特定的工作流。
*   **Skills 管理机制**：OpenClaw 支持 bundled skills（内置）、managed/local skills（`~/.openclaw/skills`）和 workspace skills（`<workspace>/skills`）。社区提供了一个名为 ClawHub 的公共注册表（`clawhub install <slug>`）来管理外部 skills。

## 2. 架构决策说明

基于上述确认信息，我设计了以下部署架构：

*   **主控分离架构**：
    *   **Windows 宿主机**：仅负责基础设施的准备（启用 WSL2、安装 Ubuntu、配置必要的网络转发和开机自启）。所有实际运行负载均不在原生 Windows 上。
    *   **WSL2 (Ubuntu) 运行时**：作为 OpenClaw 的唯一核心运行环境。安装 Node.js、Python、Git、Docker 等所有依赖。
*   **服务自启与守护机制**：
    *   使用 systemd 管理 OpenClaw Gateway 服务（`systemctl --user`）。
    *   在 Windows 侧配置计划任务（Scheduled Tasks），在系统启动时调用 `wsl.exe` 以确保 WSL2 实例启动，从而触发 systemd 启动 OpenClaw Gateway。
*   **浏览器策略**：
    *   采用 **OpenClaw-managed browser (headless/Linux)** 方案作为默认首选。因为在 WSL2 内运行独立的 Chromium 实例最稳定，且完全隔离于用户的日常浏览器。
    *   通过 `browser.executablePath` 或内置的自动下载机制确保浏览器在 WSL2 中可用。
*   **Skills 扩展策略**：
    *   不硬编码易变的社区 skills。采用清单文件 (`skills-manifest.yaml`) 驱动的安装方式。
    *   默认启用官方 bundled skills。
    *   对于外部 skills，提供示例并说明如何使用 ClawHub 或 Git 克隆安装到 `~/.openclaw/skills`。
*   **幂等性与错误处理**：
    *   所有 PowerShell 和 Bash 脚本均包含状态检查。例如：安装前检查是否已安装，目录创建前检查是否存在。
    *   Bash 脚本使用 `set -Eeuo pipefail`，PowerShell 使用 `$ErrorActionPreference = "Stop"`。

## 3. 文件树结构

最终交付将包含以下文件：

```
openclaw-deployment/
├── README.md                 # 架构说明、安装指南、故障排查
├── deploy-openclaw.ps1       # Windows 侧入口执行脚本
├── bootstrap-openclaw.sh     # WSL2 侧核心安装脚本
├── verify-openclaw.sh        # 安装后验证脚本
├── uninstall-openclaw.sh     # 清理与卸载脚本
├── skills-manifest.yaml      # Skills 配置清单
├── install-skills.sh         # 基于清单的 Skills 安装器
├── .env.example              # 环境变量模板
└── openclaw.base.json        # 最小可运行配置模板
```
