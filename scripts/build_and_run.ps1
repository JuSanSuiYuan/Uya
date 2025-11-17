$ErrorActionPreference = "Stop"
& zig build
& scripts/make_iso.ps1
& scripts/qemu.ps1
