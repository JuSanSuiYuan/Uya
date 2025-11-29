$root = "registry"
$prefix = "org/uya/uyade"
$version = "demo"
New-Item -ItemType Directory -Force -Path "$root/worktrees/$prefix/$version" | Out-Null
Set-Content "$root/worktrees/$prefix/current" $version
$ui = @'
theme { accent = "sky" }
taskbar { orientation = "bottom" }
titlebar { layout = "apple" }
titlebar { controls.left = ["close","min","max"] }
titlebar { controls.right = ["max","min","close"] }
titlebar { size = "24" }
titlebar { spacing = "8" }
clock { show_seconds = true }
tray { icons = ["default", "net", "sound"] }
layout { children = ["taskbar", "start", "tray", "clock"] }
'@
Set-Content "$root/worktrees/$prefix/$version/ui.dsl" $ui
Set-Content "$root/metrics_gfx.txt" "rows bytes"
Set-Content "$root/metrics_gc.txt" "dirty retries"
Set-Content "$root/metrics_drv.txt" "install verify rollback"
