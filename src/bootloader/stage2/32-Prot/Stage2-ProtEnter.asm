[bits 16]

global to_32_prot

%define ENDL 0x0A, 0x0D

KbdControllerDataPort:              equ 0x60
KbdControllerCommandPort:           equ 0x64
KbdControllerDisableKeyboard:       equ 0xAD
KbdControllerEnableKeyboard:        equ 0xAE
KbdControllerReadCtrlOutputPort:    equ 0xD0
KbdControllerWriteCtrlOutputPort:   equ 0xD1

section .text

    to_32_prot:

        call clr_scrn

        mov si, to_prot_message
        call puts

        cli             ; 1 - disable interrupts
        call EnableA20  ; 2 - enable A20 line
        call LoadGDT    ; 3 - load GDT

        ; 4 - set PE bit in CR0
        mov eax, cr0
        or al, 1
        mov cr0, eax

        ; 5 - jump to 32-bit code segment
        jmp dword 08h:.PMODE32

        cli
        hlt

    .PMODE32:
        [bits 32]
        cli
        hlt

    ;;
    ; @brief enables the A20 gate for switching to 32 bit mode
    ;;
    EnableA20:
        [bits 16]
        ; disable keyboard
        call A20WaitInput
        mov al, KbdControllerDisableKeyboard
        out KbdControllerCommandPort, al

        ; read controller output port
        call A20WaitInput
        mov al, KbdControllerReadCtrlOutputPort
        out KbdControllerCommandPort, al

        call A20WaitOutput
        in al, KbdControllerDataPort

        push eax

        ; write controller output port
        call A20WaitInput
        mov al, KbdControllerWriteCtrlOutputPort
        out KbdControllerCommandPort, al

        call A20WaitInput

        pop eax
        or al, 2            ; set A20 bit (bit 2)
        out KbdControllerDataPort, al

        ; enable keyboard
        call A20WaitInput
        mov al, KbdControllerEnableKeyboard
        out KbdControllerCommandPort, al

        call A20WaitInput
        ret


    A20WaitInput:
        [bits 16]
        ; wait until status bit 2 (input buffer) is 0
        ; by reading from command port, we read status byte
        in al, KbdControllerCommandPort
        test al, 2
        jnz A20WaitInput
        ret

    A20WaitOutput:
        [bits 16]
        ; wait until status bit 1 (output buffer) is 1 so it can be read
        in al, KbdControllerCommandPort
        test al, 1
        jz A20WaitOutput
        ret

    ;;
    ; @brief loads the global descriptor table
    ;;
    LoadGDT:
        [bits 16]
        lgdt [g_GDTDesc]
        ret

    ;;
    ; @brief prints a string using MMIO
    ; @param[in] si address of string
    ;;
    puts:
        [bits 16]
        push si
        push ax
        push ebx

    .loop:
        lodsb
        or al,al
        jz .done
        mov ebx, [screen_pointer]
        mov [ebx], al
        add ebx, 2
        mov [screen_pointer], ebx
        jmp .loop
    .done:

        pop ebx
        pop ax
        pop si

        ret

    ;;
    ; @brief clears the screen
    ;;
    clr_scrn:
        push ax
        push bx
        push cx
        push dx

        mov ah, 0x02
        mov bh, 0
        mov dx, 0

        int 0x10

        mov ah, 0x0E
        mov al, " "

        mov cx, 0

    .loop:

        cmp cx, 2000
        je .done
        inc cx

        int 0x10

        jmp .loop

    .done:

        mov ah, 0x02
        mov bh, 0
        mov dx, 0

        int 0x10

        pop dx
        pop cx
        pop bx
        pop ax

        ret

section .data

    screen_pointer: dd 0xB8000

section .rodata

    to_prot_message: db "Switching to 32bit protected mode!", 0

    g_GDT: 
        dq 0           ; null descriptor

        ; 32-bit code segment descriptor segment 8
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10011010b    ; access byte (present, ring 0, code segment, executable, direction 0, readable)
        db 11001111b    ; granularity (4KB pages, 32-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

        ; 32-bit data segment descriptor segment 16
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10010010b    ; access byte (present, ring 0, data segment, executable, direction 0, writable)
        db 11001111b    ; granularity (4KB pages, 32-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

        ; 16-bit code segment descriptor segment 24
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10011011b    ; access byte (present, ring 0, code segment, executable, direction 0, readable)
        db 00001111b    ; granularity (1B pages, 16-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

        ; 16-bit data segment descriptor segment 32
        dw 0FFFFh       ; limit low (bits 0-15) = 0xFFFFFFFF for full 32-bit range
        dw 0            ; base low (bits 0-15) = 0x0
        db 0            ; base middle (bits 16-23) = 0x0
        db 10010011b    ; access byte (present, ring 0, data segment, executable, direction 0, writable)
        db 00001111b    ; granularity (1B pages, 16-bit, limit high bits 16-19)
        db 0            ; base high (bits 24-31) = 0x0

    g_GDTDesc:
        dw g_GDTDesc - g_GDT - 1     ; limit (size of GDT)
        dd g_GDT                        ; base of GDT