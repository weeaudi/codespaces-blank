/**
 * @file memory.cpp
 * @author Aidcraft
 * @brief 
 * @version 0.0.2
 * @date 2025-01-27
 * 
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 * 
 */
#include "memory.h"

void* memcpy(void* dst, const void* src, uint16_t size)
{
    uint8_t* u8Dst = (uint8_t *)dst;
    const uint8_t* u8Src = (const uint8_t *)src;
    for (uint16_t i = 0; i < size; i++)
        u8Dst[i] = u8Src[i];
    return dst;
}