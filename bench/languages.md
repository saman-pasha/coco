# Python, Prolog, cocolog — one comparison, written down

This file is in `bench/` because a language comparison is a benchmark of
a different kind, and it obeys the same rule as the harness beside it:
**no sentence claims a number that has not been printed.** Where a
number below is ours it comes from a table in this repository or in
cocolog's, with the arrangement beside it. Where the fact is Python's or
SWI-Prolog's, it is stated qualitatively and checkably — what the system
is documented to do — rather than as a measurement nobody here ran.

The comparison is honest in both directions, which means it says where
cocolog loses, and it loses often. A document that had cocolog winning
every row would be `mallory.pl` in prose.

**The three, in one sentence each:**

* **Python** is the world's glue language and the default language of
  machine learning: an enormous ecosystem around a slow interpreter,
  where the intelligence lives in C/C++/CUDA libraries and Python
  arranges them.
* **Prolog** (SWI-Prolog as the reference implementation) is logic
  programming grown up: forty years of engineering on unification,
  backtracking and clause resolution, with a mature runtime — garbage
  collection, real threads, tabling, constraints — and a small
  community.
* **cocolog** is a Prolog whose knowledge base is a transactional
  database: a conformant subset of SWI's language, one C binary, where a
  clause is a row other processes can read, a computation can be frozen
  into rows and resumed by another process, and every builtin is
  deterministic by design.

They are not three answers to one question. Python and Prolog are
general-purpose languages; cocolog is a general-purpose Prolog **plus a
position** — that programs, data, and suspended computations belong in
one shared transactional store. Most rows below compare languages; the
rows where cocolog is genuinely different compare positions.

---

## The table

| aspect | Python | SWI-Prolog | cocolog |
|---|---|---|---|
| paradigm | imperative, OO, some functional | logic (Horn clauses + extras) | logic, SWI's dialect |
| program is | objects and bytecode | clauses in one process | clauses that are ROWS in a store |
| typing | dynamic, strong; gradual hints | dynamic, terms | dynamic, terms |
| syntax size | large and familiar: keywords, statements, decorators, comprehensions | one grammar rule — everything is a term; operators are data (`op/3`) | the same, held to SWI |
| ease of entry | the easiest mainstream language; that is WHY it is the default | famously steep: the cost is in semantics, not syntax | Prolog's curve, inherited |
| in-domain code size | logic lives in libraries; glue stays short | rules ARE the program | measured below: all of PoA in 39 lines |
| strings | first-class, unicode | strings, atoms and codes | codes only — `"hi"` IS `[104,105]` |
| memory | refcount + cycle GC | precise GC on all stacks | trail-bounded; NO GC inside a solution |
| indexing | dict/hash everywhere | JIT multi-argument clause indexing | none — clauses tried in order |
| tabling / memoing | `functools.cache` | full tabling with answer subsumption | none |
| constraints | external solvers | CLP(FD), CLP(B), CHR | none |
| concurrency | GIL history; threads, asyncio, multiprocessing | real OS threads, message queues | share-nothing threads (copy the term) + PROCESSES over one store |
| parallel across machines | external (celery, ray, …) | external | native: the knowledge base is the coordination |
| persistence | external (files, DB drivers, ORMs) | external (`library(persistency)`, ODBC) | THE DEFAULT: assertz is a committed row |
| transactions | the database's, through a driver | the database's, through a driver | the language's: one turn is one transaction |
| suspend/resume a computation | pickle objects, not stacks | engines, in-process | freeze/thaw to ROWS; another process finishes the proof |
| determinism | not a goal | not a goal; builtins leave choice points | every builtin deterministic, by design |
| metering | none built in | inference limits via call_with_inference_limit | `max_steps` in the machine struct — gas |
| ML / tensors | the ecosystem: PyTorch, JAX, … | thin bindings | libtorch in-process (`library(torch)`); tensors as rows |
| web server | WSGI/ASGI frameworks | `library(http)` | `library(httpd)`: pages are clauses; HTTPS |
| TLS story | `ssl` stdlib | `library(ssl)` | four named transports + `library(tls)`; mutual auth carries permissions |
| C extension | C API, ctypes, cffi | foreign interface | modules written in Cicili against an SDK |
| deployment | interpreter + venv + wheels | runtime + saved states | ONE static-leaning binary, four arrangements |
| ecosystem | overwhelming | small, mature | this family of repositories |
| implementations | CPython, PyPy, more | one that matters | one, young |
| spec / conformance | the CPython behaviour | ISO + SWI extensions | held to SWI byte for byte, where it ships |

