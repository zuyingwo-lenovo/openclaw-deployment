# OpenClaw Automated Deployment Guide (Windows 11 + WSL2)

This guide provides an automated solution for deploying a complete, runnable, and repeatable OpenClaw AI Agent infrastructure on Windows 11 using WSL2 (Ubuntu).

## 1. Key Assumptions from Public Documentation

Before creating the deployment scripts, the following key details about OpenClaw were confirmed via official documentation:

*   **Deployment Path:** The official recommendation for Windows users is to use WSL2 (Ubuntu). The CLI and Gateway run inside Linux to ensure runtime consistency and broad tool compatibility.
*   **Installation & Environment:** Node.js version 22 LTS is the minimum requirement, though Node 24 is recommended. Global NPM installation or one-line scripts are the preferred installation methods.
*   **First-Class Built-in Tools:** `browser`, `canvas`, `nodes`, `cron`, and `exec` are now treated as first-class tools rather than generic community skills.
*   **Skills vs Tools Boundaries:** Core capabilities rely on *tools*, while external service integrations (e.g., GitHub, Postgres) rely on *skills*.
*   **Skills Management:** Because community skills can be unstable, they are not hardcoded. Instead, they are declaratively managed using a `skills-manifest.yaml` file in conjunction with the ClawHub registry.

## 2. Architectural Decisions

*   **Host/Guest Separation:** Windows acts strictly as the host to enable WSL2 and configure auto-start schedules. All OpenClaw core components, the Node.js runtime, Python toolchains, and the managed browser run entirely inside WSL2 (Ubuntu).
*   **Service Auto-Start:** OpenClaw Gateway runs as a user-level `systemd` service (`systemctl --user`) within WSL2. A Windows Scheduled Task ensures the WSL instance spins up on boot.
*   **Browser Strategy:** Prioritizes the most stable **OpenClaw-managed browser (headless Chromium)** approach running natively inside WSL2. Connecting to the Windows host's native Chrome is discouraged due to common port-proxying and firewall interference across subsystems.
*   **Built-in Tools Readiness:**
    *   **browser**: `chromium-browser` and its required dependencies (`libnss3`, `libgbm1`, etc.) are pre-installed.
    *   **cron / nodes / canvas**: Built-in tools that are enabled by default in `openclaw.base.json`.
    *   **shell / Python / Node**: Pre-installs Python 3, `uv`, `pipx`, Node.js 24, `npm`, `pnpm`, and `bun`.
    *   **Git / Media Processing**: Pre-installs `git`, `gh`, `ffmpeg`, `imagemagick`, `sqlite3`, `7zip`, and standard dependencies.
    *   **Docker**: Listed as an option in the manifest, requiring users to install Docker Desktop on Windows with WSL2 integration enabled.

## 3. Directory Structure

```text
openclaw-deployment/
├── README.md                 # This document (or README_EN.md)
├── deploy-openclaw.ps1       # Windows entry execution script
├── bootstrap-openclaw.sh     # Core installation script for WSL2
├── verify-openclaw.sh        # Post-installation verification script
├── uninstall-openclaw.sh     # Cleanup and uninstallation script
├── skills-manifest.yaml      # Declarative checklist for Skills
├── install-skills.sh         # Skills installer utilizing the manifest
├── .env.example              # Environment variables template
└── openclaw.base.json        # Minimal runnable template configuration
```

## 4. Prerequisites

1.  **Windows 11 OS.**
2.  **Administrator privileges** (Required to run the entry PowerShell script).
3.  **Active Internet connection** capable of reaching GitHub, the NPM registry, and Ubuntu APT repositories.

## 5. Deployment Steps

1.  Copy the entire `openclaw-deployment` folder to your Windows machine (e.g., `C:\openclaw-deployment`).
2.  Right-click the "Start" menu and select **Windows PowerShell (Admin)** or **Terminal (Admin)**.
3.  In PowerShell, navigate to the folder and execute the deployment script:
    ```powershell
    cd C:\openclaw-deployment
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\deploy-openclaw.ps1
    ```

The script will automatically check for/install WSL2, configure `systemd`, copy files over to the WSL environment, and execute `bootstrap-openclaw.sh`.

## 6. Verification Steps

Once deployment has finished, open your WSL2 Terminal (launch the Ubuntu app) and perform the following:

1.  **Configure API Keys:**
    ```bash
    cp ~/.openclaw/.env.example ~/.openclaw/.env
    nano ~/.openclaw/.env  # Enter your preferred model API Key (e.g., OPENAI_API_KEY)
    ```
2.  **Install Community Skills:**
    ```bash
    cd ~/openclaw-setup
    ./install-skills.sh
    ```
3.  **Run Health Checks:**
    ```bash
    ./verify-openclaw.sh
    ```
    This script verifies the installed OpenClaw version, runs the `doctor`, confirms Gateway activity, retrieves the skills list, and tests browser connectivity.

## 7. Troubleshooting

*   **Script Failures:** Review `deploy-openclaw.log` (Windows) or `~/openclaw-setup/bootstrap-openclaw.log` (WSL) for specific error output.
*   **Gateway Won't Start:** Check service logs in WSL by running `systemctl --user status openclaw-gateway` or `journalctl --user -u openclaw-gateway`.
*   **Command Not Found (`openclaw`):** Try running `source ~/.bashrc` or completely close and reopen your Ubuntu terminal.
*   **Skills Installation Fails:** Ensure `clawhub` is installed correctly and network access is unobstructed. You can manually test it using `clawhub install <slug>`.
*   **Browser Tool Errors:** Verify that `chromium-browser` was installed in WSL. If issues persist in headless mode, review the `browser` block internally stored at `~/.openclaw/openclaw.json`.

## 8. Updates and Uninstallation

**Updating:**
Run the following in your WSL2 terminal:
```bash
sudo npm install -g openclaw@latest
openclaw doctor  # Checks and repairs settings
systemctl --user restart openclaw-gateway
clawhub update --all # Updates installed skills
```

**Uninstallation:**
Run the uninstall script in your WSL2 terminal:
```bash
cd ~/openclaw-setup
./uninstall-openclaw.sh
```

## 9. Design Uncertainties & Alternatives

*   **Community Skills Stability:** Plugins on ClawHub often vary quite wildly in quality.
    *   *Alternative:* In `skills-manifest.yaml`, the core functionality purely relies upon built-in tools while external skills are isolated, heavily marked as optional, or strict about dependencies.
*   **Native Windows Browser Hooking:** Using CDP to blindly connect WSL2 back to a Windows host-installed Chrome instance historically encounters recurring port-proxy failures and firewall blocks.
    *   *Alternative:* This script mandates the usage of an isolated, headless Chromium browser living natively inside WSL (`browser.defaultProfile: "openclaw"`). This is the officially recommended, most robust solution. Users desiring hookups to the host UI browser will need to configure `netsh interface portproxy` themselves on Windows and rewrite the `cdpUrl` within `openclaw.json`.

---

### Minimal Execution Guide (Manual First-time Deployment)

If you prefer to run things step-by-step manually, or if you need to recover from a crashed script, these are the core under-the-hood commands:

**Windows (Admin PowerShell):**
1. `wsl --install -d Ubuntu-24.04`
2. `wsl --set-default-version 2`

**WSL2 (Ubuntu Terminal):**
1. `sudo apt update && sudo apt install -y curl git jq build-essential`
2. `curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt install -y nodejs`
3. `sudo npm install -g openclaw@latest`
4. `openclaw onboard --install-daemon`
