#ifndef MCIL_TESTDATA_BTREE_H
#define MCIL_TESTDATA_BTREE_H

typedef struct Tree Tree;
typedef void *Nptr;

#ifndef ARRAY_SIZE
#define ARRAY_SIZE 1024
#endif

#ifndef MAX_FAN_OUT
#define MAX_FAN_OUT 32
#endif

#ifndef NONODE
#define NONODE ((Nptr)0)
#endif

int compareKeys(int, int);
Tree *initBtree(int, int, int (*)(int, int));
Nptr search(Tree *, int);
void insert(Tree *, int);
void delete(Tree *, int);
void freeBtree(Tree *);

#endif


