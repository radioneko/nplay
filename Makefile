EXE := yp.exe
EXEF := _build/default/$(EXE)

r: b out
	$(EXEF)

out: out.c
	$(CC) -Wall -o$@ $<

s: b
	strace -ff -e execve $(EXEF)

b:
	dune build ./$(EXE)
