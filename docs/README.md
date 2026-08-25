# docs

Diagrams and explainers that are worth keeping but are not code.

| file | what |
|---|---|
| `seal-to-settlement.html` | the whole arc, rungs 2&ndash;4: one payload traced from a node's hands to a settled verdict, with every PoA function, gossip hop, fork-choice key and settlement gate in the order it is reached |
| `tick-to-settlement.html` | rung 5: a spine traced from thirty-two zero bytes to a settled verdict, with every PoH function, the choreography invocation by invocation, and the measured sequential/parallel asymmetry |

Open either from a checkout &mdash; they are standalone documents with no build step
and no local assets. The only thing they fetch is the webfont; without a network it
falls back and still reads.

## Keeping it honest

**Every predicate name in it is taken from the source, not from memory.** If a
predicate is renamed, the diagram is wrong and nothing will tell you &mdash;
there is no test that reads an SVG. The names it uses live in:

    library/poa.pl        block_signable/5  block_hash/5  seal/7
                          valid_block/6  in_turn/2  better_head/2
    ledger/node.pl        ledger_seal/1  ledger_sync/1  ledger_head/1
                          chain_from/2  extends_known/2  maybe_advance/2
    library/contract.pl   contract_admit/3  contract_install/2  contract_call/2
    library/settle.pl     settle/4  holdout_matches/3  arch_fits/3  measure/6
    training/worker.pl    train_and_export/1  submit_ready/2  judge/4
                          settle_submissions/0  provenance/1
    modules/.../poh.cicili poh_run/3  poh_mix/3  poh_verify/3
                          poh_checkpoints/4
    library/spine.pl      poh_genesis/1  poh_segments/4  poh_anchor/3
                          poh_verify_segments/1  poh_slow_run/3
    spine/node.pl         spine_produce/2  verify_one/1  spine_sound/0
                          anchor_block/1  anchor_order/1  anchor_genuine/1

## The published copies

Each page is also published as an artifact. That copy is the file here with the
`<!doctype>`, `<html>`, `<head>` and `<body>` wrapper removed &mdash; the artifact
host supplies its own:

```sh
python3 - <<'EOF'
import re
s = open('docs/seal-to-settlement.html').read()   # or tick-to-settlement.html
body = s.split('<head>', 1)[1].replace('</head>', '').replace('<body>', '')
body = body.rsplit('</body>', 1)[0]
body = re.sub(r'<meta[^>]*>\s*', '', body)   # the host sets charset and viewport
open('artifact-body.html', 'w').write(body.strip() + '\n')
EOF
```

That reproduces the artifact source; the only difference is the blank
lines where the wrapper was, which HTML does not care about.

The files here are the source; the artifacts are derived from them. If they ever
disagree, these are right.
