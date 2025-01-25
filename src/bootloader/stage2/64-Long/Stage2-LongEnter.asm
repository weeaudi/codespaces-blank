[bits 32]

global to_64_prot

extern _init

section .text

    to_64_prot:
        [bits 32]
        call clr_scrn

        mov si, to_long_msg
        call puts

        call check_cpuid
        call check_long_mode

        call setup_page_tables
        call enable_paging_and_longmode

        call LoadGDT

        jmp 0x8:.long_mode_start

    .long_mode_start:
        [bits 64]

        mov ax, 10h
        mov ds, ax
        mov ss, ax

        call _init + 2 ; c++ global constructors

        cli
        hlt

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
        call puts
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
        call puts
        jmp .halt

    .no_long_mode:
        mov si, no_long_mode_msg
        call puts
        jmp .halt

    .halt:
        cli
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

    LoadGDT:
        [bits 32]
        lgdt [g_GDTDesc]
        ret

    ;;
    ; @brief prints a string using MMIO
    ; @param[in] si address of string
    ;;
    puts:
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

    clr_scrn:
        [bits 32]
        push eax
        push ebx
        push ecx

        mov ebx, 0xB8000
        mov al, " "
        mov cx, 0

    .loop:

        cmp cx, 2000
        je .done

        inc cx

        mov [ebx], al

        add ebx, 2

        jmp .loop

    .done:

        pop ecx
        pop ebx
        pop eax

        ret



section .data

    screen_pointer: dd 0xB8000

    g_GDT:

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

    g_GDTDesc:
        dw g_GDTDesc - g_GDT - 1    ; limit (size of GDT)
        dd g_GDT                        ; base of gdt

section .rodata

    no_cpuid_error_msg: db 'ERROR CPUID NOT SUPPORTED!!!!', 0
    no_ext_pro_info_msg: db 'ERROR CPUID DOES NOT SUPPORT EXTENDED PROCESSOR INFO!!!!', 0
    no_long_mode_msg: db 'ERROR CPU DOES NOT SUPPORT LONG MODE (64bit)!!!!', 0
    to_long_msg: db "Switching to 64 bit long mode!!", 0

section .bss

    align 4096
    page_table_l4:
        resb 4096
    page_table_l3:
        resb 4096
    page_table_l2:
        resb 4096
  