#include "paging.h"

#define PAGE_SIZE    4096
#define NUM_ENTRIES  512

// Page table flags.
#define PAGE_PRESENT 0x1
#define PAGE_RW      0x2
#define PAGE_PS      0x80  // When set in a PD entry, indicates a 2MB page.

typedef uint64_t pt_entry_t;

#define MAX_PAGES 16
static uint8_t* pt_pool = (uint8_t*)MEMORY_PAGE_TABLE_START;
static uint32_t pt_next = 0;

// Allocate a new zeroed 4KB page for a page table.
static pt_entry_t *alloc_page_table(void) {
    if (pt_next >= MAX_PAGES)
        return 0;  // Out of pages; in a real system, handle this error appropriately.
    void *page = (void *)(&pt_pool[pt_next * PAGE_SIZE]);
    pt_next++;
    memset(page, 0, PAGE_SIZE);
    return (pt_entry_t *)page;
}

// The top-level (PML4) page table.
static pt_entry_t *pml4 = 0;

/*
 * Map a single 4KB page so that the virtual address 'virt'
 * refers to the physical (linear) address 'linear'.
 *
 * Both 'linear' and 'virt' must be 4KB aligned.
 */
void page(uint64_t linear, uint64_t virt) {
    // Ensure the PML4 table exists.
    if (!pml4) {
        pml4 = alloc_page_table();
        if (!pml4)
            return; // Allocation failure.
    }

    // Calculate indices into the page tables.
    uint64_t pml4_index = (virt >> 39) & 0x1FF;
    uint64_t pdpt_index = (virt >> 30) & 0x1FF;
    uint64_t pd_index   = (virt >> 21) & 0x1FF;
    uint64_t pt_index   = (virt >> 12) & 0x1FF;

    pt_entry_t *pdpt;
    // Get (or allocate) the PDPT.
    if (pml4[pml4_index] & PAGE_PRESENT) {
        pdpt = (pt_entry_t *)(pml4[pml4_index] & ~0xFFFULL);
    } else {
        pdpt = alloc_page_table();
        if (!pdpt)
            return;
        pml4[pml4_index] = (uint64_t)pdpt | PAGE_PRESENT | PAGE_RW;
    }

    pt_entry_t *pd;
    // Get (or allocate) the PD.
    if (pdpt[pdpt_index] & PAGE_PRESENT) {
        pd = (pt_entry_t *)(pdpt[pdpt_index] & ~0xFFFULL);
    } else {
        pd = alloc_page_table();
        if (!pd)
            return;
        pdpt[pdpt_index] = (uint64_t)pd | PAGE_PRESENT | PAGE_RW;
    }

    pt_entry_t *pt;
    // Get (or allocate) the PT.
    if (pd[pd_index] & PAGE_PRESENT) {
        // If the PS (Page Size) bit is set then this PD entry maps a 2MB page,
        // so we cannot install a 4KB mapping here.
        if (pd[pd_index] & PAGE_PS)
            return;
        pt = (pt_entry_t *)(pd[pd_index] & ~0xFFFULL);
    } else {
        pt = alloc_page_table();
        if (!pt)
            return;
        pd[pd_index] = (uint64_t)pt | PAGE_PRESENT | PAGE_RW;
    }

    // Install the mapping in the PT.
    pt[pt_index] = (linear & ~0xFFFULL) | PAGE_PRESENT | PAGE_RW;
}

/*
 * Map a range of memory.
 *
 * 'linear'  - The starting physical (linear) address.
 * 'virt'    - The starting virtual address.
 * 'size'    - The total number of bytes to map.
 *
 * Both 'linear' and 'virt' should be 4KB aligned. If 'size' is not a multiple
 * of 4KB, it will be rounded up to cover the entire range.
 */
void page_range(uint64_t linear, uint64_t virt, uint64_t size) {
    // Calculate the number of pages needed (round up if size isn't a multiple of PAGE_SIZE).
    uint64_t pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;
    for (uint64_t i = 0; i < pages; i++) {
        page(linear + i * PAGE_SIZE, virt + i * PAGE_SIZE);
    }
}

