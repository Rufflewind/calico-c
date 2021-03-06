BENCHCPPFLAGS=-g -Wall -O3 -DNDEBUG
GLOBALCPPFLAGS=-D_POSIX_C_SOURCE=200112L
TESTCFLAGS=-std=c99
TESTCPPFLAGS=-g -Wall -Wextra -Wconversion -pedantic
TESTCXXFLAGS=-std=c++11
VALGRIND=valgrind --error-exitcode=1

all: build build-bench build-check

build: include/calico/arithmetic.h include/calico/arithmetic_impl_g.h include/calico/binary_search.h include/calico/btree.hpp include/calico/btree_head.h include/calico/btree_impl.h include/calico/btree_template.h include/calico/btree_template_impl_g.h include/calico/compat/alignas_begin.h include/calico/compat/alignas_end.h include/calico/compat/aligned_alloc_begin.h include/calico/compat/aligned_alloc_end.h include/calico/compat/alignof_begin.h include/calico/compat/alignof_end.h include/calico/compat/alloca.h include/calico/compat/inline_begin.h include/calico/compat/inline_end.h include/calico/compat/noreturn_begin.h include/calico/compat/noreturn_end.h include/calico/compat/restrict_begin.h include/calico/compat/restrict_end.h include/calico/compat/static_assert_begin.h include/calico/compat/static_assert_end.h include/calico/compat/stdint.h include/calico/frozen_btree.h include/calico/linear_ordered_search.h include/calico/macros.h include/calico/math.h include/calico/packed_arithmetic.h include/calico/shuffle.h include/calico/wclock.h prepare

build-bench: tmp/bench-btree tmp/bench-frozen_btree tmp/bench-stdmap++

build-check: tmp/test-arithmetic tmp/test-binary_search tmp/test-btree tmp/test-btree++ tmp/test-frozen_btree tmp/test-packed_arithmetic tmp/test-shuffle tmp/test-wclock

check: run-test-arithmetic run-test-binary_search run-test-btree run-test-btree++ run-test-frozen_btree run-test-packed_arithmetic run-test-shuffle run-test-wclock

clean:
	rm -fr -- include/calico/arithmetic.h include/calico/arithmetic_impl_g.h include/calico/binary_search.h include/calico/btree.hpp include/calico/btree_head.h include/calico/btree_impl.h include/calico/btree_template.h include/calico/btree_template_impl_g.h include/calico/compat/alignas_begin.h include/calico/compat/alignas_end.h include/calico/compat/aligned_alloc_begin.h include/calico/compat/aligned_alloc_end.h include/calico/compat/alignof_begin.h include/calico/compat/alignof_end.h include/calico/compat/alloca.h include/calico/compat/inline_begin.h include/calico/compat/inline_end.h include/calico/compat/noreturn_begin.h include/calico/compat/noreturn_end.h include/calico/compat/restrict_begin.h include/calico/compat/restrict_end.h include/calico/compat/static_assert_begin.h include/calico/compat/static_assert_end.h include/calico/compat/stdint.h include/calico/frozen_btree.h include/calico/linear_ordered_search.h include/calico/macros.h include/calico/math.h include/calico/packed_arithmetic.h include/calico/shuffle.h include/calico/wclock.h src/arithmetic_impl_g.h src/arithmetic_test.c.o src/binary_search_test.c.o src/black_box.c.o src/black_box_bench.c.o src/btree_bench_bench.c.o src/btree_impl_ids.txt src/btree_template_impl_g.h src/btree_test.c.o src/btree_test.cpp.o src/frozen_btree_bench_bench.c.o src/frozen_btree_test.c.o src/packed_arithmetic_test.c.o src/shuffle_test.c.o src/stdmap_bench_bench.cpp.o src/wclock_test.c.o tmp/bench-btree tmp/bench-frozen_btree tmp/bench-stdmap++ tmp/test-arithmetic tmp/test-binary_search tmp/test-btree tmp/test-btree++ tmp/test-frozen_btree tmp/test-packed_arithmetic tmp/test-shuffle tmp/test-wclock

