#ifndef MCIL_TESTDATA_HASH_H
#define MCIL_TESTDATA_HASH_H

typedef unsigned int HASH_KEY;
typedef void *PHASH;
typedef unsigned int UPOINT;

PHASH NewHash(void);
void FreeHash(PHASH);
int InsertInHash(PHASH, HASH_KEY, void *, void *);
int LookupInHash(PHASH, HASH_KEY, void **);

#endif


