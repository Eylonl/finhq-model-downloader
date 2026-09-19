# finhq-model-downloader

Interactive Windows tool to download FinHQ financial model workbooks (.xlsx).
Double-click `finhq-download.bat` (or run `finhq-download.ps1` in PowerShell),
type a ticker, and it saves the model to your Downloads folder.

## How it works
FinHQ download links expire in ~30 minutes and are tied to your account, so
they can't be hardcoded. The script makes one authenticated call to
`https://finhq.ai/api/mcp` (a JSON-RPC `tools/call` to `send_model` or
`send_input_tab`, with your token as a Bearer credential), gets a fresh signed
link, and downloads it.

## Setup
1. Get your FinHQ personal token (starts with `fhq_`) from the FinHQ app's
   MCP / Connect settings.
2. Run the tool. On first run it prompts for the token (hidden) and offers to
   save it as a per-user Windows environment variable (`FINHQ_TOKEN`) so you're
   not asked again. It's stored in your Windows user profile (the registry under
   `HKCU\Environment`), not in any file in this folder.

   Or set it yourself once in PowerShell (User scope = persists across sessions
   and reboots), then just run the tool:

   ```powershell
   [Environment]::SetEnvironmentVariable('FINHQ_TOKEN', 'fhq_xxxx', 'User')
   ```

   Open a new PowerShell window afterward so the variable is picked up.
3. Requirements: Windows PowerShell 5.1 (built into Windows 10/11). Nothing to install.

## Security
The token is a live credential to your FinHQ account. It is never stored in the
repo or in a `.env` file — only as the `FINHQ_TOKEN` environment variable on your
machine. To remove it later, clear `FINHQ_TOKEN` in Windows *System > Environment
Variables* (or run `[Environment]::SetEnvironmentVariable('FINHQ_TOKEN',$null,'User')`
in PowerShell). `.gitignore` keeps stray `.env` files and downloaded `.xlsx` files
out of git.