/*
 * Map a single 2MB page so that the virtual address 'virt'
 * refers to the physical (linear) address 'linear'.
 *
 * Both 'linear' and 'virt' must be 2MB aligned.
 */
void page_large(uint64_t linear, uint64_t virt) {
    // Ensure the PML4 table exists.
    if (!pml4) {
        pml4 = alloc_page_table();
        if (!pml4)
            return; // Allocation failure.
    }
    
    // Calculate indices into the page tables.
    uint64_t pml4_index = (virt >> 39) & 0x1FF;
    uint64_t pdpt_index = (virt >> 30) & 0x1FF;
    uint64_t pd_index   = (virt >> 21) & 0x1FF;
    
    pt_entry_t *pdpt;
    // Get (or allocate) the PDPT.
    if (pml4[pml4_index] & PAGE_PRESENT) {
        pdpt = (pt_entry_t *)(pml4[pml4_index] & ~0xFFFULL);
    } else {
        pdpt = alloc_page_table();
        if (!pdpt)
            return;
        pml4[pml4_index] = (uint64_t)pdpt | PAGE_PRESENT | PAGE_RW;
    }
    
    pt_entry_t *pd;
    // Get (or allocate) the PD.
    if (pdpt[pdpt_index] & PAGE_PRESENT) {
        pd = (pt_entry_t *)(pdpt[pdpt_index] & ~0xFFFULL);
    } else {
        pd = alloc_page_table();
        if (!pd)
            return;
        pdpt[pdpt_index] = (uint64_t)pd | PAGE_PRESENT | PAGE_RW;
    }
    
    // Install the 2MB mapping in the PD.
    // Check if a mapping already exists.
    if (pd[pd_index] & PAGE_PRESENT)
        return; // Already mapped.
    
    // Ensure that the physical address is 2MB aligned.
    pd[pd_index] = (linear & ~0x1FFFFFULL) | PAGE_PRESENT | PAGE_RW | PAGE_PS;
}

/*
 * Map a range of memory using 2MB pages.
 *
 * 'linear'  - The starting physical (linear) address.
 * 'virt'    - The starting virtual address.
 * 'size'    - The total number of bytes to map.
 *
 * Both 'linear' and 'virt' should be 2MB aligned. If 'size' is not a multiple
 * of 2MB, it will be rounded up to cover the entire range.
 */
void page_range_large(uint64_t linear, uint64_t virt, uint64_t size) {
    const uint64_t LARGE_PAGE_SIZE = 2 * 1024 * 1024;  // 2MB per page.
    uint64_t pages = (size + LARGE_PAGE_SIZE - 1) / LARGE_PAGE_SIZE;
    for (uint64_t i = 0; i < pages; i++) {
        page_large(linear + i * LARGE_PAGE_SIZE, virt + i * LARGE_PAGE_SIZE);
    }
}

/*
 * Initialize the page tables so that the first 1GB of memory is
 * identity-mapped using large (2MB) pages.
 *
 * This function also loads the new PML4 table into CR3.
 */
void init_map(void) {
    // Allocate the top-level PML4.
    pml4 = alloc_page_table();
    if (!pml4)
        return;
    
    // Allocate the PDPT.
    pt_entry_t *pdpt = alloc_page_table();
    if (!pdpt)
        return;
    pml4[0] = (uint64_t)pdpt | PAGE_PRESENT | PAGE_RW;
    
    // Allocate the PD.
    pt_entry_t *pd = alloc_page_table();
    if (!pd)
        return;
    pdpt[0] = (uint64_t)pd | PAGE_PRESENT | PAGE_RW;
    
    // Fill the PD with 512 entries mapping 2MB each (512 * 2MB = 1GB).
    for (int i = 0; i < NUM_ENTRIES; i++) {
        uint64_t addr = i * (2ULL * 1024 * 1024); // 2MB per entry.
        pd[i] = addr | PAGE_PRESENT | PAGE_RW | PAGE_PS;
    }
    
    // Load the new PML4 table into CR3.
    asm volatile("mov %0, %%cr3" :: "r"(pml4) : "memory");
}
