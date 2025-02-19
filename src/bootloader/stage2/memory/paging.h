/**
 * @file paging.h
 * @author Aidcraft
 * @brief paging functions
 * @version 0.0.2
 * @date 2025-02-18
 * 
 * @copyright Copyright (c) 2025 Aiden Gursky. All Rights Reserved
 * @par License:
 * This project is released under the Artistic License 2.0
 * 
 */

#include "../stdint.h"
#include "memory.h"

void init_map(void);
void page(uint64_t linear, uint64_t virt);
void page_range(uint64_t linear, uint64_t virt, uint64_t size);
void page_large(uint64_t linear, uint64_t virt);
void page_range_large(uint64_t linear, uint64_t virt, uint64_t size);