The rest of this file is the prose those rows compress.

---

## The everyday row: ease, syntax, and how much code a thought costs

Most of what decides a language choice is none of the architecture
below. It is the everyday questions: how hard is it to learn, how much
must be typed to say a thing, how does a page of it read, how big is the
program at the end. This section takes those questions at face value,
and it is where the comparison's honesty rule earns its keep, because
"less code" is exactly the kind of claim that is usually an adjective.
Here it is a measurement.

**Ease of entry: Python, outright.** That is not a concession, it is the
explanation of the last fifteen years — Python is the default language
of everything because a working programmer is productive in it in a
day, and a non-programmer in a week. Prolog's entry is famously steep,
and the steepness is honestly located: NOT in the syntax, which is
smaller than any mainstream language's, but in the semantics —
backtracking, unification, and the cut. A Prolog program's control flow
is invisible in its text, and that is the single hardest thing about it.
cocolog inherits the curve exactly, softens it with sixty-four runnable
tutorials whose claims fail the build when they rot, and adds hazards of
its own the newcomer must learn (codes for strings, deterministic
builtins where SWI would backtrack).

**Syntax size: Prolog's grammar is one rule.** Everything is a term;
even `:-` and `,` are operators, and operators are DATA (`op/3`), so
the whole language a reader must hold is: functors, arguments,
operators. There are no keywords, no statements, no
statement/expression split. Python's syntax is far larger than its
reputation — some thirty-five keywords, decorators, comprehensions,
generators, context managers, pattern matching, f-strings, async —
each one earning its place, and each one a thing to know. But small
syntax is not the same as easy, and the honest sentence is: Python has
more syntax and less semantic surprise; Prolog has almost no syntax and
one enormous semantic idea you must actually understand.

**Less code, measured.** These are `grep -cvE '^\s*%|^\s*$'` over this
repository, printed the way the harness prints a rate:

| what | file | total lines | CODE lines |
|---|---|---:|---:|
| proof of authority, whole | `library/poa.pl` | 140 | **39** |
| proof of stake, whole | `library/pos.pl` | 121 | **42** |
| proof of history layer, whole | `library/poh.pl` | 88 | **23** |
| BFT votes, quorums, evidence | `library/bft.pl` | 158 | **56** |
| **four consensus libraries** | | 507 | **160** |
| the CA policy layer | cocolog `library/ca.pl` | 170 | **61** |
| the HTTP/HTTPS transport seam | cocolog `library(httpd)` | | **11 clauses** |

The entire proof-of-authority consensus — block validity, sealing, the
round-robin schedule, fork choice — is thirty-nine lines of code, and
they are the same thirty-nine lines the auditor loads and the attacker
is refused by. The other number in that table matters as much: poa.pl is
140 lines of which **101 are prose**. The code is outnumbered by its own
explanation nearly three to one, which is what "less code" actually
buys — not typing saved, but room for every rule to carry its why.

Two honest caveats on that table. First, nobody wrote the Python
equivalent, so there is no second column to print, and this file does
not invent one; what can be said checkably is that a Python PoA needs
the same rules PLUS a storage layer, a serialisation and a schema,
which are precisely the layers cocolog's position deletes — the
biggest "less code" is the code that does not exist. Second, brevity
cuts both ways: those 39 lines are dense, and a reader who does not yet
think in clauses reads them slower than 200 lines of Python.

**Good view: a clause reads as the spec.** The fork-choice rule IS its
own documentation — `better_head/2` is five clauses that read as the
five sentences of the rule, and the grant-checking core of the CA is:

```prolog
ca_may(Subject, Action) :-
    ca_grants(Subject, Grant),
    ca_covers(Grant, Action),
    !.
```

