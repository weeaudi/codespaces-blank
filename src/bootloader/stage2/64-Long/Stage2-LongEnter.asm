bits 64

global to_64_prot

extern _init
extern Start

extern drive_number
extern boot_partition_segment
extern boot_partition_offset
extern memory_map
extern memory_size

section .text

;---------------------------------------------------------------
; Main Function: to_64_prot
;
; Description:
;   Prepares the system to switch to 64‑bit long mode by:
;     1. Clearing the screen.
;     2. Printing a message.
;     3. Checking CPUID support.
;     4. Verifying long mode support.
;     5. Setting up page tables.
;     6. Enabling paging and long mode.
;     7. Loading the GDT.
;     8. Jumping to 64‑bit long mode entry.
;
;   Once in long mode, it calls C++ global constructors (_init), sets
;   up parameters for the main function (Start), and transfers control.
;---------------------------------------------------------------
to_64_prot:
    [bits 32]
    call clr_scrn

    ; Print message: "Switching to 64 bit long mode!!"
    mov si, to_long_msg
    call puts

    ; Check for CPUID support
    call check_cpuid

    ; Verify that the CPU supports long mode (64-bit)
    call check_long_mode

    ; Set up page tables mapping the first 1 GiB using 2 MiB huge pages
    call setup_page_tables

    ; Enable paging and long mode
    call enable_paging_and_longmode

    ; Load the 64-bit Global Descriptor Table
    call LoadGDT

    ; Jump to the 64-bit code segment (selector 0x8)
    jmp 0x8:.long_mode_entry

.long_mode_entry:
    bits 64

    cli  ; Disable interrupts

    ; Call C++ global constructors (_init)
    call _init

    ; Pass the boot partition address to Start in RSI:
    ;   Combine boot_partition_segment (high 16 bits) and boot_partition_offset.
    xor rdx, rdx
    mov dx, [boot_partition_segment]
    shl rdx, 16
    mov dx, [boot_partition_offset]
    mov rsi, rdx

    ; Retrieve the boot drive from drive_number and store in RDI.
    xor rdx, rdx
    mov dl, [drive_number]
    mov rdi, rdx

    ; Pass the memory map address in RDX.
    xor rdx, rdx
    mov rdx, memory_map

    ; Pass the memory size (from memory_size) in RCX.
    xor rcx, rcx
    mov cx, [memory_size]

    ; Call the main function (Start) with the above parameters.
    call Start

    cli
    hlt

;---------------------------------------------------------------
; Function: check_cpuid
;
; Description:
;   Determines if the CPUID instruction is supported by attempting to
;   toggle the ID flag (bit 21) in EFLAGS. If the flag is unchangeable,
;   CPUID is not supported and the system halts.
;---------------------------------------------------------------
check_cpuid:
    [bits 32]
    push eax
    push ecx

    ; Save EFLAGS, try to toggle bit 21, then compare.
    pushfd              ; Push EFLAGS onto the stack.
    pop eax             ; Get EFLAGS in EAX.
    mov ecx, eax        ; Save original EFLAGS.
    xor eax, 1 << 21    ; Toggle ID flag (bit 21).
    push eax
    popfd               ; Update EFLAGS.
    pushfd              ; Get new EFLAGS.
    pop eax             ; Store new EFLAGS in EAX.
    push ecx
    popfd               ; Restore original EFLAGS.
    cmp eax, ecx        ; Compare new and original values.
    je .no_cpuid        ; If unchanged, CPUID is not supported.

    pop ecx
    pop eax
    ret

.no_cpuid:
    mov si, no_cpuid_error_msg
    call puts
    cli
    hlt
.halt:
    hlt
    jmp .halt

;---------------------------------------------------------------
; Function: check_long_mode
;
; Description:
;   Checks if the CPU supports long mode (64-bit) by querying extended
;   processor information using CPUID. If long mode is not supported,
;   an error message is printed and the system halts.
;---------------------------------------------------------------
check_long_mode:
    [bits 32]
.check_cpuid_ext_pro_info:
    push edx
    push eax

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .no_ext_pro_info
.check_long_mode_bit:
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29       ; Test long mode bit (bit 29 in EDX).
    jz .no_long_mode

    pop eax
    pop edx
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

;---------------------------------------------------------------
; Function: setup_page_tables
;
; Description:
;   Sets up the page tables for 64-bit mode. It creates entries to map
;   the first 1 GiB of memory using 2 MiB huge pages, and sets up the
;   level 4, level 3, and level 2 tables.
;---------------------------------------------------------------
setup_page_tables:
    [bits 32]
    push eax
    push ecx

    ; Set L4: mark the level 3 table as present and writable.
    mov eax, page_table_l3
    or eax, 11b                 ; Flags: present, writable.
    mov [page_table_l4], eax

    ; Set L3: mark the level 2 table as present and writable.
    mov eax, page_table_l2
    or eax, 11b                 ; Flags: present, writable.
    mov [page_table_l3], eax

    mov ecx, 0                  ; Initialize counter for L2 entries.

