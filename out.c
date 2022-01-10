#include <stdio.h>
#include <signal.h>

int main()
{
	printf("STDOUT text\n");
	fprintf(stderr, "STDERR output\n");
	fflush(stdout);
	fflush(stderr);
	*(volatile int*)0 = 0;
	raise(SIGILL);
	return 12;
}
