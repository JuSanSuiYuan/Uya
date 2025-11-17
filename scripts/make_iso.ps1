param(
  [string]$OutDir = "dist",
  [string]$IsoRoot = "dist/iso_root",
  [string]$Kernel = "zig-out/bin/uya-kernel",
  [string]$LimineDir = "third_party/limine",
  [string]$IsoName = "uya.iso"
)
$ErrorActionPreference = "Stop"
if (!(Test-Path $LimineDir)) { throw "Limine directory not found: $LimineDir" }
if (!(Test-Path "$LimineDir/limine.sys") -and !(Test-Path "$LimineDir/limine-bios.sys")) { throw "Missing Limine runtime: $LimineDir/limine.sys (or limine-bios.sys)" }
if (!(Test-Path "$LimineDir/limine-cd.bin")) { throw "Missing Limine boot image: $LimineDir/limine-cd.bin" }
if (!(Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
if (Test-Path $IsoRoot) { Remove-Item -Recurse -Force $IsoRoot }
New-Item -ItemType Directory -Path $IsoRoot | Out-Null
Copy-Item $Kernel "$IsoRoot/uya-kernel"
if (Test-Path "$LimineDir/limine.sys") { Copy-Item "$LimineDir/limine.sys" "$IsoRoot/limine.sys" } else { Copy-Item "$LimineDir/limine-bios.sys" "$IsoRoot/limine.sys" }
Copy-Item "$LimineDir/limine-cd.bin" "$IsoRoot/limine-cd.bin"
Copy-Item "limine/limine.cfg" "$IsoRoot/limine.cfg"
if (Test-Path "fonts") { Copy-Item "fonts" "$IsoRoot/fonts" -Recurse }
$x = Get-Command xorriso -ErrorAction SilentlyContinue
$g = Get-Command genisoimage -ErrorAction SilentlyContinue
$m = Get-Command mkisofs -ErrorAction SilentlyContinue
if ($x) {
  & xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -input-charset utf-8 -output-charset utf-8 -o "$OutDir/$IsoName" "$IsoRoot"
} elseif ($g) {
  & genisoimage -R -J -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table -o "$OutDir/$IsoName" "$IsoRoot"
} elseif ($m) {
  & mkisofs -R -J -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table -o "$OutDir/$IsoName" "$IsoRoot"
} else {
  $wsl = Get-Command wsl -ErrorAction SilentlyContinue
  if (-not $wsl) { throw "No ISO tools found. Install xorriso (recommended), or genisoimage/mkisofs, or WSL (wsl --install)." }
  function Convert-ToWslPath([string]$p) {
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
    $drive = $full.Substring(0,1).ToLower()
    $rest = $full.Substring(2).Replace('\\','/')
    return "/mnt/$drive$rest"
  }
  $wIsoRoot = Convert-ToWslPath $IsoRoot
  $wOutFile = Convert-ToWslPath (Join-Path $OutDir $IsoName)
  wsl xorriso -as mkisofs -b limine-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -input-charset utf-8 -output-charset utf-8 -o $wOutFile $wIsoRoot
}
