param(
  [string]$Iso = "dist/uya.iso",
  [string]$Qemu = "qemu-system-x86_64"
)
$ErrorActionPreference = "Stop"
& $Qemu -m 512M -serial stdio -no-reboot -boot d -cdrom $Iso
