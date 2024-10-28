#include <stddef.h>  // for size_t

// Doubly linked list node structure
struct dlist {
    struct dlist *next;
    struct dlist *prev;
};

// Initialize the doubly linked list node
static inline void dlist_init(struct dlist *list) {
    list->next = list;
    list->prev = list;
}

// Insert a new node after the specified node in the list
static inline void dlist_insert_after(struct dlist *list, struct dlist *new_node) {
    new_node->next = list->next;
    new_node->prev = list;
    list->next->prev = new_node;
    list->next = new_node;
}

// Insert a new node before the specified node in the list
static inline void dlist_insert_before(struct dlist *list, struct dlist *new_node) {
    new_node->next = list;
    new_node->prev = list->prev;
    list->prev->next = new_node;
    list->prev = new_node;
}

// Remove a node from the list
static inline void dlist_remove(struct dlist *list) {
    list->prev->next = list->next;
    list->next->prev = list->prev;
    list->next = list;
    list->prev = list;
}

// Memory chunk structure for manual memory management
struct chunk {
    struct dlist all; // Part of a global chunk list
    int used;         // Is this chunk currently in use?
};

// Align value upwards to the nearest multiple of alignment
#define ALIGN_UP(val, alignment) (((val) + (alignment) - 1) & ~((alignment) - 1))

// Macros for accessing the memory within a chunk
#define CHUNK_DATA(chunk) ((void *)((struct chunk *)(chunk) + 1))
#define DATA_CHUNK(data)  ((struct chunk *)((struct chunk *)(data) - 1))

// Number of memory chunk sizes we are managing
#define NUM_SIZES 32

// Constants for memory allocation
#define ALIGN 4
#define MIN_SIZE ALIGN_UP(sizeof(struct dlist), ALIGN)

// Global variables for memory management
static struct dlist free_chunk[NUM_SIZES]; // Free list for different chunk sizes
static size_t mem_free = 0;                // Amount of free memory
static size_t mem_used = 0;                // Amount of used memory
static size_t mem_meta = 0;                // Metadata memory overhead

// Calculate the appropriate memory slot based on the requested size
static inline size_t memory_chunk_slot(size_t size) {
    size = ALIGN_UP(size, ALIGN);
    size_t slot = 0;
    while (size >>= 1) {
        slot++;
    }
    return (slot > MIN_SIZE) ? slot - MIN_SIZE : 0;
}

// Initialize the memory pool
void memory_pool_init(void *mem, size_t size) {
    struct chunk *chunk = (struct chunk *)mem;
    dlist_init(&chunk->all);  // Initialize the global list
    dlist_insert_after(&free_chunk[NUM_SIZES - 1], &chunk->all);  // Insert into free list
    mem_free = size - sizeof(struct chunk);
    mem_meta = sizeof(struct chunk);
}

// Allocate memory from the pool
void *mrvn_malloc(size_t size) {
    if (size < MIN_SIZE) size = MIN_SIZE;
    size_t slot = memory_chunk_slot(size);
    if (slot >= NUM_SIZES) return NULL; // Requested size too large

    struct dlist *free_list = &free_chunk[slot];
    if (free_list->next == free_list) return NULL;  // No free chunks available

    struct chunk *chunk = (struct chunk *)free_list->next;
    dlist_remove(&chunk->all);  // Remove chunk from the free list
    chunk->used = 1;

    mem_free -= size;
    mem_used += size;

    return CHUNK_DATA(chunk);
}

// Free memory and return it to the pool
void mrvn_free(void *ptr) {
    if (!ptr) return;  // Do nothing if ptr is NULL

    struct chunk *chunk = DATA_CHUNK(ptr);
    chunk->used = 0;

    size_t size = sizeof(*chunk) + sizeof(ptr);  // Calculate chunk size
    size_t slot = memory_chunk_slot(size);
    dlist_insert_after(&free_chunk[slot], &chunk->all);  // Return to free list

    mem_used -= size;
    mem_free += size;
}

int main() {
    return 0;
}