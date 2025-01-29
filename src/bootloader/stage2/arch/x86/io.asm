bits 64

global inb
global outb

section .text

    inb:
        xor rax, rax
        mov rdx, rdi
        in al, dx
        ret

    outb:
        mov rdx, rdi
        mov rax, rsi
        out dx, al
        ret
