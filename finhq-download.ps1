# finhq-download.ps1 — interactive FinHQ model downloader (Windows / PowerShell).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$BaseUrl   = if ($env:FINHQ_BASE_URL) { $env:FINHQ_BASE_URL.TrimEnd('/') } else { 'https://finhq.ai' }
function Get-FinhqToken {
    if ($env:FINHQ_TOKEN) { return $env:FINHQ_TOKEN.Trim() }
    $stored = [Environment]::GetEnvironmentVariable('FINHQ_TOKEN', 'User')
    if ($stored) { return $stored.Trim() }
    Write-Host "Enter your FinHQ token (starts with fhq_  --  from the FinHQ app > MCP/Connect):"
    $sec  = Read-Host -Prompt 'Token' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try   { $tok = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $tok = $tok.Trim()
    if (-not $tok) { throw 'No token entered.' }
    $save = Read-Host "Save this token as a Windows environment variable (FINHQ_TOKEN) so you aren't asked again? [y/N]"
    if ($save -match '^[Yy]') {
        [Environment]::SetEnvironmentVariable('FINHQ_TOKEN', $tok, 'User')
        $env:FINHQ_TOKEN = $tok
        Write-Host "Saved as user environment variable FINHQ_TOKEN."
        Write-Host "(Remove it later with:  setx FINHQ_TOKEN """"  then delete it in System > Environment Variables, or run  [Environment]::SetEnvironmentVariable('FINHQ_TOKEN',`$null,'User'))"
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
if (-not $text -and $resp.error) { $text = "$($resp.error.message)".Trim() }
if ($resp.result.isError -or $resp.error) {
    if (-not $text) { $text = "the model for '$ticker' is not available." }
    throw "FinHQ says: $text"
}
$match = [regex]::Match($text, 'https://\S*api/model/xlsx\S*')
if (-not $match.Success) {
    if (-not $text) { $text = "no model is available for '$ticker'." }
    throw "No download link returned. FinHQ says: $text"
}
$url = $match.Value
try { Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing }
catch {
    $code = $null
    try { $code = [int]$_.Exception.Response.StatusCode } catch {}
    if ($code -eq 404) {
        throw "The model file wasn't found (HTTP 404) -- '$ticker' may not have an available model yet."
    } elseif ($code -eq 403 -or $code -eq 410) {
        throw "The download link expired (HTTP $code) -- links last ~30 min. Just run again."
    } else {
        $extra = if ($code) { " (HTTP $code)" } else { '' }
        throw "Download failed$extra. $($_.Exception.Message)"
    }
}
Write-Host ''
Write-Host "Saved: $outPath"