which is the sentence "a subject may do what some grant of theirs
covers", executable. When the program is the rule, review is reading,
and an auditor loads the rules themselves rather than trusting a
paraphrase — the aggregator rung is built on exactly that property.
The honest counterpart: what reads beautifully at the clause level can
be opaque at the flow level. A cut changes a predicate's meaning while
changing one character of its text; Python's explicit `if`/`return`
flow is far easier to trace for anyone not fluent. Prolog is a
better language to READ RULES in; Python is a better language to READ
EXECUTION in.

**Applicability is where the adjectives usually cheat.** Python is
applicable to everything shallowly — that is its genius. Prolog is
applicable deeply where the problem is made of rules, relations and
search, and MISAPPLIED where it is not: string munging, numeric loops
and pixel pushing in Prolog are more code than Python, not less, and
anyone comparing languages on their home ground alone is running
`mallory.pl`'s eighth attack on themselves. This family's own division
of labour says it plainly: the torch tutorials TRAIN in what is
effectively Python's shape (tensors, epochs) through a module, and
SETTLE in clauses — each language kept where it is short.

**Complexity, over a program's life.** Python is simple on day one and
accumulates complexity in program state — the objects, their mutations,
the invariants held in comments. Prolog is complex on day one and then
programs STAY small, because new knowledge is new clauses rather than
new control flow. Which curve is right depends on how long the program
will live and how often its rules change — and a consensus whose rules
are data that hot-loads (every node invocation here loads its own
rules, so upgrading the consensus rewrites no chain) is the case where
the second curve wins by construction.

---

## Paradigm, and what a program IS

Python's unit of meaning is the object; a program is a graph of them,
mutated over time, and the program text is instructions for building and
mutating that graph. Prolog's unit is the clause; a program is a theory,
and running it is asking whether something follows. That difference is
real and forty years of literature explain it; nothing here needs to.

What cocolog adds is not a paradigm but a **location**. In SWI-Prolog a
clause lives in the process: `assertz/1` changes what this process
believes, and when the process exits the belief goes with it. In cocolog
a clause is a row in a ZiguratIP knowledge base — `assertz` commits, a
second interpreter that consulted nothing reads the clause back, and the
suite proves exactly that, across processes, in nearly every case it
runs. Python has no counterpart sentence: "the program is data another
program can query" requires an ORM, a schema and a serialisation
decision, and each of those is a project.

The cost of the position is stated as plainly as the benefit: a language
whose asserts are commits pays for them like commits. cocolog's own
harness prints seal lanes at **7.96/s per-turn against 18.38/s batched**
(30 blocks, one server, one container — the arrangement is on the line),
which is the price of durability being the default rather than a layer.

## Typing, syntax, strings

All three are dynamically typed; none of the three will catch a type
error before it happens. Python's gradual typing (`mypy`, annotations)
is the most developed answer and a real advantage at scale — a large
Python codebase can buy back much of what static languages have.
Prolog's answer is `must_be/2` and discipline; cocolog ships `must_be/2`
and the same discipline.

Strings are the honest row where cocolog is weakest. Python's `str` is a
first-class unicode type with thirty years of method surface.
SWI-Prolog has strings, atoms and code lists, with flags to choose.
cocolog has **no string type at all**: `double_quotes` is `codes`, so
`"hi"` IS `[104,105]`, and every library that touches text — json, xml,
html, the crypto modules' hex — is written around that. It is the ISO
default and it composes beautifully with DCGs, but nobody should
pretend it is ergonomic for string-heavy work.

## Execution model and performance

CPython interprets bytecode; the famous numbers live in the C libraries
underneath it, and idiomatic Python performance engineering is the art
of never actually running Python. SWI-Prolog compiles clauses to a VM
with just-in-time multi-argument indexing, so a predicate with ten
thousand clauses dispatches like a hash lookup. cocolog is a
continuation-passing engine in C with **no clause indexing** — clauses
are tried in order — and its suite pins complexity rather than speed:
100 000 solutions from `between/3`, ten times the work in far less than
a hundred times the time, and a 500 000-deep deterministic recursion,
with the answers checked, because a representation change that made
everything fast and one thing wrong would pass every timing check.

