extern "C" {
#include "myalloc.h"
}

#include <stdlib.h>

void *my_aligned_alloc(size_t alignment, size_t size) {
  // aligned_alloc(alignment, size);
  return _aligned_malloc(alignment, size);
}

void my_free(void *block) { _aligned_free(block); }