deploy-doc: doc
	[ -d doc/html/.git ] || ( url=`git remote -v | grep origin | awk '{ printf "%s", $$2; exit }'` &&mkdir -p doc/html && cd doc/html && git init && git config user.name Bot && git config user.email '<>' && git commit -m _ --allow-empty && git remote add origin "$$url" ) && cd doc/html && git add -A && git commit --amend -q -m Autogenerated && git push -f origin master:gh-pages

doc: build
	rm -fr tmp/doc-src
	mkdir -p tmp
	cp -r include tmp/doc-src/
	mv tmp/doc-src/calico/btree_impl.h tmp/doc-src/calico/btree_template.h
	tools/generate-doxygen-mainpage <README.md >tmp/doc-src/README.md
	doxygen

prepare: src/arithmetic.h src/arithmetic_impl_g.h src/binary_search.h src/btree_head.h src/btree_impl.h src/btree_template.h src/btree_template_impl_g.h src/compat/alignas_begin.h src/compat/alignas_end.h src/compat/aligned_alloc.h src/compat/inline_begin.h src/compat/inline_end.h src/compat/static_assert_begin.h src/compat/static_assert_end.h src/compat/stdint.h src/linear_ordered_search.h src/macros.h

run-test-arithmetic: tmp/test-arithmetic
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-arithmetic

run-test-binary_search: tmp/test-binary_search
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-binary_search

run-test-btree: tmp/test-btree
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-btree

run-test-btree++: tmp/test-btree++
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-btree++

run-test-frozen_btree: tmp/test-frozen_btree
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-frozen_btree

run-test-packed_arithmetic: tmp/test-packed_arithmetic
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-packed_arithmetic

run-test-shuffle: tmp/test-shuffle
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-shuffle

run-test-wclock: tmp/test-wclock
	$(VALGRIND) $(VALGRINDFLAGS) tmp/test-wclock

include/calico/arithmetic.h: src/arithmetic.h
	@mkdir -p include/calico
	cp src/arithmetic.h $@

include/calico/arithmetic_impl_g.h: src/arithmetic_impl_g.h
	@mkdir -p include/calico
	cp src/arithmetic_impl_g.h $@

include/calico/binary_search.h: src/binary_search.h
	@mkdir -p include/calico
	cp src/binary_search.h $@

include/calico/btree.hpp: src/btree.hpp
	@mkdir -p include/calico
	cp src/btree.hpp $@

include/calico/btree_head.h: src/btree_head.h
	@mkdir -p include/calico
	cp src/btree_head.h $@

include/calico/btree_impl.h: src/btree_impl.h
	@mkdir -p include/calico
	cp src/btree_impl.h $@

include/calico/btree_template.h: src/btree_template.h
	@mkdir -p include/calico
	cp src/btree_template.h $@

include/calico/btree_template_impl_g.h: src/btree_template_impl_g.h
	@mkdir -p include/calico
	cp src/btree_template_impl_g.h $@

include/calico/compat/alignas_begin.h: src/compat/alignas_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/alignas_begin.h $@

include/calico/compat/alignas_end.h: src/compat/alignas_end.h
	@mkdir -p include/calico/compat
	cp src/compat/alignas_end.h $@

include/calico/compat/aligned_alloc_begin.h: src/compat/aligned_alloc_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/aligned_alloc_begin.h $@

include/calico/compat/aligned_alloc_end.h: src/compat/aligned_alloc_end.h
	@mkdir -p include/calico/compat
	cp src/compat/aligned_alloc_end.h $@

include/calico/compat/alignof_begin.h: src/compat/alignof_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/alignof_begin.h $@

include/calico/compat/alignof_end.h: src/compat/alignof_end.h
	@mkdir -p include/calico/compat
	cp src/compat/alignof_end.h $@

include/calico/compat/alloca.h: src/compat/alloca.h
	@mkdir -p include/calico/compat
	cp src/compat/alloca.h $@

include/calico/compat/inline_begin.h: src/compat/inline_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/inline_begin.h $@

include/calico/compat/inline_end.h: src/compat/inline_end.h
	@mkdir -p include/calico/compat
	cp src/compat/inline_end.h $@

include/calico/compat/noreturn_begin.h: src/compat/noreturn_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/noreturn_begin.h $@