The numbers this family HAS printed, with their arrangements: cocolog's
local verify lane at **537/s** and validate at **530/s** (2000 blocks,
4-core container, everything -O3, no database), and the server lanes
above.

**And the sentence this file refused to write is now written, because a
harness printed it.** `bench/langs.sh` runs five small programs in both
languages -- naive reverse, all-solutions 8-queens, a tight counting
loop, a keyed lookup, a generate-and-sort -- checks that every lane
answers the same value, and times them at two sizes so a fixed cost can
be told from a per-unit one. `bench/README.md` has the tables and the
runs. The short of it, in memory, nothing kept, against CPython 3.11:

| task | cocolog vs CPython |
|---|---:|
| naive reverse of a 400-list | **7-11x** slower |
| 8-queens, all 92 solutions | **13-15x** slower |
| generate and sort 5000 ints | **11-14x** slower |
| a hundred thousand additions | **35-62x** slower |
| a thousand keyed lookups, 200 facts | **80-83x** slower |

So: **cocolog is slow, by between one and two orders of magnitude, and
the spread is the interesting part.** Search -- the thing a Prolog engine
is for -- is its best showing. A counting loop is its worst, which is the
per-inference cost of a continuation-passing interpreter with no
compilation step. Start-up is NOT the reason and the guess that it was
is dead: every arrangement boots in **0.01s**, the same as Python.

**THE KEYED LOOKUP IS NOT A FACTOR, IT IS A SLOPE**, and it is this
file's own "no clause indexing" sentence with numbers on it. The same
thousand probes over a growing database:

| facts | CPython | cocolog | ratio |
|---:|---:|---:|---:|
| 200 | 0.02s | 0.13s | 7x |
| 2 000 | 0.02s | 0.82s | 49x |
| 20 000 | 0.02s | 7.95s | **411x** |

Python's dict is flat; cocolog walks the clauses. First-argument
indexing is the one change that would move this, and it is cocolog's to
make.

**BUT PYTHON IS A LANGUAGE AND COCOLOG IS A LANGUAGE AND A STATE
MACHINE**, and the table above compares only the half they share. A dict
is memory: not durable, not transactional, invisible to every other
process, gone at exit. cocolog's `--embed` and server arrangements are a
database. Timing those against a dict measures the guarantees rather
than the engine, so the harness pairs them with the nearest thing Python
already has -- `sqlite3`, a file, an index, one committed transaction --
and that lane is itself **60x** slower than the dict. Durability is not
free in either language; it is simply usually invisible in Python
because nobody asks a dict for it.

What the same measurement says about the store, and it is the most
useful line here: **reading costs a constant, writing costs a fortune.**
On every compute task the embedded store and the in-memory arrangement
are within a few percent of each other -- 6.5 against 6.9, 14.7 against
14.5, 32.6 against 34.6 -- so the database does not slow the *thinking*
down at all. But asserting 200 facts and probing them cost **17.2
seconds** embedded, and over the server the same work did not finish
inside a five-minute cap and the harness refused to print a number for
it. Assert-heavy loops do not belong inside a turn, which this family
already knew as a discipline and can now say as a measurement.

And the third column has no counterpart to compare at all: a suspended
machine any process can finish, a clause that IS a row another program
queries, a turn that is the store's transaction. Those are not faster or
slower than Python. They are absent from it, and a speed table has no
way to say so.

## Then cocolog fixed both of them

**EVERY PARAGRAPH ABOVE THIS ONE IS RUN B, AND TWO OF ITS READINGS WERE
DEFECTS RATHER THAN A SLOW INTERPRETER.** The benchmark said so, in the two
sentences it was written to be able to say -- "the keyed lookup is a slope,
not a factor" and "writing costs a fortune" -- and both were diagnosed in
cocolog and fixed THERE, on their own merits, behind that repository's own
gate: 39 of 39 GREEN, `red: 0`, no SKIPs, on a fresh store. The Coco
modified nothing. It measured, and the pillar answered.

