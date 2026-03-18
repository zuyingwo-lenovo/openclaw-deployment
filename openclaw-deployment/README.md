# OpenClaw 自动化部署方案 (Windows 11 + WSL2)

本方案旨在 Windows 11 环境下，通过 WSL2 (Ubuntu) 自动部署一套完整、可运行、可重跑的 OpenClaw AI Agent 基础设施。

## 1. 基于公开资料确认到的关键假设

在开始编写部署脚本前，我已通过官方文档确认了以下关于 OpenClaw 的关键信息：

*   **部署路径假设**：OpenClaw 官方明确推荐在 Windows 上使用 WSL2 (Ubuntu) 进行部署。CLI 和 Gateway 运行在 Linux 内部，以保持运行时一致性并提高工具的兼容性。
*   **安装方式与环境要求**：Node 最低版本要求为 22 LTS，推荐版本为 Node 24。官方推荐使用全局 npm 安装或一键脚本。
*   **主流内置 Tools**：`browser`, `canvas`, `nodes`, `cron`, `exec` 等已成为一等公民 (first-class tools)，不再作为普通 skills 存在。
*   **Skills 与 Tools 的边界**：核心能力依赖 tools，外部服务集成（如 GitHub、Postgres）依赖 skills。
*   **Skills 管理**：社区 skills 不稳定，因此不硬编码，而是通过 `skills-manifest.yaml` 结合 ClawHub 注册表进行声明式管理。

## 2. 架构决策说明

*   **主控分离架构**：Windows 仅作为宿主负责启用 WSL2 和配置开机自启。所有 OpenClaw 核心组件、Node.js 运行时、Python 工具链和受管浏览器均运行在 WSL2 (Ubuntu) 内部。
*   **服务自启**：利用 systemd 在 WSL2 中以用户服务 (`systemctl --user`) 方式运行 OpenClaw Gateway。Windows 侧通过计划任务确保 WSL 实例在开机时启动。
*   **浏览器支持策略**：优先采用最稳定的 **OpenClaw-managed browser (headless Chromium)** 方案，运行在 WSL2 内部。不推荐连接 Windows 宿主 Chrome，因为跨子系统通信容易因防火墙或端口代理配置失败。
*   **主流 Tools 准备情况**：
    *   **browser**: 安装了 `chromium-browser` 及相关依赖库 (libnss3, libgbm1 等)。
    *   **cron / nodes / canvas**: 作为内置工具，在 `openclaw.base.json` 中默认开启。
    *   **shell / Python / Node**: 安装了 Python 3, uv, pipx, Node.js 24, npm, pnpm, bun。
    *   **Git / 媒体处理**: 安装了 git, gh, ffmpeg, imagemagick, sqlite3, 7zip 等基础依赖。
    *   **Docker**: 作为可选项在 manifest 中列出，要求用户在 Windows 端安装 Docker Desktop 并开启 WSL2 集成。

## 3. 文件树

```
openclaw-deployment/
├── README.md                 # 本文档
├── deploy-openclaw.ps1       # Windows 侧入口执行脚本
├── bootstrap-openclaw.sh     # WSL2 侧核心安装脚本
├── verify-openclaw.sh        # 安装后验证脚本
├── uninstall-openclaw.sh     # 清理与卸载脚本
├── skills-manifest.yaml      # Skills 配置清单
├── install-skills.sh         # 基于清单的 Skills 安装器
├── .env.example              # 环境变量模板
└── openclaw.base.json        # 最小可运行配置模板
```

## 4. 安装前提

1.  Windows 11 系统。
2.  具有管理员权限（运行入口脚本需要）。
3.  确保网络畅通，能够访问 GitHub、npm registry 和 Ubuntu 软件源。

## 5. 执行步骤