include/calico/compat/noreturn_end.h: src/compat/noreturn_end.h
	@mkdir -p include/calico/compat
	cp src/compat/noreturn_end.h $@

include/calico/compat/restrict_begin.h: src/compat/restrict_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/restrict_begin.h $@

include/calico/compat/restrict_end.h: src/compat/restrict_end.h
	@mkdir -p include/calico/compat
	cp src/compat/restrict_end.h $@

include/calico/compat/static_assert_begin.h: src/compat/static_assert_begin.h
	@mkdir -p include/calico/compat
	cp src/compat/static_assert_begin.h $@

include/calico/compat/static_assert_end.h: src/compat/static_assert_end.h
	@mkdir -p include/calico/compat
	cp src/compat/static_assert_end.h $@

include/calico/compat/stdint.h: src/compat/stdint.h
	@mkdir -p include/calico/compat
	cp src/compat/stdint.h $@

include/calico/frozen_btree.h: src/frozen_btree.h
	@mkdir -p include/calico
	cp src/frozen_btree.h $@

include/calico/linear_ordered_search.h: src/linear_ordered_search.h
	@mkdir -p include/calico
	cp src/linear_ordered_search.h $@

include/calico/macros.h: src/macros.h
	@mkdir -p include/calico
	cp src/macros.h $@

include/calico/math.h: src/math.h
	@mkdir -p include/calico
	cp src/math.h $@

include/calico/packed_arithmetic.h: src/packed_arithmetic.h
	@mkdir -p include/calico
	cp src/packed_arithmetic.h $@

include/calico/shuffle.h: src/shuffle.h
	@mkdir -p include/calico
	cp src/shuffle.h $@

include/calico/wclock.h: src/wclock.h
	@mkdir -p include/calico
	cp src/wclock.h $@

src/arithmetic_impl_g.h: src/arithmetic_impl_g.h.gen.py
	tools/run-generator >$@.tmp src/arithmetic_impl_g.h.gen.py
	mv $@.tmp $@

src/arithmetic_test.c.o: src/arithmetic.h src/arithmetic_impl_g.h src/arithmetic_test.c src/compat/inline_begin.h src/compat/inline_end.h src/compat/stdint.h src/macros.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/arithmetic_test.c

src/binary_search_test.c.o: src/binary_search.h src/binary_search_test.c src/compat/inline_begin.h src/compat/inline_end.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/binary_search_test.c

src/black_box.c.o: src/black_box.c src/compat/inline_begin.h src/compat/inline_end.h src/utils.h src/wclock.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/black_box.c

src/black_box_bench.c.o: src/black_box.c src/compat/inline_begin.h src/compat/inline_end.h src/utils.h src/wclock.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(BENCHCPPFLAGS) $(BENCHCFLAGS) -c -o $@ src/black_box.c

src/btree_bench_bench.c.o: src/binary_search.h src/btree_bench.c src/btree_head.h src/btree_impl.h src/btree_template.h src/btree_template_impl_g.h src/btree_test.c src/compat/inline_begin.h src/compat/inline_end.h src/compat/static_assert_begin.h src/compat/static_assert_end.h src/linear_ordered_search.h src/macros.h src/shuffle.h src/utils.h src/wclock.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(BENCHCPPFLAGS) $(BENCHCFLAGS) -c -o $@ src/btree_bench.c

src/btree_impl_ids.txt: src/btree_impl.h src/btree_impl_ids.txt.gen.py
	tools/run-generator >$@.tmp src/btree_impl_ids.txt.gen.py
	mv $@.tmp $@

src/btree_template_impl_g.h: src/btree_impl_ids.txt src/btree_template_impl_g.h.gen.py
	tools/run-generator >$@.tmp src/btree_template_impl_g.h.gen.py
	mv $@.tmp $@

src/btree_test.c.o: src/binary_search.h src/btree_head.h src/btree_impl.h src/btree_template.h src/btree_template_impl_g.h src/btree_test.c src/compat/inline_begin.h src/compat/inline_end.h src/compat/static_assert_begin.h src/compat/static_assert_end.h src/linear_ordered_search.h src/macros.h src/shuffle.h src/utils.h src/wclock.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/btree_test.c

