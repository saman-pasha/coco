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

```sh
export CICILI=/home/user/cicili                  # for building the pillars
export ZIGURATIP=/home/user/ZiguratIP            # a BUILT ZiguratIP
export ZIGURATIP_HOME=/home/user/ZiguratIP/home
export COCOLOG=/home/user/cocolog                # a BUILT cocolog checkout
sh test/run.sh                                   # the suite
```

The server, which the wire cases need — start it detached; a plain
`nohup ... &` from a tool call does not survive the turn:

```sh
cd /home/user/ZiguratIP && ZIGURATIP_HOME=$PWD/home \
  LD_LIBRARY_PATH=$PWD/home/lib setsid ./home/bin/ziguratip
```

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
