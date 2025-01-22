;;
; This is the entry to the second stage bootloader. it will switch to 64 bit mode
; @include{lineno} entry.asm
; @author Aidcraft
; @version 0.0.2
; @date 2025-01-19
; 
; @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
; @par License:
; This project is released under the Artistic License 2.0
;;

bits 16

section .entry

    %define ENDL 0x0A, 0x0D

    extern __bss_start
    extern __end
    extern _init
    extern Start

    global entry

section .text

    ;;
    ; @brief the entry to the second stage
    ;;
    entry:
        cli
        mov ax, ds 
        mov ss, ax
        mov sp, 0xFFF0
        mov bp, sp
        sti

        ; expect boot drive in dl, save it to drive_number
        mov [drive_number], dl

        mov [boot_partition_offset], di

        mov [boot_partition_segment], es


        mov si, to_prot_message
        call puts

        ; switch to 32-bit protected mode

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

        ; we are now in 32-bit protected mode

        call check_cpuid
        call check_long_mode

         ; clear bss (uninitialized data)
        mov edi, __bss_start
        mov ecx, __end
        sub ecx, edi
        mov al, 0
        cld
        rep stosb

        call setup_page_tables
        call enable_paging_and_longmode

        call LoadGDT64

        jmp 0x8:.long_mode_start

    .long_mode_start:
        [bits 64]
        ; 6 - set up data segment registers
        mov ax, 10h
        mov ds, ax
        mov ss, ax

        call _init ; c++ global constructors

        ; pass the address of the boot partition to the stage2 main function
        xor rdx, rdx
        mov dx, [boot_partition_segment]
        shl rdx, 16
        mov dx, [boot_partition_offset]
        mov rsi, rdx

        ; expect boot drive in drive_number, restore it to dl and call _cstart_
        xor rdx, rdx
        mov dl, [drive_number]
        mov rdi, rdx
        
        call Start ; call stage2 main function
        
    .halt:
        hlt
        jmp .halt

    ;;
    ; @brief checks if cpuid is supported
    ;;
    check_cpuid:
        [bits 32]
        pushfd              ; push eflags
        pop eax             ; eflags -> eax
        mov ecx, eax        ; eax(eflags) -> ecx
        xor eax, 1 << 21    ; set bit 21 in eax
        push eax            ; push eax
        popfd               ; eax -> eflags
        pushfd              ; push eflags
        pop eax             ; eflags -> eax
        push ecx            ; push ecx
        popfd               ; restore original eflags
        cmp eax, ecx        ; if equal the id bit cannot be changed so no cpuid
        je .no_cpuid
        ret
    .no_cpuid:
        mov si, no_cpuid_error_msg
        call puts_prot
        cli
        hlt
    .halt:
        hlt
        jmp .halt

    ;;
    ; @brief checks if cpu supports long mode (64 bit)
    ;;
    check_long_mode:
        [bits 32]
    .check_cpuid_ext_pro_info:
        mov eax, 0x80000000
        cpuid
        cmp eax, 0x80000001
        jb .no_ext_pro_info
    .check_long_mode_bit:
        mov eax, 0x80000001
        cpuid
        test edx, 1 << 29       ; test long mode bit
        jz .no_long_mode

        ret

    .no_ext_pro_info:
        mov si, no_ext_pro_info_msg
        call puts_prot
        jmp .halt

    .no_long_mode:
        mov si, no_long_mode_msg
        call puts_prot
        jmp .halt

    .halt:
        hlt
        jmp .halt

    ;;
    ; @brief sets up the page tables for 64 bit mode
    ; @details memory maps the first gigabyte identically
    ;;
    setup_page_tables:
        [bits 32]
        mov eax, page_table_l3
        or eax, 11b                 ; present, writable
        mov [page_table_l4], eax    ; mov l3 table into l4

        mov eax, page_table_l2
        or eax, 11b                 ; present, writable
        mov [page_table_l3], eax    ; mov l2 table into l3

        mov ecx, 0                  ; counter

