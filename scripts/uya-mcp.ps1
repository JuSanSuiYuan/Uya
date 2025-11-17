$ErrorActionPreference = "Stop"
$resp = Invoke-WebRequest -Uri http://127.0.0.1:7801/v1/tools -Method GET
Write-Output $resp.Content