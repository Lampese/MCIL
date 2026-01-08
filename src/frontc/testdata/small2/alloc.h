#ifndef MCIL_TESTDATA_ALLOC_H
#define MCIL_TESTDATA_ALLOC_H

#include <stddef.h>

void *xmalloc(size_t);
void *xrealloc(void *, size_t);
void xfree(void *);

#endif


