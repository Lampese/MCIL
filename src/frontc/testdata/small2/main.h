#ifndef MCIL_TESTDATA_MAIN_H
#define MCIL_TESTDATA_MAIN_H

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>

#ifndef TIMESTART
#define TIMESTART(clk) do { (clk) = (double)clock(); } while (0)
#endif

#ifndef TIMESTOP
#define TIMESTOP(clk) do { (clk) = 1000000.0 * ((double)clock() - (clk)) / CLOCKS_PER_SEC; } while (0)
#endif

#ifndef ERROR0
#define ERROR0(code, msg) do { fprintf(stderr, "%s", (msg)); exit((code)); } while (0)
#endif

#ifndef ERROR3
#define ERROR3(code, msg, a, b, c) do { fprintf(stderr, (msg), (a), (b), (c)); exit((code)); } while (0)
#endif

#ifndef CREAT
#define CREAT(name) open((name), O_CREAT | O_TRUNC | O_WRONLY, 0644)
#endif

#endif


