# finhq-download.ps1 — interactive FinHQ model downloader (Windows / PowerShell).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$BaseUrl   = if ($env:FINHQ_BASE_URL) { $env:FINHQ_BASE_URL.TrimEnd('/') } else { 'https://finhq.ai' }
$TokenFile = Join-Path $HOME '.finhq_token'
function Get-FinhqToken {
    if ($env:FINHQ_TOKEN) { return $env:FINHQ_TOKEN.Trim() }
    if (Test-Path $TokenFile) { return ((Get-Content -Raw $TokenFile).Trim()) }
    Write-Host "Enter your FinHQ token (starts with fhq_  --  from the FinHQ app > MCP/Connect):"
    $sec  = Read-Host -Prompt 'Token' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try   { $tok = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $tok = $tok.Trim()
    if (-not $tok) { throw 'No token entered.' }
    $save = Read-Host "Save this token to $TokenFile so you aren't asked again? [y/N]"
    if ($save -match '^[Yy]') {
        Set-Content -Path $TokenFile -Value $tok -NoNewline
        Write-Host "Saved. (Delete $TokenFile to remove it.)"
    }
    return $tok
}
$Token = Get-FinhqToken
if (-not $Token) { throw 'No FinHQ token available.' }
$ticker = (Read-Host 'Ticker (e.g. MU)').ToUpper().Trim()
if ($ticker -notmatch '^[A-Z0-9.\-]{1,10}$') { throw "'$ticker' does not look like a valid ticker." }
$kindIn = Read-Host 'Full model or Input tab only? [F/i]'
if ($kindIn -match '^[Ii]') { $tool = 'send_input_tab'; $suffix = 'input' }
else                        { $tool = 'send_model';     $suffix = 'model' }
$downloads = Join-Path $HOME 'Downloads'
$outDir    = if (Test-Path $downloads) { $downloads } else { (Get-Location).Path }
$outPath   = Join-Path $outDir ("{0}_{1}.xlsx" -f $ticker, $suffix)
$body = @{ jsonrpc='2.0'; id=1; method='tools/call'; params=@{ name=$tool; arguments=@{ ticker=$ticker } } } | ConvertTo-Json -Depth 6 -Compress
Write-Host "Requesting $ticker ($suffix)..."
try {
    $resp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/mcp" `
        -Headers @{ Authorization = "Bearer $Token"; Accept = 'application/json, text/event-stream' } `
        -ContentType 'application/json' -Body $body
} catch { throw "Could not reach $BaseUrl (check your internet / token). $_" }
if ($resp -is [string]) {
    $dataLine = ($resp -split "`n" | Where-Object { $_ -like 'data:*' } | Select-Object -Last 1)
    $json = if ($dataLine) { $dataLine -replace '^data:\s*', '' } else { $resp }
    $resp = $json | ConvertFrom-Json
}
$text = (($resp.result.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) -join '').Trim()
if ($resp.result.isError -or $resp.error) { throw "FinHQ says: $text" }
$match = [regex]::Match($text, 'https://\S*api/model/xlsx\S*')
if (-not $match.Success) { throw "No download link returned. FinHQ says: $text" }
$url = $match.Value
try { Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing }
catch { throw "Download failed (the link may have expired -- links last ~30 min; just run again). $_" }
Write-Host ''
Write-Host "Saved: $outPath"
