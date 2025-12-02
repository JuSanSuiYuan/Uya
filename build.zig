const std = @import("std");
const iso_builder = @import("src/tools/iso_builder.zig");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    const root_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/main.zig"), .target = target, .optimize = optimize });
    const mm_core_mod = b.createModule(.{ .root_source_file = b.path("kernel/mm/core.zig"), .target = target, .optimize = optimize });
    const mm_phys_mod = b.createModule(.{ .root_source_file = b.path("kernel/mm/phys.zig"), .target = target, .optimize = optimize });
    const fs_vfs_mod = b.createModule(.{ .root_source_file = b.path("kernel/fs/vfs.zig"), .target = target, .optimize = optimize });
    const fs_fat32_mod = b.createModule(.{ .root_source_file = b.path("kernel/fs/fat32.zig"), .target = target, .optimize = optimize });
    const fs_iso_stub_mod = b.createModule(.{ .root_source_file = b.path("kernel/fs/iso9660_stub.zig"), .target = target, .optimize = optimize });
    const gfx_fb_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gfx/framebuffer.zig"), .target = target, .optimize = optimize });
    const gfx_comp_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gfx/compositor.zig"), .target = target, .optimize = optimize });
    const zigabi_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/zigabi/module.zig"), .target = target, .optimize = optimize });
    const plugin_zigmod_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/zigmod.zig"), .target = target, .optimize = optimize });
    const gc_api_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/api.zig"), .target = target, .optimize = optimize });
    const gc_bar_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/barriers.zig"), .target = target, .optimize = optimize });
    const gc_owned_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/owned.zig"), .target = target, .optimize = optimize });
    const gc_mark_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/mark.zig"), .target = target, .optimize = optimize });
    const gc_card_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/card.zig"), .target = target, .optimize = optimize });
    const gc_hazard_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/hazard.zig"), .target = target, .optimize = optimize });
    const gc_tagptr_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/tagptr.zig"), .target = target, .optimize = optimize });
    const gc_sched_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/sched.zig"), .target = target, .optimize = optimize });
    const ds_list_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/ds/intrusive_list.zig"), .target = target, .optimize = optimize });
    const gc_policy_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/gc/policy.zig"), .target = target, .optimize = optimize });
    const ai_doubao_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/ai/doubao.zig"), .target = target, .optimize = optimize });
    const plugin_doubao_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/doubao.zig"), .target = target, .optimize = optimize });
    const plugin_gc_policy_ai_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/gc_policy_ai.zig"), .target = target, .optimize = optimize });
    const plugin_gc_policy_qwen_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/gc_policy_qwen.zig"), .target = target, .optimize = optimize });
    const plugin_gc_policy_hunyuan_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/gc_policy_hunyuan.zig"), .target = target, .optimize = optimize });
    const driver_center_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/driver/center.zig"), .target = target, .optimize = optimize });
    const plugin_driver_doubao_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/driver_doubao.zig"), .target = target, .optimize = optimize });
    const plugin_driver_qwen_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/driver_qwen.zig"), .target = target, .optimize = optimize });
    const plugin_driver_hunyuan_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/plugin/driver_hunyuan.zig"), .target = target, .optimize = optimize });
    const util_ring_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/util/ringbuf.zig"), .target = target, .optimize = optimize });
    const util_seqlock_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/util/seqlock.zig"), .target = target, .optimize = optimize });
    const util_mpmc_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/util/mpmc.zig"), .target = target, .optimize = optimize });
    const util_radix_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/util/radix/tree.zig"), .target = target, .optimize = optimize });
    const io_blk_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/io/blk.zig"), .target = target, .optimize = optimize });
    const uyalink_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/net/uyalink.zig"), .target = target, .optimize = optimize });
    const drv_ramdisk_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/drivers/ramdisk.zig"), .target = target, .optimize = optimize });
    const drv_graphics_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/drivers/graphics.zig"), .target = target, .optimize = optimize });
    const drv_input_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/drivers/input.zig"), .target = target, .optimize = optimize });
    
    // 创建VESA汇编文件
    const vesa_asm_obj = b.addObject(.{ .name = "vesa_asm", .target = target, .optimize = optimize });
    vesa_asm_obj.addAssemblyFile(b.path("kernel/src/drivers/vesa_asm.S"));
    
    // 添加VESA显卡驱动模块
    const drv_vesa_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/drivers/vesa.zig"), .target = target, .optimize = optimize });
    
    // 添加VESA驱动测试模块
    const drv_vesa_test_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/drivers/vesa_test.zig"), .target = target, .optimize = optimize });
    drv_vesa_test_mod.addImport("drv_vesa", drv_vesa_mod);
    drv_vesa_test_mod.addImport("fs_vfs", fs_vfs_mod);
    
    const drv_manager_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/drivers/manager.zig"), .target = target, .optimize = optimize });
    const evt_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/event/events.zig"), .target = target, .optimize = optimize });
    const cap_types_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/cap/types.zig"), .target = target, .optimize = optimize });
    const cap_api_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/cap/cap_api.zig"), .target = target, .optimize = optimize });
    const cap_epoch_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/cap/epoch.zig"), .target = target, .optimize = optimize });
    cap_api_mod.addImport("cap_types", cap_types_mod);
    _ = b.createModule(.{ .root_source_file = b.path("kernel/src/cap/epoch.zig"), .target = target, .optimize = optimize });
    const win_pe_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/pe.zig"), .target = target, .optimize = optimize });
    const win_handle_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/handle.zig"), .target = target, .optimize = optimize });
    const win_process_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/process.zig"), .target = target, .optimize = optimize });
    const win_thread_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/thread.zig"), .target = target, .optimize = optimize });
    const win_api_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/api.zig"), .target = target, .optimize = optimize });
    const win_object_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/object.zig"), .target = target, .optimize = optimize });
    const evt_shmq_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/event/shmq.zig"), .target = target, .optimize = optimize });
    const win_context_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/context.zig"), .target = target, .optimize = optimize });
    const win_syscall_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/win/syscall.zig"), .target = target, .optimize = optimize });
    const compat_atomic_mod = b.createModule(.{ .root_source_file = b.path("compat/atomic.zig"), .target = target, .optimize = optimize });
    const abi_persona_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/abi/persona.zig"), .target = target, .optimize = optimize });
    const abi_linux_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/abi/linux.zig"), .target = target, .optimize = optimize });
    const abi_bsd_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/abi/bsd.zig"), .target = target, .optimize = optimize });
    const libos_linux_elf_mod = b.createModule(.{ .root_source_file = b.path("kernel/src/libos/linux/elf.zig"), .target = target, .optimize = optimize });
    fs_iso_stub_mod.addImport("fs_vfs", fs_vfs_mod);
    fs_vfs_mod.addImport("cap_types", cap_types_mod);
    fs_vfs_mod.addImport("cap_api", cap_api_mod);
    fs_vfs_mod.addImport("cap_epoch", cap_epoch_mod);
    fs_vfs_mod.addImport("util_radix_tree", util_radix_mod);
    fs_fat32_mod.addImport("io_blk", io_blk_mod);
    fs_fat32_mod.addImport("fs_vfs", fs_vfs_mod);
    root_mod.addImport("fs_fat32", fs_fat32_mod);
    evt_mod.addImport("util_ring", util_ring_mod);
    evt_mod.addImport("event_shmq", evt_shmq_mod);
    evt_mod.addImport("util_mpmc", util_mpmc_mod);
    evt_mod.addImport("cap_types", cap_types_mod);
    evt_mod.addImport("cap_api", cap_api_mod);
    evt_mod.addImport("cap_epoch", cap_epoch_mod);
    uyalink_mod.addImport("events", evt_mod);
    uyalink_mod.addImport("fs_vfs", fs_vfs_mod);
    util_mpmc_mod.addImport("cap_epoch", cap_epoch_mod);
    mm_core_mod.addImport("util_radix_tree", util_radix_mod);
    root_mod.addImport("util_radix_tree", util_radix_mod);
    root_mod.addImport("io_blk", io_blk_mod);
    root_mod.addImport("drv_ramdisk", drv_ramdisk_mod);
    root_mod.addImport("drv_graphics", drv_graphics_mod);
    root_mod.addImport("drv_input", drv_input_mod);
    root_mod.addImport("drv_manager", drv_manager_mod);
    root_mod.addImport("drv_vesa", drv_vesa_mod);
    drv_ramdisk_mod.addImport("io_blk", io_blk_mod);
    drv_graphics_mod.addImport("fs_vfs", fs_vfs_mod);
    drv_input_mod.addImport("fs_vfs", fs_vfs_mod);
    drv_vesa_mod.addImport("fs_vfs", fs_vfs_mod);
    drv_manager_mod.addImport("drivers_graphics", drv_graphics_mod);
    drv_manager_mod.addImport("drv_vesa", drv_vesa_mod);
    drv_manager_mod.addImport("drivers_input", drv_input_mod);
    drv_manager_mod.addImport("fs_vfs", fs_vfs_mod);
    root_mod.addImport("cap_epoch", cap_epoch_mod);
    root_mod.addImport("mm_core", mm_core_mod);
    root_mod.addImport("mm_phys", mm_phys_mod);
    root_mod.addImport("fs_vfs", fs_vfs_mod);
    root_mod.addImport("fs_iso_stub", fs_iso_stub_mod);
    root_mod.addImport("util_ring", util_ring_mod);
    root_mod.addImport("events", evt_mod);
    root_mod.addImport("util_seqlock", util_seqlock_mod);
    root_mod.addImport("gfx_fb", gfx_fb_mod);
    root_mod.addImport("gfx_comp", gfx_comp_mod);
    root_mod.addImport("zigabi", zigabi_mod);
    root_mod.addImport("plugin_zigmod", plugin_zigmod_mod);
    root_mod.addImport("gc_api", gc_api_mod);
    root_mod.addImport("gc_bar", gc_bar_mod);
    root_mod.addImport("gc_owned", gc_owned_mod);
    root_mod.addImport("gc_mark", gc_mark_mod);
    root_mod.addImport("gc_card", gc_card_mod);
    root_mod.addImport("gc_hazard", gc_hazard_mod);
    root_mod.addImport("gc_tagptr", gc_tagptr_mod);
    root_mod.addImport("gc_sched", gc_sched_mod);
    root_mod.addImport("ds_list", ds_list_mod);
    root_mod.addImport("gc_policy", gc_policy_mod);
    root_mod.addImport("ai_doubao", ai_doubao_mod);
    root_mod.addImport("plugin_doubao", plugin_doubao_mod);
    root_mod.addImport("plugin_gc_policy_ai", plugin_gc_policy_ai_mod);
    root_mod.addImport("plugin_gc_policy_qwen", plugin_gc_policy_qwen_mod);
    root_mod.addImport("plugin_gc_policy_hunyuan", plugin_gc_policy_hunyuan_mod);
    root_mod.addImport("driver_center", driver_center_mod);
    root_mod.addImport("plugin_driver_doubao", plugin_driver_doubao_mod);
    root_mod.addImport("plugin_driver_qwen", plugin_driver_qwen_mod);
    root_mod.addImport("plugin_driver_hunyuan", plugin_driver_hunyuan_mod);
    root_mod.addImport("win_pe", win_pe_mod);
    root_mod.addImport("win_handle", win_handle_mod);
    root_mod.addImport("win_process", win_process_mod);
    root_mod.addImport("win_thread", win_thread_mod);
    root_mod.addImport("win_api", win_api_mod);
    root_mod.addImport("win_object", win_object_mod);
    root_mod.addImport("event_shmq", evt_shmq_mod);
    root_mod.addImport("uyalink", uyalink_mod);
    root_mod.addImport("compat_atomic", compat_atomic_mod);
    root_mod.addImport("win_context", win_context_mod);
    root_mod.addImport("win_syscall", win_syscall_mod);
    root_mod.addImport("abi_persona", abi_persona_mod);
    root_mod.addImport("abi_linux", abi_linux_mod);
    root_mod.addImport("abi_bsd", abi_bsd_mod);
    win_process_mod.addImport("fs_vfs", fs_vfs_mod);
    win_process_mod.addImport("win_pe", win_pe_mod);
    win_process_mod.addImport("win_handle", win_handle_mod);
    win_process_mod.addImport("abi_persona", abi_persona_mod);
    util_ring_mod.addImport("compat_atomic", compat_atomic_mod);
    util_seqlock_mod.addImport("compat_atomic", compat_atomic_mod);
    evt_shmq_mod.addImport("compat_atomic", compat_atomic_mod);
    util_mpmc_mod.addImport("compat_atomic", compat_atomic_mod);
    win_api_mod.addImport("fs_vfs", fs_vfs_mod);
    win_api_mod.addImport("win_handle", win_handle_mod);
    win_api_mod.addImport("win_object", win_object_mod);
    win_thread_mod.addImport("win_handle", win_handle_mod);
    win_syscall_mod.addImport("win_api", win_api_mod);
    win_syscall_mod.addImport("win_handle", win_handle_mod);
    abi_persona_mod.addImport("win_syscall", win_syscall_mod);
    abi_persona_mod.addImport("abi_linux", abi_linux_mod);
    abi_persona_mod.addImport("abi_bsd", abi_bsd_mod);
    abi_linux_mod.addImport("fs_vfs", fs_vfs_mod);
    abi_linux_mod.addImport("events", evt_mod);
    abi_bsd_mod.addImport("fs_vfs", fs_vfs_mod);
    abi_bsd_mod.addImport("events", evt_mod);
    abi_linux_mod.addImport("libos_elf", libos_linux_elf_mod);
    win_object_mod.addImport("win_handle", win_handle_mod);
    win_object_mod.addImport("compat_atomic", compat_atomic_mod);
    win_pe_mod.addImport("mm_core", mm_core_mod);
    win_pe_mod.addImport("win_api", win_api_mod);
    win_pe_mod.addImport("win_handle", win_handle_mod);
    const exe = b.addExecutable(.{ .name = "uya-kernel", .root_module = root_mod });
    root_mod.link_libc = false;
    exe.entry = .{ .symbol_name = "_start" };
    exe.linker_script = b.path("linker.ld");
    b.installArtifact(exe);
    const host_target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows });
    // UyaDE桌面环境模块
    const window_render_mod = b.createModule(.{ .root_source_file = b.path("apps/uyade/components/window_render.zig"), .target = host_target, .optimize = optimize });
    const desktop_manager_mod = b.createModule(.{ .root_source_file = b.path("apps/uyade/desktop/manager.zig"), .target = host_target, .optimize = optimize });
    const uyade_mod = b.createModule(.{ .root_source_file = b.path("apps/uyade/main.zig"), .target = host_target, .optimize = optimize });
    
    // 添加模块依赖
    desktop_manager_mod.addImport("window_render", window_render_mod);
    uyade_mod.addImport("desktop_manager", desktop_manager_mod);
    uyade_mod.addImport("window_render", window_render_mod);
    const uyade = b.addExecutable(.{ .name = "uyade", .root_module = uyade_mod });
    b.installArtifact(uyade);
    const reg_mod = b.createModule(.{ .root_source_file = b.path("apps/registry/cli.zig"), .target = host_target, .optimize = optimize });
    const worktree_path = "apps/registry/worktree_win.zig";
    const reg_worktree_mod = b.createModule(.{ .root_source_file = b.path(worktree_path), .target = host_target, .optimize = optimize });
    reg_mod.addImport("worktree_mod", reg_worktree_mod);
    const reg_cli = b.addExecutable(.{ .name = "uya-registry", .root_module = reg_mod });
    b.installArtifact(reg_cli);
    const reg_srv_mod = b.createModule(.{ .root_source_file = b.path("apps/registry/server.zig"), .target = host_target, .optimize = optimize });
    const reg_srv = b.addExecutable(.{ .name = "uya-registry-server", .root_module = reg_srv_mod });
    b.installArtifact(reg_srv);
    const apt_mod = b.createModule(.{ .root_source_file = b.path("apps/pkg/cli.zig"), .target = host_target, .optimize = optimize });
    apt_mod.addImport("worktree_mod", reg_worktree_mod);
    const apt_cli = b.addExecutable(.{ .name = "apt", .root_module = apt_mod });
    b.installArtifact(apt_cli);
    const browser_mod = b.createModule(.{ .root_source_file = b.path("apps/browser/main.zig"), .target = host_target, .optimize = optimize });
    browser_mod.addImport("worktree_mod", reg_worktree_mod);
    const browser = b.addExecutable(.{ .name = "uyabrowser", .root_module = browser_mod });
    b.installArtifact(browser);
    
    // 创建dist目录结构
    const dist_dir = b.fmt("{s}/dist", .{b.build_root});
    const iso_root_dir = b.fmt("{s}/dist/iso_root", .{b.build_root});
    
    // 确保dist目录存在
    const create_dirs = b.addSystemCommand(&[_][]const u8{ 
        "mkdir", "-p", iso_root_dir 
    });
    create_dirs.step.make() catch |err| {
        b.step(.{ .id = .custom, .name = "mkdir-warn" }).emit(.warn, "警告：创建目录失败：{}", .{err});
    };
    
    // 测试支持
    // 驱动测试模块
    const drivers_test_mod = b.createModule(.{ .root_source_file = b.path("src/test/drivers_test.zig"), .target = host_target, .optimize = optimize });
    drivers_test_mod.addImport("../../kernel/src/drivers/graphics.zig", drv_graphics_mod);
    drivers_test_mod.addImport("../../kernel/src/drivers/input.zig", drv_input_mod);
    drivers_test_mod.addImport("../../kernel/src/drivers/manager.zig", drv_manager_mod);
    
    // 桌面环境测试模块
    const desktop_test_mod = b.createModule(.{ .root_source_file = b.path("src/test/desktop_test.zig"), .target = host_target, .optimize = optimize });
    
    // 集成测试模块
    const integration_test_mod = b.createModule(.{ .root_source_file = b.path("src/test/integration_test.zig"), .target = host_target, .optimize = optimize });
    
    // 驱动测试可执行文件
    const drivers_test_exe = b.addExecutable(.{ .name = "uya-drivers-test", .root_module = drivers_test_mod });
    drivers_test_exe.linkLibC();
    b.installArtifact(drivers_test_exe);
    
    // VESA驱动测试可执行文件
    const vesa_test_exe = b.addExecutable(.{ .name = "uya-vesa-test", .root_module = drv_vesa_test_mod });
    vesa_test_exe.addObject(vesa_asm_obj);
    vesa_test_exe.linkLibC();
    b.installArtifact(vesa_test_exe);
    
    // 桌面测试可执行文件
    const desktop_test_exe = b.addExecutable(.{ .name = "uya-desktop-test", .root_module = desktop_test_mod });
    desktop_test_exe.linkLibC();
    b.installArtifact(desktop_test_exe);
    
    // 集成测试可执行文件
    const integration_test_exe = b.addExecutable(.{ .name = "uya-integration-test", .root_module = integration_test_mod });
    integration_test_exe.linkLibC();
    b.installArtifact(integration_test_exe);
    
    // 添加测试步骤
    const drivers_test_step = b.step("test-drivers", "Run Uya drivers tests");
    const run_drivers_test = b.addRunArtifact(drivers_test_exe);
    drivers_test_step.dependOn(&run_drivers_test.step);
    
    // VESA驱动测试步骤
    const vesa_test_step = b.step("test-vesa", "Run Uya VESA driver tests");
    const run_vesa_test = b.addRunArtifact(vesa_test_exe);
    vesa_test_step.dependOn(&run_vesa_test.step);
    
    const desktop_test_step = b.step("test-desktop", "Run Uya desktop tests");
    const run_desktop_test = b.addRunArtifact(desktop_test_exe);
    desktop_test_step.dependOn(&run_desktop_test.step);
    
    // 集成测试步骤
    const integration_test_step = b.step("test-integration", "Run Uya integration tests");
    const run_integration_test = b.addRunArtifact(integration_test_exe);
    integration_test_step.dependOn(&run_integration_test.step);
    
    // 综合测试步骤
    const test_step = b.step("test", "Run all Uya tests");
    test_step.dependOn(drivers_test_step);
    test_step.dependOn(desktop_test_step);
    test_step.dependOn(integration_test_step);
    test_step.dependOn(vesa_test_step);
    
    // 添加ISO构建步骤
    const limine_dir = "limine"; // Uya的Limine目录位置
    const iso_step = iso_builder.addIsoBuildStep(b, exe, limine_dir, dist_dir);
    iso_step.dependOn(&create_dirs.step);
    
    // 使ISO构建成为默认构建的一部分
    const default_step = b.step("default", "默认构建");
    default_step.dependOn(iso_step);
    // 确保测试也被构建
    default_step.dependOn(&drivers_test_exe.step);
    default_step.dependOn(&desktop_test_exe.step);
    default_step.dependOn(&integration_test_exe.step);
    default_step.dependOn(&vesa_test_exe.step);
}
