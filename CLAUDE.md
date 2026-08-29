# Working on The Coco

README.md says what The Coco is and where it is aimed. This says how to
work in here and what will bite you.

## The three pillars are frozen — all three

**Only this repository may be modified.** cicili, ZiguratIP and cocolog
are inputs, the way ZiguratIP and cicili are inputs to cocolog: The Coco
uses all three and modifies none. A Coco problem that traces into a
pillar gets a diagnosis and a proposed patch in THAT repository on its
own merits — never a workaround that quietly forks behavior here.

What the freeze allows, exactly as cocolog's own CLAUDE.md draws the
line: compiling The Coco's OWN Parsi objects into `$ZIGURATIP_HOME/ld`
(the `parsi` compiler writes there, `*.so` is not tracked), and the
server writing to `$ZIGURATIP_HOME/data`. `git status` in every pillar
stays empty. Verify that it does.

## What The Coco is made of

Four materials, and only four:

* `.pl` files, consulted by the one `cocolog` binary — consensus rules,
  contracts, validity predicates are clauses; a clauses-only library
  goes on `$COCOLOG_LIBRARY` and `use_module(library(Name))` loads it.
* Cicili modules against cocolog's `lib/sdk.cicili`: the C half of a
  predicate Prolog cannot reach, compiled to a shared object and loaded
  at run time by `use_module` — cocolog unmodified, the module ours.
  cocolog's MODULES.md is the developer guide to both ways.
* Parsi objects of The Coco's own, compiled into the server home. A
  Parsi procedure's backticks reach Zigurat's C++ directly — the other
  road to `Cryptography/`'s sha256, HMAC, signatures and certificates,
  when the work belongs on the server rather than in the process.
* `run.sh` choreography, in the mold of cocolog's coworker tasks.

C-shaped work in this repository is written in CICILI AND ITS MACROS,
always — never raw C or C++; only inside ZiguratIP is there a choice
between C++ and Cicili. If a piece of work seems to need more than
these four materials, the design is wrong or the capability belongs in
a pillar.

## Environment and running

**`coco.yaml` is the one declaration** — where the pillars are, which
knowledge base the wire cases speak to, which Cicili modules exist,
which suite cases exist. Every script reads it by sourcing
`test/config.sh`; none of them carries its own copy of any of it. Add a
crypto module by adding a line under `modules.crypto`, and both
`build.sh` and `crypto.sh` pick it up. **A fact that appears in two
places will disagree with itself eventually**, and the disagreement is
always silent.

The environment still wins over the file, so nothing below is required
when the four checkouts are siblings:

```sh
export CICILI=/home/user/cicili                  # for building the pillars
export ZIGURATIP=/home/user/ZiguratIP            # a BUILT ZiguratIP
export ZIGURATIP_HOME=/home/user/ZiguratIP/home
export COCOLOG=/home/user/cocolog                # a BUILT cocolog checkout
sh test/run.sh                                   # the suite
```

**One dial string, in `config.sh`.** Every script reaches the store
through `$ZIGURAT_DIAL`, built once from `arrangement:` — twelve copies
of `--host H --port P` were twelve places to edit to try the hub over an
encrypted link, and `--port` is deprecated in cocolog anyway (`--tcp
PORT` is the same field and names the transport). `ZIGURAT_TRANSPORT=tls`
turns the whole hub secure; `ZIGURAT_CACERT`, `ZIGURAT_CERT` and
`ZIGURAT_KEY` are the rest of it, and cert/key go together or not at all.

**TLS changes the link, not one verdict**, and `test/secure.sh` proves it
by re-running `ledger`, `spine` and `votes` behind a terminator and
requiring the verdict lines to be identical — including the deliberate
successes. If a change here ever makes those two runs differ, the
difference is the finding: a consensus law that depends on the transport
is a consensus law that is wrong. The same case holds the converse, which
is the one an encrypted transport invites you to forget: **an
authenticated peer is not a trusted one.** Mallory over a verified TLS
link is refused exactly as she was in the clear, because `valid_block/6`
asks who signed the block and never who opened the socket. Never add a
"peer is authenticated, skip re-verification" path.

**THE MONEY IS `library(coco)`, AND IT NEEDS A COCOLOG NEW ENOUGH.**
COCO is the chain's native token and its gas is the ENGINE's inference
count, read with cocolog's `call_metered/4` — a builtin that did not
exist until this repository needed it and was built over there, on its
own merits, with `test/meter.sh` beside it. A cocolog older than that
answers `existence_error(procedure, call_metered/4)` from the middle of
`coco_apply/4`, which names the predicate and not the cause. Rebuild the
pillar.

