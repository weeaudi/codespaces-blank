[bits 16]

global detect_memory
global memory_map
global memory_size

%define ENDL 0x0A, 0x0D

section .text

    detect_memory:

        push di
        push si
        push ebx
        push eax
        push ecx
        push edx

        mov di, memory_map

        xor ebx, ebx

        mov edx, 0x534D4150

    .loop:

        clc

        mov eax, 0xE820

        mov ecx, 24

        int 15h

        cmp eax, 0x534D4150

        jne .fail
        jc .done

        cmp ebx, 0

        je .done

        add di, 24

        mov si, [memory_size]
        add si, 24
        mov [memory_size], si

        cmp cl, 24
        je .acpi3

        jmp .loop

    .acpi3:
        mov byte [es:di - 4], 1 << 7
        jmp .loop

    .done:

        pop edx
        pop ecx
        pop eax
        pop ebx
        pop si
        pop di

        ret

    .fail:

        mov si, memory_fail_msg
        call puts

        cli
        hlt


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

        pop ax
        pop si

        ret

section .rodata

    memory_fail_msg: db "ERROR: memory detection has failed!", ENDL, 0

section .bss

    memory_map: resb 512
    memory_size: db 0