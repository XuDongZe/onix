[org 0x7c00]

; 设置屏幕模式为文本模式，清除屏幕
mov ax, 3
int 0x10

; 初始化段寄存器
mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00

; 打印Booting文本
mov si, booting
call print

xchg bx, bx; bochs 魔数断点

; 读取硬盘第一扇区内容到内存
mov edi, 0x1000; 读取的目标内存
mov ecx, 0; 起始扇区
mov bl, 1; 读取的扇区数量

call read_disk

xchg bx, bx; bochs 魔数断点

mov edi, 0x1000; 写的目标内存
mov ecx, 1; 写到第二个扇区
mov bl, 1;

call write_disk

xchg bx, bx; bochs 魔数断点

; 阻塞
jmp $

read_disk:

    ; 设置读写扇区的数量
    mov dx, 0x1f2; 端口
    mov al, bl; 扇区数量
    out dx, al

    inc dx; 0x1f3
    mov al, cl; 起始扇区的前8位
    out dx, al

    inc dx; 0x1f4
    shr ecx, 8
    mov al, cl; 起始扇区的中8位
    out dx, al

    inc dx; 0x1f5
    shr ecx, 8
    mov al, cl; 起始扇区的高8位
    out dx, al

    inc dx; 0x1f6
    shr ecx, 8
    and cl, 0b1111; 将高4位置为0 保留低4位

    mov al, 0b1110_0000
    or al, cl
    out dx, al; 主盘 - LBA模式

    inc dx; 0x1f7
    mov al, 0x20; 读硬盘
    out dx, al

    xor ecx, ecx; 将ecx清空
    mov cl, bl; 得到读写扇区的数量

    .read:
        push cx; 保存 cx
        call .waits; 等待数据准备完毕
        call .reads; 读取一个扇区
        pop cx; 恢复 cx
        loop .read

    ret

    .waits:
        mov dx, 0x1f7
        .check:
            in al, dx
            jmp $+2; nop 直接跳转到下一行
            jmp $+2; 一点点延迟
            jmp $+2;
            and al, 0b1000_1000
            cmp al, 0b0000_1000
            jnz .check
        ret
    
    .reads:
        mov dx, 0x1f0
        mov cx, 256; 一个扇区256字
        .readw:
            in ax, dx
            jmp $+2; 一点点延迟
            jmp $+2
            jmp $+2
            mov [edi], ax
            add edi, 2; 一个字2个字节
            loop .readw
        ret

write_disk:

    ; 设置读写扇区的数量
    mov dx, 0x1f2; 端口
    mov al, bl; 扇区数量
    out dx, al

    inc dx; 0x1f3
    mov al, cl; 起始扇区的前8位
    out dx, al

    inc dx; 0x1f4
    shr ecx, 8
    mov al, cl; 起始扇区的中8位
    out dx, al

    inc dx; 0x1f5
    shr ecx, 8
    mov al, cl; 起始扇区的高8位
    out dx, al

    inc dx; 0x1f6
    shr ecx, 8
    and cl, 0b1111; 将高4位置为0 保留低4位

    mov al, 0b1110_0000
    or al, cl
    out dx, al; 主盘 - LBA模式

    inc dx; 0x1f7
    mov al, 0x30; 写硬盘
    out dx, al

    xor ecx, ecx; 将ecx清空
    mov cl, bl; 得到读写扇区的数量

    .write:
        push cx; 保存 cx
        call .writes; 写一个扇区
        call .waits; 等待硬盘繁忙结束
        pop cx; 恢复 cx
        loop .write

    ret

    .waits:
        mov dx, 0x1f7
        .check:
            in al, dx
            jmp $+2; nop 直接跳转到下一行
            jmp $+2; 一点点延迟
            jmp $+2;
            and al, 0b1000_0000
            cmp al, 0b0000_0000
            jnz .check
        ret
    
    .writes:
        mov dx, 0x1f0
        mov cx, 256; 一个扇区256字
        .writew:
            mov ax, [edi]
            out dx, ax
            jmp $+2; 一点点延迟
            jmp $+2
            jmp $+2
            mov [edi], ax
            add edi, 2; 一个字2个字节
            loop .writew
        ret


print:
    mov ah, 0x0e
    .next
        mov al, [si]
        cmp al, 0
        jz .done
        int 0x10
        inc si
        jmp .next
    .done
    ret

booting:
    db "Booting Onix...", 10, 13, 0 ; \n\r

times 510-($-$$) db 0
db 0x55, 0xaa