ENTRY(entry)
OUTPUT_FORMAT("elf64-x86-64")
phys = 0x00001000;

SECTIONS
{
    . = phys;
    
    .text           : { __text_start = .;       *(.text)         }
    .data           : { __data_start = .;       *(.data)         }
    .rodata         : { __rodata_start = .;     *(.rodata)       }
    .bss            : { __bss_start = .;        *(.bss)          }

    __end = .;
}