1.  将整个 `openclaw-deployment` 文件夹复制到 Windows 机器上（例如 `C:\openclaw-deployment`）。
2.  右键点击“开始”菜单，选择 **“Windows PowerShell (管理员)”** 或 **“终端 (管理员)”**。
3.  在 PowerShell 中，进入该文件夹并执行入口脚本：
    ```powershell
    cd C:\openclaw-deployment
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\deploy-openclaw.ps1
    ```

该脚本将自动检查并安装 WSL2、配置 systemd、并将文件复制到 WSL 内部执行 `bootstrap-openclaw.sh`。

## 6. 验证步骤

部署完成后，在 WSL2 终端（打开 Ubuntu 应用）中执行以下操作：

1.  **配置 API Keys**：
    ```bash
    cp ~/.openclaw/.env.example ~/.openclaw/.env
    nano ~/.openclaw/.env  # 填入你的模型 API Key (如 OPENAI_API_KEY)
    ```
2.  **安装 Skills**：
    ```bash
    cd ~/openclaw-setup
    ./install-skills.sh
    ```
3.  **运行健康检查**：
    ```bash
    ./verify-openclaw.sh
    ```
    该脚本会验证 openclaw 版本、doctor 状态、gateway 状态、skills 列表和 browser 连通性。

## 7. 常见故障与修复

*   **脚本执行失败**：检查 `deploy-openclaw.log` (Windows 侧) 或 `~/openclaw-setup/bootstrap-openclaw.log` (WSL 侧) 了解具体错误。
*   **Gateway 未启动**：在 WSL 中运行 `systemctl --user status openclaw-gateway` 或 `journalctl --user -u openclaw-gateway` 查看服务日志。
*   **找不到 OpenClaw 命令**：尝试运行 `source ~/.bashrc` 或重新打开 Ubuntu 终端。
*   **Skills 安装失败**：确保已安装 `clawhub` 且网络能正常访问。可以手动运行 `clawhub install <slug>` 进行测试。
*   **浏览器工具报错**：确保 WSL 中已安装 `chromium-browser`。如果使用 headless 模式仍有问题，可检查 `~/.openclaw/openclaw.json` 中的 `browser` 配置。

## 8. 升级与卸载方式

**升级方式**
在 WSL2 终端中执行：
```bash
sudo npm install -g openclaw@latest
openclaw doctor  # 检查并修复配置
systemctl --user restart openclaw-gateway
clawhub update --all # 更新 Skills
```

**卸载方式**
在 WSL2 终端中运行卸载脚本：
```bash
cd ~/openclaw-setup
./uninstall-openclaw.sh
```

## 9. 你不确定的地方与替代方案

*   **社区 Skills 的稳定性**：ClawHub 上的 skills 质量参差不齐。
    *   *替代方案*：在 `skills-manifest.yaml` 中，我将核心功能依赖于内置 tools，而将外部 skills 标记为 optional 或明确声明了依赖项。
*   **Windows 原生浏览器连接**：通过 CDP 连接 Windows 宿主机的 Chrome 在 WSL2 网络模式下经常遇到端口代理和防火墙问题。
    *   *替代方案*：我强制选用了 WSL2 内部的 headless Chromium (`browser.defaultProfile: "openclaw"`)，这是最稳定且被官方推荐的做法。如果用户强烈要求连接宿主机浏览器，需在 Windows 侧配置 `netsh interface portproxy` 并修改 `openclaw.json` 中的 `cdpUrl`，但这不作为默认推荐。

---

### 最小执行清单 (First-time Deployment)

如果你想手动逐步执行，或者在脚本报错后继续，以下是核心步骤：

**Windows (Admin PowerShell):**
1. `wsl --install -d Ubuntu-24.04`
2. `wsl --set-default-version 2`

**WSL2 (Ubuntu Terminal):**
1. `sudo apt update && sudo apt install -y curl git jq build-essential`
2. `curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt install -y nodejs`
3. `sudo npm install -g openclaw@latest`
4. `openclaw onboard --install-daemon`
