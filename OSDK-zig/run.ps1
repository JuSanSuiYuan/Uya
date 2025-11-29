param(
  [string]$Iso = "",
  [string]$Kernel = ""
)

powershell -ExecutionPolicy Bypass -File scripts\qemu.ps1 -Iso $Iso -Kernel $Kernel

