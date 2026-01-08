#ifndef MCIL_TESTDATA_PCCIO_H
#define MCIL_TESTDATA_PCCIO_H

typedef unsigned char U8;
typedef unsigned short U16;
typedef unsigned int U32;
typedef unsigned int UPOINT;

typedef struct {
  int dummy;
} INDATA;

void initLFIOFile(INDATA *, const char *);
int canFetch(INDATA *, int);
U16 fetchWordLE(INDATA *);
void finishIOFile(INDATA *);

#endif