.loop:
    ; Calculate physical address for the 2 MiB page: 0x200000 * ECX.
    mov eax, 0x200000
    mul ecx                     ; EAX = 0x200000 * ECX.
    or eax, 10000011b           ; Set flags: present, writable, huge page.
    mov [page_table_l2 + ecx * 8], eax

    inc ecx
    cmp ecx, 512                ; Map 512 entries (512 * 2MiB = 1 GiB).
    jne .loop

    pop ecx
    pop eax
    ret

;---------------------------------------------------------------
; Function: enable_paging_and_longmode
;
; Description:
;   Passes the page table location to the CPU, enables PAE, and then
;   activates long mode and paging by modifying control registers and
;   the IA32_EFER MSR.
;---------------------------------------------------------------
enable_paging_and_longmode:
    [bits 32]
    ; Load L4 page table address into CR3.
    mov eax, page_table_l4
    mov cr3, eax

    ; Enable PAE in CR4.
    mov eax, cr4
    or eax, 1 << 5 | 1 << 7     ; Enable PAE and related flags.
    mov cr4, eax

.enable_long_mode:
    mov ecx, 0xC0000080         ; IA32_EFER MSR.
    rdmsr
    or eax, 1 << 8              ; Set the Long Mode Enable (LME) bit.
    wrmsr

.enable_paging:
    mov eax, cr0
    or eax, 1 << 31 | 1 << 0     ; Enable paging (PG) and protection (PE).
    mov cr0, eax

    ret

;---------------------------------------------------------------
; Function: LoadGDT
;
; Description:
;   Loads the 64-bit Global Descriptor Table (GDT) using the LGDT
;   instruction.
;---------------------------------------------------------------
LoadGDT:
    [bits 32]
    lgdt [g_GDT64Desc]
    ret

;---------------------------------------------------------------
; Function: puts
;
; Description:
;   Prints a null-terminated string using memory-mapped I/O. It writes
;   each character to video memory at the address given by screen_pointer.
;
; Input:
;   SI - Pointer to the null-terminated string.
;---------------------------------------------------------------
puts:
    [bits 32]
    push si
    push ax
    push ebx

.puts_loop:
    lodsb
    or al, al
    jz .puts_done
    mov ebx, [screen_pointer]
    mov [ebx], al
    add ebx, 2
    mov [screen_pointer], ebx
    jmp .puts_loop
.puts_done:
    pop ebx
    pop ax
    pop si
    ret

;---------------------------------------------------------------
; Function: clr_scrn
;
; Description:
;   Clears the screen by writing blank spaces to video memory. Assumes
;   an 80x25 text mode display (2000 characters).
;---------------------------------------------------------------
clr_scrn:
    [bits 32]
    push eax
    push ebx
    push ecx

    mov ebx, 0xB8000        ; Video memory base address.
    mov al, " "             ; Blank space character.
    mov cx, 0

.clr_loop:
    cmp cx, 2000            ; 80 * 25 = 2000 characters.
    je .clr_done
    inc cx
    mov [ebx], al
    add ebx, 2
    jmp .clr_loop

.clr_done:
    pop ecx
    pop ebx
    pop eax
    ret

section .data
    screen_pointer: dd 0xB8000

    align 16
    g_GDT64:
        dq 0            ; Null descriptor

        ; 64-bit code segment descriptor (selector 0x8)
        dw 0xFFFF       ; Limit low (ignored in 64-bit mode)
        dw 0            ; Base low (ignored in 64-bit mode)
        db 0            ; Base middle (ignored in 64-bit mode)
        db 10011010b    ; Access: present, ring 0, code, executable, readable
        db 10101111b    ; Flags: long mode enabled
        db 0            ; Base high (ignored)

        ; 64-bit data segment descriptor (selector 0x10)
        dw 0xFFFF       ; Limit low (ignored in 64-bit mode)
        dw 0            ; Base low (ignored in 64-bit mode)
        db 0            ; Base middle (ignored in 64-bit mode)
        db 10010010b    ; Access: present, ring 0, data, writable
        db 11001111b    ; Flags: long mode enabled
        db 0            ; Base high (ignored)

    g_GDT64Desc:
        dw g_GDT64Desc - g_GDT64 - 1    ; Limit: size of GDT - 1
        dd g_GDT64                      ; Base address of the GDT

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
