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
   save it to `%USERPROFILE%\.finhq_token` so you're not asked again.
3. Requirements: Windows PowerShell 5.1 (built into Windows 10/11). Nothing to install.

## Security
The token is a live credential to your FinHQ account. It is never stored in the
repo — only in the env var or `%USERPROFILE%\.finhq_token`. `.gitignore` keeps
`.env`, `.finhq_token`, and downloaded `.xlsx` files out of git.