src/btree_test.cpp.o: src/btree.hpp src/btree_head.h src/btree_impl.h src/btree_template.h src/btree_template_impl_g.h src/btree_test.cpp src/compat/inline_begin.h src/compat/inline_end.h src/compat/static_assert_begin.h src/compat/static_assert_end.h src/linear_ordered_search.h src/macros.h
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCXXFLAGS) -c -o $@ src/btree_test.cpp

src/frozen_btree_bench_bench.c.o: src/binary_search.h src/compat/inline_begin.h src/compat/inline_end.h src/frozen_btree.h src/frozen_btree_bench.c src/linear_ordered_search.h src/macros.h src/utils.h src/wclock.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(BENCHCPPFLAGS) $(BENCHCFLAGS) -c -o $@ src/frozen_btree_bench.c

src/frozen_btree_test.c.o: src/binary_search.h src/compat/inline_begin.h src/compat/inline_end.h src/frozen_btree.h src/frozen_btree_test.c src/linear_ordered_search.h src/macros.h
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/frozen_btree_test.c

src/packed_arithmetic_test.c.o: src/arithmetic.h src/arithmetic_impl_g.h src/compat/alignas_begin.h src/compat/alignas_end.h src/compat/inline_begin.h src/compat/inline_end.h src/compat/stdint.h src/macros.h src/packed_arithmetic.h src/packed_arithmetic_test.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/packed_arithmetic_test.c

src/shuffle_test.c.o: src/shuffle.h src/shuffle_test.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/shuffle_test.c

src/stdmap_bench_bench.cpp.o: src/compat/inline_begin.h src/compat/inline_end.h src/stdmap_bench.cpp src/utils.h src/wclock.h
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(GLOBALCPPFLAGS) $(BENCHCPPFLAGS) $(BENCHCXXFLAGS) -c -o $@ src/stdmap_bench.cpp

src/wclock_test.c.o: src/compat/inline_begin.h src/compat/inline_end.h src/wclock.h src/wclock_test.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(GLOBALCPPFLAGS) $(TESTCPPFLAGS) $(TESTCFLAGS) -c -o $@ src/wclock_test.c

tmp/bench-btree: src/black_box_bench.c.o src/btree_bench_bench.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/black_box_bench.c.o src/btree_bench_bench.c.o $(LIBS)

tmp/bench-frozen_btree: src/black_box_bench.c.o src/frozen_btree_bench_bench.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/black_box_bench.c.o src/frozen_btree_bench_bench.c.o $(LIBS)

tmp/bench-stdmap++: src/black_box_bench.c.o src/stdmap_bench_bench.cpp.o
	@mkdir -p tmp
	$(CXX) $(CXXFLAGS) -o $@ src/black_box_bench.c.o src/stdmap_bench_bench.cpp.o $(LIBS)

tmp/test-arithmetic: src/arithmetic_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/arithmetic_test.c.o $(LIBS)

tmp/test-binary_search: src/binary_search_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/binary_search_test.c.o $(LIBS)

tmp/test-btree: src/black_box.c.o src/btree_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/black_box.c.o src/btree_test.c.o $(LIBS)

tmp/test-btree++: src/btree_test.cpp.o
	@mkdir -p tmp
	$(CXX) $(CXXFLAGS) -o $@ src/btree_test.cpp.o $(LIBS)

tmp/test-frozen_btree: src/frozen_btree_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/frozen_btree_test.c.o $(LIBS)

tmp/test-packed_arithmetic: src/packed_arithmetic_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/packed_arithmetic_test.c.o $(LIBS)

tmp/test-shuffle: src/shuffle_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/shuffle_test.c.o $(LIBS)

tmp/test-wclock: src/wclock_test.c.o
	@mkdir -p tmp
	$(CC) $(CFLAGS) -o $@ src/wclock_test.c.o $(LIBS)

.PHONY: all build build-bench build-check check clean deploy-doc doc prepare run-test-arithmetic run-test-binary_search run-test-btree run-test-btree++ run-test-frozen_btree run-test-packed_arithmetic run-test-shuffle run-test-wclock
