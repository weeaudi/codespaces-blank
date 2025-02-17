#pragma once

#include "../stdint.h"

/**
 * @brief Memory map structure.
 */
struct memory_map
{
    /// @brief Base of the entry
    uint64_t base;
    /// @brief Size of the entry
    uint64_t length;
    /// @brief type of the entry
    uint32_t type;
    /// @brief ACPI 3.0 Extended Attributes bitfield
    uint32_t acpi3;
} __attribute__((packed));

#define MEMORY_STAGE2_START 0x00001000
#define MEMORY_STAGE2_END 0x0020000
#define MEMORY_STAGE2_SIZE (MEMORY_STAGE2_END - MEMORY_STAGE2_START)

#define MEMORY_FAT_START 0x0020000
#define MEMORY_FAT_END 0x0100000
#define MEMORY_FAT_SIZE (MEMORY_FAT_END - MEMORY_FAT_START)

/**
 * @brief Copies from src to dst by amount of size
 * 
 * @param[out] dst the destination to copy to
 * @param[in] src the source to copy from
 * @param[in] size the amount to copy
 * @return void* a pointer to the destination
 */
void* memcpy(void* dst, const void* src, uint16_t size);
void* memset(void* dst, uint8_t val, uint16_t size);
bool memcmp(const void* dst, const void* src, uint16_t size);
