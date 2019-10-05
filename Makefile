CC=gcc
DC=ldc2
GO=go
OCAMLOPT=ocamlopt
DARTCOMP=dart2aot
DARTRUN=dartaotruntime
OCAMLFLAGS=-O3
NIMC=nim cc
JAVAC=javac
JAVA=java
JAVAFLAGS=-XX:ParallelGCThreads=4 -XX:ConcGCThreads=3
CFLAGS=-O3
DFLAGS=-O3 -release
NIMFLAGS=-d:release -d:danger --hints=off --warnings=off --verbosity=0 --nimcache=$@.build
DARTFLAGS=--marker-tasks=1
LIBGC=-lgc
WITHDLMALLOC=-w -DUSE_DL_PREFIX dlmalloc/dlmalloc.c
WITHTINYGC=-DGC_FASTCALL= -DGC_CLIBDECL= -DGC_STACKBOTTOMVAR=GC_stackend -DGC_CORE_MALLOC=dlmalloc -DGC_CORE_FREE=dlfree tinygc/tinygc.c

BENCH=/usr/bin/time
PROGRAMS=btree-jemalloc \
	 btree-dlmalloc btree-dlmalloc-lock \
	 btree-gc btree-gc-inc btree-gc-free \
	 btree-ml \
	 btree-nim btree-nim-boehm btree-nim-ms \
	 btree-d \
	 btree-d-struct \
	 btree.class \
	 btree-dart.aot \
	 btree-go \
	 btree-sysmalloc \
	 btree-tiny-gc \
	 btree-hs
DEPTH=21

all: $(PROGRAMS)
benchmark: $(PROGRAMS)
	# haskell
	$(BENCH) ./btree-hs $(DEPTH) > /dev/null
	# jemalloc explicit malloc()/free()
	$(BENCH) ./btree-jemalloc $(DEPTH) >/dev/null
	# dlmalloc explicit malloc()/free() (not threadsafe)
	$(BENCH) ./btree-dlmalloc $(DEPTH) >/dev/null
	# dlmalloc explicit malloc()/free() (threadsafe)
	$(BENCH) ./btree-dlmalloc-lock $(DEPTH) >/dev/null
	# Boehm GC with four parallel marker threads
	GC_MARKERS=4 $(BENCH) ./btree-gc $(DEPTH) >/dev/null
	# Boehm GC with single-threaded marking
	GC_MARKERS=1 $(BENCH) ./btree-gc $(DEPTH) >/dev/null
	# Boehm GC with explicit deallocation
	GC_MARKERS=1 $(BENCH) ./btree-gc-free $(DEPTH) >/dev/null
	# Boehm GC with incremental collection
	GC_MARKERS=4 $(BENCH) ./btree-gc-inc $(DEPTH) >/dev/null
	# OCaml
	$(BENCH) ./btree-ml $(DEPTH) >/dev/null
	# Nim reference counting GC
	$(BENCH) ./btree-nim $(DEPTH) >/dev/null
	# Nim mark and sweep GC
	$(BENCH) ./btree-nim-ms $(DEPTH) >/dev/null
	# Nim with Boehm GC
	GC_MARKERS=4 $(BENCH) ./btree-nim-boehm $(DEPTH) >/dev/null
	# D garbage collector (classes)
	$(BENCH) ./btree-d $(DEPTH) >/dev/null
	# D garbage collector (structs)
	$(BENCH) ./btree-d-struct $(DEPTH) >/dev/null
	# Go garbage collector
	GOMAXPROCS=4 $(BENCH) ./btree-go $(DEPTH) >/dev/null
	# Dart garbage collector
	$(BENCH) $(DARTRUN) $(DARTFLAGS) btree-dart.aot $(DEPTH) >/dev/null
	# Java default garbage collector
	$(BENCH) $(JAVA) $(JAVAFLAGS) btree $(DEPTH) >/dev/null
	# System malloc()/free()
	$(BENCH) ./btree-sysmalloc $(DEPTH) >/dev/null
	# Tiny GC (w/ dlmalloc as base allocator)
	$(BENCH) ./btree-tiny-gc $(DEPTH) >/dev/null

btree-jemalloc: btree.c
	$(CC) $(CFLAGS) -DUSE_JEMALLOC -o $@ $< -ljemalloc -lm
btree-dlmalloc: btree.c
	$(CC) $(CFLAGS) -DUSE_DLMALLOC $(WITHDLMALLOC) -o $@ $< -lm
btree-dlmalloc-lock: btree.c
	$(CC) $(CFLAGS) -DUSE_DLMALLOC -DUSE_MALLOC_LOCK $(WITHDLMALLOC) -o $@ $< -lm
btree-gc: btree.c
	$(CC) $(CFLAGS) -DUSE_BOEHM_GC -o $@ $< $(LIBGC) -lm
btree-gc-free: btree.c
	$(CC) $(CFLAGS) -DUSE_BOEHM_GC -DEXPLICIT_FREE -o $@ $< $(LIBGC) -lm
btree-gc-inc: btree.c
	$(CC) $(CFLAGS) -DUSE_BOEHM_GC -DUSE_INC_GC -o $@ $< $(LIBGC) -lm
btree-tiny-gc: btree.c
	$(CC) $(CFLAGS) -DUSE_TINY_GC $(WITHTINYGC) $(WITHDLMALLOC) -o $@ $< -lm
btree-sysmalloc: btree.c
	$(CC) $(CFLAGS) -o $@ $< -lm
btree-nim: btree.nim
	$(NIMC) $(NIMFLAGS) -o=$@ $<
btree-nim-boehm: btree.nim
	$(NIMC) $(NIMFLAGS) --gc=boehm -o=$@ $<
btree-nim-ms: btree.nim
	$(NIMC) $(NIMFLAGS) --gc=markandsweep -o=$@ $<
btree-d: btree.d
	$(DC) $(DFLAGS) -of=$@ $<
btree-d-struct: btree.d
	$(DC) $(DFLAGS) -d-version=UseStructs -of=$@ $<
btree-go: btree.go
	$(GO) build -o $@ $<
btree-hs: btree-hs.lhs
	stack ghc -- --make -O3 $<
btree-ml: btree.ml
	$(OCAMLOPT) $(OCAMLFLAGS) -o $@ $<
btree.class: btree.java
	$(JAVAC) $<
btree-dart.aot: btree.dart
	$(DARTCOMP) $< $@

version:
	@printf "jemalloc "; jemalloc-config --version | sed -e 's/-.*//'
	@printf '#include <gc/gc.h>\nGC_VERSION_MAJOR GC_VERSION_MINOR GC_VERSION_MICRO'| gcc -E - | tail -1 | awk '{print "Boehm GC "$$1"."$$2"."$$3 }'
	@$(CC) -v 2>&1 | egrep ' version '
	@$(DC) --version | head -1
	@$(NIMC)  --version | head -1
	@go version
	@printf "ocamlopt "; ocamlopt -version
	@dart --version
	@javac -version

clean:
	rm -f $(PROGRAMS)
	rm -rf btree*.o btree.cm? btree*.class btree*.dill btree*.build
.PHONY: all benchmark clean
