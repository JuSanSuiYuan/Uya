const std = @import("std");
const tb = @import("titlebar_layout.zig");
const calc = @import("titlebar_calc.zig");
const colors = @import("colors.zig");

pub fn render_with_size(width: usize, height: usize) void {
    const o = std.io.getStdOut().writer();
    const left = tb.get_left();
    const right = tb.get_right();
    
    // 显示当前布局类型和Material3样式
    const layout_name = switch (tb.get()) {
        .apple => "apple",
        .windows => "windows",
        .hybrid => "hybrid"
    };
    
    // Material3风格标题
    _ = o.print("TITLEBAR - Material3 风格 ({s})\n", .{layout_name});
    _ = o.print("主题颜色: 深蓝色 (#1976D2)\n", .{});
    
    // 左侧按钮信息（显示颜色）
    _ = o.print("左侧按钮: ", .{});
    var i: usize = 0; 
    while (i < left.len) : (i += 1) { 
        const color = colors.getButtonColor(left[i]);
        _ = o.print("{s} (#{X:06}) ", .{ left[i], color }); 
    }
    _ = o.print("\n", .{});
    
    // 右侧按钮信息（显示颜色）
    _ = o.print("右侧按钮: ", .{});
    var j: usize = 0; 
    while (j < right.len) : (j += 1) { 
        const color = colors.getButtonColor(right[j]);
        _ = o.print("{s} (#{X:06}) ", .{ right[j], color }); 
    }
    _ = o.print("\n", .{});
    
    // 搜索栏信息
    const search_enabled = tb.has_search() and tb.get() == .hybrid;
    _ = o.print("搜索栏: {}, 背景色: #{X:06}\n", .{ 
        if (search_enabled) "enabled" else "disabled",
        colors.Primary.light
    });
    
    var lrects: [16]calc.Rect = undefined;
    var rrects: [16]calc.Rect = undefined;
    var search_bar: calc.SearchBar = .{.x=0, .y=0, .w=0, .h=0, .visible=false};
    
    const res = calc.compute(width, height, lrects[0..], rrects[0..], &search_bar);
    
    _ = o.print("COORDS LEFT\n", .{});
    var k: usize = 0; while (k < res.ln) : (k += 1) { const r = lrects[k]; _ = o.print("{s} @ ({d},{d}) {d}x{d}\n", .{ r.name, r.x, r.y, r.w, r.h }); }
    
    _ = o.print("COORDS RIGHT\n", .{});
    var m: usize = 0; while (m < res.rn) : (m += 1) { const rr = rrects[m]; _ = o.print("{s} @ ({d},{d}) {d}x{d}\n", .{ rr.name, rr.x, rr.y, rr.w, rr.h }); }
    
    // 显示搜索栏坐标
    if (search_bar.visible) {
        _ = o.print("SEARCH BAR @ ({d},{d}) {d}x{d}\n", .{ search_bar.x, search_bar.y, search_bar.w, search_bar.h });
    }
}

pub fn render_ascii(width: usize, height: usize) void {
    var lrects: [16]calc.Rect = undefined;
    var rrects: [16]calc.Rect = undefined;
    var search_bar: calc.SearchBar = .{.x=0, .y=0, .w=0, .h=0, .visible=false};
    
    const res = calc.compute(width, height, lrects[0..], rrects[0..], &search_bar);
    const bar_w = width;
    
    const line = std.heap.page_allocator.alloc(u8, bar_w) catch return;
    defer std.heap.page_allocator.free(line);
    
    const o = std.io.getStdOut().writer();
    
    // 打印Material3风格的ASCII表示
    _ = o.print("==========================================\n", .{});
    _ = o.print("Material3 风格 ASCII 预览 - 深蓝色主题\n", .{});
    _ = o.print("==========================================\n", .{});
    
    // 初始化行（使用'='表示深蓝色背景）
    var i: usize = 0; 
    while (i < bar_w) : (i += 1) {
        line[i] = '='; // 深蓝色背景
    }
    
    // 绘制左侧按钮（粉红色、天蓝色、淡绿色）
    var k: usize = 0;
    while (k < res.ln) : (k += 1) {
        const r = lrects[k];
        if (r.x < bar_w) line[r.x] = '('; // 按钮边界
        if (r.x + 1 < bar_w) {
            // 根据按钮类型使用不同字符表示颜色
            if (std.mem.eql(u8, r.name, "close")) line[r.x + 1] = 'X'; // 粉红色（关闭）
            else if (std.mem.eql(u8, r.name, "min")) line[r.x + 1] = '_'; // 天蓝色（最小化）
            else if (std.mem.eql(u8, r.name, "max")) line[r.x + 1] = '□'; // 淡绿色（最大化）
        }
        if (r.x + 2 < bar_w) line[r.x + 2] = ')';
    }
    
    // 绘制右侧按钮
    var m: usize = 0;
    while (m < res.rn) : (m += 1) {
        const rr = rrects[m];
        const pos = if (rr.x + 2 < bar_w) rr.x else if (bar_w > 3) bar_w - 3 else 0;
        line[pos] = '(';
        if (pos + 1 < bar_w) {
            // 根据按钮类型使用不同字符表示颜色
            if (std.mem.eql(u8, rr.name, "close")) line[pos + 1] = 'X'; // 粉红色
            else if (std.mem.eql(u8, rr.name, "min")) line[pos + 1] = '_'; // 天蓝色
            else if (std.mem.eql(u8, rr.name, "max")) line[pos + 1] = '□'; // 淡绿色
        }
        if (pos + 2 < bar_w) line[pos + 2] = ')';
    }
    
    // 绘制搜索栏（浅蓝色背景）
    if (search_bar.visible) {
        const start = search_bar.x;
        const end = if (start + search_bar.w < bar_w) start + search_bar.w else bar_w;
        
        // 填充搜索栏区域（浅蓝色）
        var s: usize = start;
        while (s < end) : (s += 1) {
            if (s < bar_w) line[s] = '#'; // '#' 表示浅蓝色背景
        }
        
        // 绘制搜索栏边界
        if (start < bar_w) line[start] = '<';
        if (end - 1 < bar_w) line[end - 1] = '>';
        
        // 在搜索栏中间绘制搜索图标
        const mid = start + (search_bar.w / 2);
        if (mid < bar_w) line[mid] = 'S'; // 搜索图标
    }
    
    // 打印图例
    _ = o.print("图例: = 深蓝色背景 | () 按钮 | # 搜索栏 (浅蓝色)\n", .{});
    _ = o.print("按钮颜色: X 粉红色(关闭) | _ 天蓝色(最小化) | □ 淡绿色(最大化)\n", .{});
    _ = o.print("------------------------------------------\n", .{});
    
    // 打印ASCII标题栏
    _ = o.print("{s}\n", .{ line });
    _ = o.print("==========================================\n", .{});
}