.loop:

        mov eax, 0x200000           ; 2 MiB
        mul ecx                     ; address of page
        or eax, 10000011b           ; present, writable, and huge page
        mov [page_table_l2 + ecx * 8], eax

        inc ecx
        cmp ecx, 512                ; checks if we mapped all 512 entries

        jne .loop

        ret

    ;;
    ; @brief passes the page table location to the cpu
    ;;
    enable_paging_and_longmode:
        [bits 32]
        mov eax, page_table_l4
        mov cr3, eax            ; pass l4 address to cpu

        mov eax, cr4
        or eax, 1 << 5          ; enable PAE bit
        mov cr4, eax

    .enable_long_mode:
        mov ecx, 0xC0000080
        rdmsr
        or eax, 1 << 8
        wrmsr

    .enable_paging:
        mov eax, cr0
        or eax, 1 << 31
        mov cr0, eax

        ret

    drive_number: db 0
    boot_partition_offset: dw 0
    boot_partition_segment: dw 0

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
    ; @brief loads the 64 bit global descriptor table
    ;;
    LoadGDT64:
        [bits 32]
        lgdt [g_GDT64Desc]
        ret


    KbdControllerDataPort:              equ 0x60
    KbdControllerCommandPort:           equ 0x64
    KbdControllerDisableKeyboard:       equ 0xAD
    KbdControllerEnableKeyboard:        equ 0xAE
    KbdControllerReadCtrlOutputPort:    equ 0xD0
    KbdControllerWriteCtrlOutputPort:   equ 0xD1

    ScreenBuffer:                       equ 0xB8000

    ;;
    ; @brief prints a string using BIOS
    ; @param[in] si address of string
    ;;
    puts:
        [bits 16]
        ; save registers we mofify
        push si
        push ax

    .loop:
        lodsb                  ; load next byte from ds:si into al
        or al, al              ; check if al is zero
        jz .done               ; if zero, we're done
        mov ah, 0x0E           ; teletype output
        mov bh, 0x00           ; page number
        int 0x10               ; call video interrupt
        jmp .loop

    .done:
        ; restore registers
        pop ax
        pop si
        ret

    screen_pointer: dd 0xB8000

    ;;
    ; @brief prints a string using MMIO
    ; @param[in] si address of string
    ;;
    puts_prot:
        [bits 32]
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


section .rodata

    no_cpuid_error_msg: db 'ERROR CPUID NOT SUPPORTED!!!!', 0
    no_ext_pro_info_msg: db 'ERROR CPUID DOES NOT SUPPORT EXTENDED PROCESSOR INFO!!!!', 0
    no_long_mode_msg: db 'ERROR CPU DOES NOT SUPPORT LONG MODE (64bit)!!!!', 0
    to_prot_message: db 'Loading into 32-bit Prot. mode...', ENDL, 0

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

    g_GDT64:

        dq 0            ; null entry

        ; 64-bit code segment descriptor segment 8
        dw 0            ; limit low     (limit ignored in 64 bit)
        dw 0            ; base low      (base ignored in 64 bit)
        db 0            ; base middle   (base ignored in 64 bit)
        db 10011011b    ; access byte (present, ring 0, code segment, executable, direction 0, readable)
        db 00000100b    ; long bit set
        db 0            ; base high     (base ignored in 64 bit)

        ; 64-bit data segment descriptor segment 8
        dw 0            ; limit low     (limit ignored in 64 bit)
        dw 0            ; base low      (base ignored in 64 bit)
        db 0            ; base middle   (base ignored in 64 bit)
        db 10010011b    ; access byte (present, ring 0, data segment, direction 0, readable)
        db 00000100b    ; long bit set
        db 0            ; base high     (base ignored in 64 bit)

    g_GDT64Desc:
        dw g_GDT64Desc - g_GDT64 - 1    ; limit (size of GDT)
        dd g_GDT                        ; base of gdt

section .bss

    align 4096
    page_table_l4:
        resb 4096
    page_table_l3:
        resb 4096
    page_table_l2:
        resb 4096

