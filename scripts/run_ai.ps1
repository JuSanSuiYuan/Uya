$ErrorActionPreference = "Stop"
Push-Location services
try {
  & cargo run -p uya_ai_runtime &
  & cargo run -p uya_mcp_host &
} finally { Pop-Location }