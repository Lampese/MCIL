#ifndef MCIL_TESTDATA_REDBLACK_H
#define MCIL_TESTDATA_REDBLACK_H

typedef struct RBNode RBNode;

int insertRB(RBNode **root, int key, int datasize);
int findRB(RBNode *root, int key);

#ifndef FORALLRBNODES
#define FORALLRBNODES(root, body) do { (void)(root); } while (0)
#endif

#endif


