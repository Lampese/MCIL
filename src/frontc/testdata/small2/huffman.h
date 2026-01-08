#ifndef MCIL_TESTDATA_HUFFMAN_H
#define MCIL_TESTDATA_HUFFMAN_H

#include "hash.h"
#include "pccio.h"

void bumpFrequency(PHASH, U16);
void createCompressTables(PHASH, int, int);
void initCompressor(const char *);
void startCompress(int (*)(U8));
void writeCompressedSymbol(U16);
void endCompress(void);
void startDecompress(void);
int fetchCompressedSymbol(INDATA *);
void endDecompress(INDATA *);

#endif


