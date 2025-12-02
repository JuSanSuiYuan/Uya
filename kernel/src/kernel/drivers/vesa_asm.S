.section .text
.global vesaGetVbeInfo
.global vesaSetVideoMode
.global vesaGetModeInfo

// 获取VBE信息
// 参数: info_block_ptr - VbeInfoBlock结构体指针
// 返回: 0x4F表示成功
vesaGetVbeInfo:
    push %bp
    mov %sp, %bp
    mov 4(%bp), %es       // ES:DI指向info_block_ptr
    mov 6(%bp), %di
    
    mov $0x4F00, %ax       // VESA功能号00h:获取VBE信息
    int $0x10              // 调用BIOS中断10h
    
    mov %ax, %dx           // 保存返回值到DX
    
    pop %bp
    ret

// 设置视频模式
// 参数: mode - 要设置的视频模式
// 返回: 0x4F表示成功
vesaSetVideoMode:
    push %bp
    mov %sp, %bp
    mov 4(%bp), %bx        // BX包含模式号
    
    mov $0x4F02, %ax       // VESA功能号02h:设置视频模式
    int $0x10              // 调用BIOS中断10h
    
    mov %ax, %dx           // 保存返回值到DX
    
    pop %bp
    ret

// 获取模式信息
// 参数: mode - 模式号
//       info_ptr - VesaModeInfo结构体指针
// 返回: 0x4F表示成功
vesaGetModeInfo:
    push %bp
    mov %sp, %bp
    mov 4(%bp), %cx        // CX包含模式号
    mov 6(%bp), %es        // ES:DI指向info_ptr
    mov 8(%bp), %di
    
    mov $0x4F01, %ax       // VESA功能号01h:获取模式信息
    int $0x10              // 调用BIOS中断10h
    
    mov %ax, %dx           // 保存返回值到DX
    
    pop %bp
    ret
