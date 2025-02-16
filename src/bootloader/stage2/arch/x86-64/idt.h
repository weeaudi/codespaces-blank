#pragma once

#include "../../stdio.h"

/// @brief code segment for the kernel (found in Stage2-LongEnter.asm)
#define GDT_OFFSET_KERNEL_CODE 0x8

#define IDT_MAX_ENTRIES 256
#define IDT_MAX_DESCRIPTORS IDT_MAX_ENTRIES

/// @brief Struct for an interrupt descriptor entry
typedef struct {
	/// @brief The lower 16 bits of the ISR's address
	uint16_t    isr_low;
	/// @brief The GDT segment selector that the CPU will load into CS before calling the ISR
	uint16_t    kernel_cs;    
	/// @brief The IST in the TSS that the CPU will load into RSP; set to zero for now
	uint8_t	    ist;      
	/// @brief Type and attributes; see the IDT page
	uint8_t     attributes;  
	/// @brief The higher 16 bits of the lower 32 bits of the ISR's address
	uint16_t    isr_mid;     
	/// @brief The higher 32 bits of the ISR's address
	uint32_t    isr_high;   
	/// @brief Set to zero
	uint32_t    reserved;
} __attribute__((packed)) idt_entry_t;

/// @brief the thing we actually load into the cpu
typedef struct {
	/// @brief size of the idt
	uint16_t	limit;
	/// @brief address of the idt
	uint64_t	base;
} __attribute__((packed)) idtr_t;


/// @brief general exception handler
extern "C" void __attribute__((noreturn)) exception_handler();

/// @brief sets an entry in the idt to isr
/// @param[in] vector the vector number for the interrupt
/// @param[in] isr pointer to the handler
/// @param[in] flags flags for the entry
void idt_set_descriptor(uint8_t vector, void* isr, uint8_t flags);

/// @brief loads the idt stub table and the idt itself
void idt_init();