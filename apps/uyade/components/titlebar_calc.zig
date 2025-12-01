const tb = @import("titlebar_layout.zig");

pub const Rect = struct { 
    x: usize, 
    y: usize, 
    w: usize, 
    h: usize, 
    name: []const u8 
};

// 搜索栏结构
pub const SearchBar = struct {
    x: usize,
    y: usize,
    w: usize,
    h: usize,
    visible: bool
};

var size_px: usize = 24;
var spacing_px: usize = 8;
var search_bar_height: usize = 28; // 搜索栏高度
var search_bar_min_width: usize = 200; // 搜索栏最小宽度

pub fn set_metrics(size: usize, spacing: usize) void { 
    size_px = size; 
    spacing_px = spacing; 
}

// 设置搜索栏相关参数
pub fn set_search_bar_metrics(height: usize, min_width: usize) void {
    search_bar_height = height;
    search_bar_min_width = min_width;
}

// 计算标题栏布局，返回左侧按钮数、右侧按钮数和搜索栏信息
pub fn compute(width: usize, height: usize, out_left: []Rect, out_right: []Rect, out_search: *SearchBar) struct { ln: usize, rn: usize } {
    var x_left: usize = spacing_px;
    var x_right: usize = if (width > spacing_px) width - spacing_px else 0;
    const y: usize = spacing_px;
    var ln: usize = 0;
    var rn: usize = 0;
    
    const left = tb.get_left();
    const right = tb.get_right();
    const layout = tb.get();
    const has_search = tb.has_search() and layout == .hybrid;
    
    // 计算左侧按钮
    var i: usize = 0;
    while (i < left.len and ln < out_left.len) : (i += 1) {
        // 仅在hybrid或apple布局下显示左侧按钮
        if (layout == .hybrid or layout == .apple) {
            out_left[ln] = .{ .x = x_left, .y = y, .w = size_px, .h = size_px, .name = left[i] };
            x_left += size_px + spacing_px;
            ln += 1;
        }
    }
    
    // 计算右侧按钮
    var j: usize = 0;
    while (j < right.len and rn < out_right.len) : (j += 1) {
        // 仅在hybrid或windows布局下显示右侧按钮
        if (layout == .hybrid or layout == .windows) {
            const w = size_px;
            if (x_right >= w) x_right -= w else x_right = 0;
            out_right[rn] = .{ .x = x_right, .y = y, .w = size_px, .h = size_px, .name = right[j] };
            if (x_right >= spacing_px) x_right -= spacing_px else x_right = 0;
            rn += 1;
        }
    }
    
    // 计算搜索栏位置（仅在混合模式下显示）
    out_search.* = .{ .x = 0, .y = 0, .w = 0, .h = 0, .visible = false };
    if (has_search) {
        // 计算搜索栏宽度
        const available_width = width - x_left - (width - x_right);
        const sb_width = if (available_width > search_bar_min_width) available_width else search_bar_min_width;
        
        // 确保有足够空间显示搜索栏
        if (available_width > 0 and width > x_left + sb_width) {
            const sb_y = (height - search_bar_height) / 2; // 居中显示
            out_search.* = .{ 
                .x = x_left,
                .y = sb_y,
                .w = sb_width,
                .h = search_bar_height,
                .visible = true
            };
        }
    }
    
    return .{ .ln = ln, .rn = rn };
}