* **The turn's writes are batched now.** Writing a clause through re-sends
  the whole predicate, and the batching that made a CONSULT cheap was
  switched off before the goal ran -- so `assertz` in a loop paid a
  forget-and-resend per clause. 200 cost 16.9s and 400 cost 85.4s, roughly
  N^2.4; they cost 0.050s and 0.088s now.
* **Clauses are indexed on their first argument.** A call used to COPY each
  clause onto the heap and unify its head, so a probe into a table of facts
  copied the table.

The keyed lookup, in the four columns -- a thousand probes over 200 facts,
per sweep:

| | cocolog --local | CPython | cocolog --embed | CPython + sqlite3 |
|---|---|---|---|---|
| what it is | in memory, no database | dict, in memory | MVCCS in-process | file, indexed, one commit |
| **before** | 0.005979s (79.7x) | 0.000075s | one rep, **17.18s wall** | 0.004530s (60.4x) |
| **after** | 0.003614s (47.6x) | 0.000076s | **0.002291s (30.1x)** | 0.004432s (58.3x) |

And the slope this file named, re-measured on `--local`, where no store is
involved at all:

| facts | CPython | cocolog before | cocolog after | ratio before | ratio after |
|---:|---:|---:|---:|---:|---:|
| 200 | 0.02s | 0.13s | 0.06s | 7x | **3x** |
| 2 000 | 0.02s | 0.82s | 0.06s | 49x | **3x** |
| 20 000 | 0.02s | 7.95s | 0.09s | 411x | **4x** |

**The slope is gone.** "First-argument indexing is the one change that would
move this, and it is cocolog's to make" -- it was made, and this is the
line that says so.

The rest of the tasks, the same four columns, after (only `lookup` has a
durable-Python counterpart written, so the fourth column is empty by
construction):

| task (one rep) | cocolog --local | CPython | cocolog --embed | CPython + sqlite3 |
|---|---|---|---|---|
| nrev, 400-element list | ~0.0387s (5.9x) † | 0.006611s | 0.035925s (5.4x) | -- |
| queens, all 92 solutions | 0.025366s (14.3x) | 0.001772s | 0.024442s (13.8x) | -- |
| loop, 100 000 additions | 0.106376s (33.9x) | 0.003141s | 0.124958s (39.8x) | -- |
| lookup, 1000 probes / 200 facts | 0.003614s (47.6x) | 0.000076s | 0.002291s (30.1x) | 0.004432s (58.3x) |
| sortnums, 5000 integers | 0.012735s (9.1x) | 0.001392s | 0.012850s (9.2x) | -- |

**WHAT DID NOT CHANGE IS THE SENTENCE THIS FILE EXISTS FOR.** cocolog as a
LANGUAGE is still 6-34x CPython on the four compute tasks, because neither
fix touches the per-inference cost of a continuation-passing interpreter
with no compilation step. "Search is its best showing, a counting loop its
worst" still holds, and start-up is still not the reason. What moved was
the database half and the clause walk -- two defects -- and not the engine's
per-step cost, which is a design.

Three things this run does not get to claim, recorded because a benchmark
that reports only what flatters it is not one:

* **† The `nrev --local` row the harness printed is wrong**, and its own
  shape column said so: `2R/R` of 3.36, where 2.0 is linear. Re-measured at
  R=64, three runs: 0.039391, 0.039185, 0.038652 -- about 5.9x, an
  improvement on 6.9x. The R=128 point swung 0.0387-0.0624, which poisoned
  the second measurement. Container noise, not a regression.
* **The server lane is CONFOUNDED and is not in the tables.** It went from
  "one rep, no rate" and a REFUSAL on lookup to real rates, but the server
  was restarted on a FRESH store between the runs while the earlier one
  measured a 76 MB aged store. Some of that is the fix and some is the
  restart; this run cannot separate them. `--embed` is clean, because it
  builds a fresh store per run either way.
* **`--embed` beating `--local` on lookup is not a finding** -- 0.002291
  against 0.003614 with the local row's shape at 2.58 is inside the noise,
  and an in-memory lane cannot really be slower than the same lane with a
  database under it.

Where cocolog deliberately wins is the floor under the numbers: the
whole stack is one toolchain (clang, workspace-wide, checked), so a
measurement is of the code rather than of a mixed build.

