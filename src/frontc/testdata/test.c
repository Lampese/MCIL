#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    int value;
    struct Node* next;
} Node;

int global_flag = 0;

/* ---------- helper ---------- */

Node* make_node(int v) {
    Node* n = (Node*)malloc(sizeof(Node));
    if (!n) return NULL;
    n->value = v;
    n->next = NULL;
    return n;
}

/* pointer escape + alias */
void link(Node** a, Node* b) {
    if (a) {
        *a = b;
    }
}

/* ---------- core logic ---------- */

int compute(int x) {
    int y;
    if (x > 0) {
        y = x * 2;
    }
    // ❌ y may be uninitialized
    return y + 1;
}

void tricky_free(Node* n, int cond) {
    if (!n) return;

    if (cond) {
        free(n);
    }

    if (global_flag) {
        // ❌ potential double free
        free(n);
    }
}

int loop_phi(int n) {
    int acc = 0;
    int i;

    for (i = 0; i < n; i++) {
        if (i % 2 == 0)
            acc = acc + i;
        else
            acc = acc - i;
    }
    return acc;
}

void alias_test() {
    Node* a = make_node(1);
    Node* b = make_node(2);

    Node* p = NULL;
    link(&p, a);

    Node* q = p;      // alias p
    q->value = 42;

    if (rand() % 2) {
        free(a);
    }

    // ❌ p / q may be dangling
    printf("%d\n", p->value);

    free(b);
}

/* ---------- main ---------- */

int main(int argc, char** argv) {
    int x = argc > 1 ? atoi(argv[1]) : -1;

    int r = compute(x);
    printf("r = %d\n", r);

    Node* n = make_node(10);
    global_flag = (x % 2 == 0);

    tricky_free(n, x > 0);

    int s = loop_phi(x);
    printf("s = %d\n", s);

    alias_test();

    // ❌ use-after-free possibility
    if (n) {
        printf("%d\n", n->value);
    }

    return 0;
}