Two shapes to keep straight, because both are called tokens.
`contracts/token/` is ERC-20's and ERC-721's, deployed ON a chain and
fenced. `library(coco)` is what the chain CHARGES IN, and it cannot be a
contract for a reason worth remembering rather than looking up: the fence
has no way to price its own execution, and a contract able to move the
billing currency would be a contract that pays itself. So no `coco_*`
predicate is in `library(contract)`'s vocabulary, and none may be added.

config.sh's parser is a small awk over a deliberately small subset:
`key: value` two levels deep, `- item` lists, `#` comments after
whitespace. It is not YAML and does not pretend to be. If a
configuration needs more than that, the configuration is wrong — the
four materials do not include a schema language.

The server, which the wire cases need — start it detached; a plain
`nohup ... &` from a tool call does not survive the turn:

```sh
cd /home/user/ZiguratIP && ZIGURATIP_HOME=$PWD/home \
  LD_LIBRARY_PATH=$PWD/home/lib setsid ./home/bin/ziguratip
```

### One compiler across all three, and it is clang

`modules/*/build.sh` source `tools/cc/env.sh`, which puts `tools/cc` on
`PATH` and points CC and CXX at the wrappers there. cocolog and ZiguratIP
carry an identical copy, and that duplication is the point: these modules
are `dlopen`'d into the cocolog binary, which itself links ZiguratIP's
libCore, so one process ends up holding all three toolchains' output. A
mixed build is two ABIs in one address space.

Two things in `tools/cc/README` are worth reading before a build
surprises you. **Cicili names `gcc` outright** and takes no override — it
is frozen, so `gcc`/`g++` there are shims onto the real wrappers, on PATH
for that one step. And **`clang++` alone does not compile C++ here**: it
borrows libstdc++ from the newest gcc it can find, which on Ubuntu 24.04
is gcc-14's runtime directory, and that one ships no headers — so
`#include <string>` fails while `/usr/include/c++/13` sits there
untouched. `tools/cc/cxx` finds the right install dir and says so with
`--gcc-install-dir`.

`CICILI_CC=gcc CICILI_CXX=g++ sh modules/math/build.sh` goes back to gcc.
Nothing is load-bearing on clang; what is load-bearing is that all of it
agrees.

### No `use_module` for a tier-1 library

cocolog registers sixteen libraries before the first goal runs — `lists`,
`apply`, `builtins`, `dcg`, `files`, `library` and `zigurat` compiled into
the binary, and `assoc`, `pairs`, `ordsets`, `yall`, `aggregate`,
`ugraphs`, `dcg_basics` and `dcg_high_order` read from `lib/swipl` beside
it. **Asking for one is a directive that does nothing** and reads like a
dependency that is not there.

Twenty-four such lines were written here out of habit for another Prolog
— 23 `use_module(library(lists))` across `library/`, `contracts/`, the
nodes and `bench/`, and one `library(zigurat)` in `bench/tps.sh` — and
are gone. What The Coco DOES import is its own tier-2 libraries (`poa`,
`contract`, `hub`, `bft`, `pos`, `poh`, `settle`, `tickmath`, `bytes`,
`spine`, `keccak`) and cocolog's loadable modules (`torch`), every one of
which genuinely has to be found on the library path.

The list is checkable rather than memorable — copy the cocolog binary
somewhere with no `library/` beside it, point `COCOLOG_LIBRARY` at
nothing, and see which names still load. cocolog's own CLAUDE.md has the
two lines.

## The hazards, inherited

cocolog's CLAUDE.md hazards all apply here, because the same store and
server sit underneath: **a slow suite is the store ageing** (restart from
a fresh `$ZIGURATIP_HOME/data` when numbers stop making sense; the
vacuum is the in-place answer); **`red: 0` does not mean the suite
passed** (wire cases SKIP without a server — run `pgrep ziguratip`
before believing a green run, and read the per-case lines); **rebuild
the Parsi objects after ANY ZiguratIP engine change** (`make schema` in
cocolog, then recompile The Coco's own objects), and **a PAGE and a
PROCEDURE of the same name are ONE compiled object** — check the page
names before naming a procedure.

Two disciplines proven in blood over there and law over here: **long
compute never sits inside a database turn** (the server's idle timeout
takes the connection; cocolog now fails loudly, but the loss of the
turn is still yours), and **anything big travels as chunked rows**,
because a row must fit in a page.

## Before saying something works

Every rung of the README's ladder is an arrangement with a `run.sh`
that ends in a GREEN line, run with a server up, and checked line by
line — and anything that writes wants proving **across processes**: one
invocation writing, a second that consulted nothing reading it back.
Nothing is checked in before its GREEN line, and no sentence claims a
number that has not been printed.
