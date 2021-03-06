import logging, os, re, subprocess, sys
import makegen as mk
sys.path.insert(0, "tools")
import utils

def make_preprocess_rules(fns):
    for fn in fns:
        m = re.match("(.*?)\.gen\.py$", fn)
        if not m:
            continue
        out_fn, = m.groups()
        deps = [mk.snormpath(os.path.join(os.path.dirname(fn), x))
                for x in utils.FileGenerator(fn).deps]
        deps.insert(0, fn)
        yield mk.simple_command(
            [
                "tools/run-generator >$@.tmp {fn}".format(**locals()),
                "mv $@.tmp $@",
            ],
            out_fn,
            deps,
            no_format=True,
        )

def make_copy_header_rules(fns, extensions, prefix=""):
    ppfiles = []
    rules = []
    for fn in fns:
        name, ext = os.path.splitext(os.path.basename(fn))
        if ext not in extensions:
            continue
        pp = utils.Preprocessor(fn)
        pp.preprocess()
        if not pp.attributes.get("public", False):
            continue
        relpath, = re.match("src/(.*)$", fn).groups()
        out_fn = "include/" + prefix + relpath
        rules.append(mk.simple_command(
            "cp {fn} $@".format(**locals()),
            out_fn,
            [fn],
        ))
        for dep_fn in mk.get_cpp_includes(fn):
            ppfiles.append(mk.plain_file(dep_fn))
    return rules, ppfiles

def make_run_test_rule(program_ruleset):
    return mk.simple_command("$(VALGRIND) $(VALGRINDFLAGS) {0}",
        "run-" + os.path.basename(program_ruleset.default_target),
        [program_ruleset], phony=True)

def parse_dependencies(filename):
    dn = os.path.dirname(filename)
    try:
        pp = utils.Preprocessor(filename)
        pp.preprocess()
        return [mk.snormpath(os.path.join(dn, bn))
                for bn in pp.attributes["deps"]]
    except OSError as e:
        logging.warn("cannot preprocess {0} ({1})".format(filename, e))
    return []

class DepParser(object):

    def __init__(self):
        self._cache = {} # filename -> deps

    def __getitem__(self, filename):
        try:
            return self._cache[filename]
        except KeyError:
            pass
        value = (mk.get_cpp_includes(filename), parse_dependencies(filename))
        self._cache[filename] = value
        return value

    def get_obj_deps(self, filename):
        queue = [filename]
        seen = set(queue)
        deps = set(queue)
        while queue:
            fn = queue.pop()
            incls, objs = self[fn]
            for new_fn in incls:
                if not new_fn in seen:
                    seen.add(new_fn)
                    queue.append(new_fn)
            for new_fn in objs:
                if not new_fn in seen:
                    deps.add(new_fn)
                    seen.add(new_fn)
                    queue.append(new_fn)
        return sorted(deps)

def make_test_rules(fns, extensions, root):
    dp = DepParser()
    for fn in fns:
        name, ext = os.path.splitext(os.path.basename(fn))
        if ext not in extensions:
            continue
        m = re.match("(.*?)_(test|bench)$", name)
        if not m:
            continue
        out_name, type = m.groups()
        dn = os.path.dirname(fn)
        src_fns = dp.get_obj_deps(fn)
        test_name = mk.snormpath(os.path.join(
            os.path.relpath(dn, root),
            out_name
        )).replace("/", "-")
        if ext == ".cpp":
            test_name += "++"
        if type == "test":
            build_check_rule = mk.build_program("tmp/test-" + test_name, [
                mk.compile_source(
                    src_fn,
                    extra_flags=("$(GLOBALCPPFLAGS) $(TESTCPPFLAGS) " +
                                 ("$(TESTCXXFLAGS)"
                                  if src_fn.endswith(".cpp")
                                  else "$(TESTCFLAGS)")),
                    suffix="",
                    extension_suffix=True,
                ) for src_fn in src_fns
            ], libraries="$(LIBS)")
            check_rule = make_run_test_rule(build_check_rule)
            bench_rule = None
        else:
            build_check_rule = None
            check_rule = None
            bench_rule = mk.build_program("tmp/bench-" + test_name, [
                mk.compile_source(
                    src_fn,
                    extra_flags=("$(GLOBALCPPFLAGS) $(BENCHCPPFLAGS) " +
                                 ("$(BENCHCXXFLAGS)"
                                  if src_fn.endswith(".cpp")
                                  else "$(BENCHCFLAGS)")),
                    suffix="_bench",
                    extension_suffix=True,
                ) for src_fn in src_fns
            ], libraries="$(LIBS)")
        yield build_check_rule, check_rule, bench_rule

def make_deploy_doc_rule(doc_dir, doc_rule, branch="origin"):
    return mk.simple_command(
            "[ -d {0}/.git ] || ( "
                "url=`git remote -v | grep {1} | "
                    "awk '{{ printf \"%s\", $$2; exit }}'` &&"
                "mkdir -p {0} && "
                "cd {0} && "
                "git init && "
                "git config user.name Bot && "
                "git config user.email '<>' && "
                "git commit -m _ --allow-empty && "
                'git remote add origin "$$url" '
            ") && "
            "cd {0} && "
            "git add -A && "
            "git commit --amend -q -m Autogenerated && "
            "git push -f origin master:gh-pages"
        .format(doc_dir, branch),
        "deploy-doc",
        [doc_rule],
        phony=True,
        no_format=True)

mk.init_logger()

root = "src"

srcs = list(utils.get_all_files(root))

pp_rules = list(make_preprocess_rules(srcs))

rules, ppfiles = make_copy_header_rules(srcs, [".h", ".hpp"], prefix="calico/")
prepare_rule = mk.alias("prepare", ppfiles)

test_rules = list(make_test_rules(srcs, [".c", ".cpp"], root))

build_rule = mk.alias("build", rules + [prepare_rule])

build_bench_rule = mk.alias("build-bench", [x[2] for x in test_rules
                                            if x[2] is not None])

build_check_rule = mk.alias("build-check", [x[0] for x in test_rules
                                            if x[0] is not None])

check_rule = mk.alias("check", [x[1] for x in test_rules
                                if x[1] is not None])

doc_rule = mk.simple_command([
    "rm -fr tmp/doc-src",
    "mkdir -p tmp",
    "cp -r include tmp/doc-src/",
    "mv tmp/doc-src/calico/btree_impl.h tmp/doc-src/calico/btree_template.h",
    "tools/generate-doxygen-mainpage <README.md >tmp/doc-src/README.md",
    "doxygen",
], "doc", [build_rule], phony=True)

mk.alias("all", [
    build_rule,
    build_bench_rule,
    build_check_rule,
]).merge(
    check_rule,
    doc_rule,
    make_deploy_doc_rule("doc/html", doc_rule),
    mk.Ruleset(macros={
        "GLOBALCPPFLAGS": "-D_POSIX_C_SOURCE=199309L",
        "BENCHCPPFLAGS": "-g -Wall -O3 -DNDEBUG",
        "TESTCPPFLAGS": "-g -Wall -Wextra -Wconversion -pedantic",
        "TESTCFLAGS": "-std=c99",
        "TESTCXXFLAGS": "-std=c++11",
        "VALGRIND": "valgrind",
    }),
    *pp_rules
).save()
