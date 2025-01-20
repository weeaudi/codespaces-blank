%ifndef __CONFIG_INC__
%define __CONFIG_INC__

; stage1 will realocate itself to this address
; make sure to leave enough space for stack
; don't forget to update linker offset
STAGE1_SEGMENT  equ 0x0000
STAGE1_OFFSET   equ 0x0700

%endif