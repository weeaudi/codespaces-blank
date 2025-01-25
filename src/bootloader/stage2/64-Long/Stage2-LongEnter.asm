[bits 32]

global to_64_prot

section .text

    to_64_prot:

        mov si, to_long_msg
        call puts

        cli
        hlt

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

section .data

    screen_pointer: dd 0xB8000

section .rodata

    to_long_msg: db "Switching to 64 bit long mode!!", 0
  