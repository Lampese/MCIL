#ifndef MCIL_TESTDATA_MALLOC_H
#define MCIL_TESTDATA_MALLOC_H

#include <stddef.h>

void *malloc(size_t);
void free(void *);
void *calloc(size_t, size_t);
void *realloc(void *, size_t);

#endif


