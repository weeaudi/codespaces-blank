ENTRY(start)
OUTPUT_FORMAT("binary")
phys = 0x700;

SECTIONS
{
    . = phys;

    .fsjump                     : {                         *(.fsjump)      }
    .fsheaders                  : {                         *(.fsheaders)   }
    .entry                      : { __entry_start = .;      *(.entry)       }
    .text                       : { __text_start = .;       *(.text)        }
    .data                       : { __data_start = .;       *(.data)        }
    .rodata                     : { __rodata_start = .;     *(.rodata)      }
    .bios_footer phys + 0x1FE   : {                         SHORT(0xAA55)   }
    .bss                        : { __bss_start = .;        *(.bss)         }

    __end = .;
}