## Memory

Python: reference counting plus a cycle collector; leaks are rare and
diagnosable. SWI-Prolog: precise garbage collection on the global stack
and trail; long-running deterministic computations are routine. cocolog:
**no garbage collection.** The heap grows within a solution and is
reclaimed on backtracking and on a new query — elegant, WAM-honest, and
a real limitation the STATUS file lists under "by choice": a long
deterministic run that builds structure grows until it ends. The
mitigation is architectural rather than a collector: work is shaped into
turns, and a turn's heap dies with the turn.

## Concurrency, parallelism, distribution

Python's story is history being repaired: the GIL made threads
concurrency-without-parallelism for thirty years, `asyncio` gave I/O
concurrency a syntax, `multiprocessing` gave parallelism at the price of
serialising everything, and the free-threaded build is only now
dismantling the constraint. SWI-Prolog has had real OS threads with
message queues for two decades — the quiet best-in-class of this row for
in-process parallelism.

cocolog's in-process story is deliberately smaller: share-nothing
threads that copy terms through channels — `test/thread.sh` proves eight
senders through one channel with all 800 terms arriving, and four
threads doing four times the work in 1.7× the time. Its real answer is
**between processes**: the knowledge base is the coordination layer.
Twelve interpreters over four machine states; one writer and eight
readers; a claim-of-one under SERIALIZABLE isolation as leader election
— all proven as crowds of actual processes, and the same arrangement is
what The Coco's federation ledger runs on. Python and SWI need a
message broker or a database to say any of that; cocolog's position is
that the database was already there.

Distribution follows for free, and over TLS since this repository's
`secure` case: the three consensus rungs run with every node-to-store
link encrypted and all seventy-eight verdicts unchanged.

## Persistence and transactions — the deep difference

This is the row the whole comparison exists for.

In Python, persistence is a decision: files, pickle, an ORM, a database
driver — each with a boundary where objects become bytes and invariants
become hope. In SWI-Prolog it is also a decision: `library(persistency)`
journals asserts to a file; ODBC reaches real databases; both are
libraries a program opts into.

In cocolog **there is no boundary to cross**. A clause is a row; a turn
is a transaction; `assertz` then process death loses nothing, and the
suite's favourite shape — one process writes, a second that consulted
nothing reads it back — is the language working as specified, not a
feature demonstration. Isolation is the store's real ladder
(READ_UNCOMMITTED to SERIALIZABLE); a dirty read is a speed lane the
bench measures, not an accident. And freeze/thaw makes a **suspended
computation** a first-class durable thing: a machine stopped mid-proof
becomes rows, its process exits, and any other process — on any other
machine that reaches the store — picks the proof up and finishes it.
Python's nearest neighbour is a workflow engine; Prolog's is engines,
which die with the process.

## Backend work: serving, storage, deployment

As a backend language Python is the incumbent: every framework, every
driver, every deployment target. SWI-Prolog is a working web platform
few people use: `library(http)` has served real sites for decades.

cocolog's server is `library(httpd)`: pages are clauses, a page handler
is a predicate, HTTPS is one option (`tls([...])`) on the same code
path, and a TLS peer's subject and permissions arrive as two synthetic
headers a page reads like any other — with the reverse-proxy hole
(a client SENDING those headers) closed and tested. The four transports
are named — `--tcp`, `--tls`, `--http`, `--https` — and the store's
certificate-borne permission system means "who may append" is decided by
the server against the peer TLS identified, not by application code.

Deployment is where the one-binary decision pays: cocolog is a single
executable whose four arrangements — in-memory, server, HTTP read-only,
embedded store — are runtime flags. A Python service is an interpreter,
a virtualenv, a lockfile and a base image; reproducibility is tooling.
SWI sits between: saved states exist, and so does the runtime they need.

## Extension, metaprogramming, tooling

Python extends in C against a large, stable API, and its metaprogramming
(decorators, metaclasses, descriptors) is powerful and famously easy to
overuse. Prolog is homoiconic — programs are terms — so `assert`,
`clause/2`, term expansion and DCG translation are the metaprogramming,
with nothing bolted on. cocolog inherits that homoiconicity and extends
in **Cicili** (Lisp-syntax C) against a module SDK; the same
`use_module(library(Name))` loads a `.pl` of clauses or a compiled `.so`
and the caller cannot tell which — `library(eth)` composes two of each.

