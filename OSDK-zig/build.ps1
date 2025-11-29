param(
  [string]$Mode = "release"
)

powershell -ExecutionPolicy Bypass -File scripts\make_iso.ps1

