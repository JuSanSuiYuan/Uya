$ErrorActionPreference = "Stop"
param([string]$Prompt = "hello")
$body = @{ prompt = $Prompt } | ConvertTo-Json
$resp = Invoke-WebRequest -Uri http://127.0.0.1:7800/v1/infer -Method POST -Body $body -ContentType "application/json"
Write-Output $resp.Content