Tooling is not close and this file does not pretend otherwise. Python
has the deepest tooling of any language alive. SWI has a graphical
debugger, a profiler and a package manager. cocolog has a four-port
tracer held to SWI's format port for port, an Emacs mode whose test
runs are checked by the interpreter itself, and a suite; it has no
debugger GUI, no profiler, no package manager.

## Correctness culture

Worth a row because it differs in kind, not just degree. Python's
correctness lives in its test ecosystem — excellent, and opt-in. SWI's
lives in its maturity. cocolog's is structural: the DCG layer and five
libraries are proven against **swipl itself, byte for byte** — 555 lines
of agreement across nineteen cases run by both systems — the
tutorials are executable claims that fail the build when they stop being
true, and the security tests keep attacks that SUCCEED (malleability,
spine forks, draw grinding) in the suite as successes, because a suite
where every attack fails is a rehearsal.

---

## AI-friendliness, in its four separate senses

"AI-friendly" means four different things, and a language can hold any
subset.

**1. Building models.** Python, and it is not close. PyTorch, JAX, the
CUDA ecosystem, every paper's reference implementation. cocolog's
`library(torch)` puts real libtorch in-process — twenty-four tutorial
networks train, test and predict as three separate processes each, GPU
included, with parameters storable as rows in the tensors table — which
makes cocolog unusual among Prologs and still a visitor in Python's
country. SWI's numeric story is thin.

**2. Representing knowledge.** Prolog, by construction: facts, rules and
queries are the language. cocolog keeps all of that and adds the part
classic AI always outsourced — the knowledge base survives the process,
is shared, is transactional, and is itself queryable by other programs.
Python represents knowledge the way it represents everything: in
objects, plus whatever schema you design.

**3. Running agents.** Here the requirements invert: an agent harness
wants execution that is **deterministic, meterable, suspendable and
auditable**, and this is the sense in which cocolog was built
AI-friendly on purpose. Every builtin is deterministic — no builtin
leaves a choice point. `max_steps` is a gas meter in the machine struct,
not a wrapper. A machine freezes mid-proof into rows and any process
resumes it — an agent's pending decision as durable data. And the audit
plane is free: an agent's beliefs are rows a supervisor reads over a
read-only HTTP transport. Python can build all of this and does, as
frameworks; none of it is the language. The Coco's training rung is the
demonstration: train freely in Python-shaped freedom (torch), then
settle deterministically — the acceptance test re-runs the model and the
chain believes the measurement, not the trainer.

**4. Being written BY a model.** Python is what every model writes best;
the training data saw to that. Prolog is rarer in corpora and models
mis-handle backtracking and cuts more often than syntax. cocolog's
mitigation is conformance: it is held to SWI's behaviour byte for byte
where it ships, so a model's SWI-Prolog competence transfers — and the
project's own documentation is machine-checkable (`must/3` tutorials),
so what a model learns from the docs cannot silently rot. Its hazards
for a generating model are the honest ones listed above: codes, no GC,
no indexing, deterministic builtins where SWI would backtrack.

---

## Where each wins

**Choose Python** for model-building, for ecosystem reach, for hiring,
for anything whose hard part somebody already wrote. It is the right
default and the other two know it.

**Choose SWI-Prolog** for in-process symbolic computation at its most
mature: constraints, tabling, big clause bases with real indexing, a GC
that lets a process run for a month.

**cocolog's ground** is the intersection the other two each need two
systems to stand on: logic programs whose state must OUTLIVE and be
SHARED between processes, transactionally, with determinism and
metering guaranteed by the engine rather than promised by the
application — consensus rules as clauses, contracts under gas,
settlement as an acceptance predicate, an agent's suspended proof as
rows. That is not "better than Python" or "better than Prolog"; it is
the position this family of repositories exists to demonstrate, one
GREEN line at a time, and the ladder above this directory is the
demonstration.
