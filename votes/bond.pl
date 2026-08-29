%% votes/bond.pl -- THE STAKE IS THE COIN, and the evidence bites.
%%
%% Consulted beside `ledger/node.pl', `ledger/gas.pl' and, where a node
%% votes, `votes/node.pl'. It is the seam between two rungs that were
%% built apart: rung 6's proof of stake, which asks what a validator
%% weighs, and COCO, which is the only thing here anybody can lose.
%%
%%   stake_entry(?Who, ?Weight)    library(pos)'s table, as a QUERY
%%   bond_weight(+Amount, -Weight) a bond in whole COCO, floored
%%   validator_bond(?Who, -Amount) what one validator has at risk
%%   slash_for_equivocation(+Votes, +Reporter, -Report)
%%   slash_for_certificates(+QC1, +QC2, +Reporter, -Report)
%%   slashed(?Who, ?EvidenceId)    who was punished, and for what
%%   stake_report
%%
%% WHAT CHANGED, AND WHY IT MATTERS. `library(pos)' says the stake table
%% is not its business -- `stake_entry(Who, Amount)' is supplied by
%% whoever loads it -- and rung 6 supplied it by reading NUMBERS off the
%% chain: a block said alice weighs 40, so alice weighed 40. Nothing was
%% at risk, because nothing had been put up. Here the table is a RULE
%% over bonded COCO, so a validator's weight is money it has actually
%% locked, and `library(bft)''s closing sentence -- "a name is what a
%% slashing rule needs" -- finally has something to spend the name on.
%%
%% A VALIDATOR IS A NAMED KEY WITH COIN AT ITS ADDRESS. The name and the
%% key come from the federation (`authority/2', which is also how
%% `valid_vote/1' knows whose signature to check); the money is at the
%% address of that same key, so who does the work and who holds the bond
%% are one key and nobody keeps a second roster.
%% `coco_authority_account/2' is `ledger/gas.pl''s, used rather than
%% copied -- a rule that appears in two files will disagree with itself
%% eventually, and the disagreement is always silent.
%%
%% WEIGHT IS WHOLE COCO, and that is a deliberate loss of precision. The
%% safety arithmetic is integer arithmetic -- `quorum/2' is
%% `(T * 2) // 3 + 1' and `sum_list/2' adds machine integers -- while
%% money here is u256 and must stay u256, because a balance in `is/2'
%% wraps in silence at nineteen COCO. Counting whole coins keeps both
%% halves in the type they need. The consequence is stated rather than
%% hidden: A BOND SMALLER THAN ONE WHOLE COCO WEIGHS NOTHING. It is
%% still yours, and it is still slashable; it simply does not vote.
%%
%% WHAT IS NOT HERE. Nobody is REWARDED for validating -- an emission
%% schedule is monetary policy and this rung takes no position on it, the
%% way rung 4 took none on paying a trainer. There is no delegation: a
%% bond votes for the key that made it, and a third party's stake behind
%% a validator needs a rule about who bears the loss, which is a design
%% question and not a missing line. And a slash here is TOTAL -- the
%% whole bond, not a percentage of it -- because a partial slash is a
%% number somebody has to justify and this rung has no basis to pick one.

:- use_module(library(pos)).
:- use_module(library(bft)).
:- use_module(library(poa)).
:- use_module(library(coco)).
:- use_module(library(sha256)).
:- use_module(library(u256)).

:- dynamic slashed/2.           % slashed(Who, EvidenceId)
:- dynamic slashed_evidence/1.  % the evidence already paid for

%% ---- the table, as a query -------------------------------------------
%%
%% `stake_entry/2' is declared dynamic by `library(pos)' and rung 6
%% asserts facts for it. This is a CLAUSE for the same predicate, which
%% is the whole trick: a node that loads this file answers the same
%% question from bonded coin, and `stake_of/2', `total_stake/1',
%% `quorum/2' and the leader draw go on working with nothing to change.
%% (Do not load this file and rung 6's `stake_from_chain/0' into one
%% knowledge base expecting one answer: they are two sources for one
%% table and the weights would add.)
%%
%% WEIGHT IS MONEY AT RISK, NOT MONEY BONDED, and that is not a detail --
%% it is what closes an escape hatch that reading `library(bft)' turned
%% up. `valid_vote/1' opens with `has_stake(Who)': a validator with no
%% stake cannot cast a vote that anybody will look at, and
%% `equivocation/3' validates both votes before it names anybody. So if
%% weight dropped the moment a validator ASKED for its money back, the
%% attack would be two lines long -- equivocate, unbond in the same
%% breath, and the evidence against you stops being readable while your
%% money is still sitting there waiting to mature.
%%
%% Tying the weight to `coco_at_risk/2' -- the bond plus every unbonding
%% still in flight -- closes it by construction, and the rule it leaves
%% is the simpler one to say out loud: YOU WEIGH WHAT YOU CAN LOSE. A
%% validator on its way out still votes, and still has everything to lose
%% if it votes twice; the weight goes to zero at exactly the moment the
%% money stops being takeable, which is when it lands back in a balance.
stake_entry(Who, Weight) :-
    coco_authority_account(Who, Addr),
    coco_at_risk(Addr, Amount),
    bond_weight(Amount, Weight),
    Weight > 0.

bond_weight(Amount, Weight) :-
    coco_unit(U),
    u256_div(Amount, U, Whole),
    u256_int(Whole, Weight).

%% The same money the weight is computed from, in the type money is
%% written in -- for a report, or for anyone who wants the exact figure
%% rather than the coins it rounds to.
validator_bond(Who, Amount) :-
    coco_authority_account(Who, Addr),
    coco_at_risk(Addr, Amount).

%% ---- the slash -------------------------------------------------------
%%
%% THE POLICY IS HERE AND THE MONEY IS NOT. `library(coco)' knows how to
%% take a bond and refuses to know what deserves taking; this file weighs
%% evidence and refuses to touch a balance. Between them the rule is:
%% two signed votes that cannot both be honest, and the bond behind the
%% key that signed them is gone.
%%
%% EVIDENCE IS PAID FOR ONCE. The id is the hash of the evidence term
%% itself, so the same two votes cannot be reported twice -- by the same
%% reporter or by two -- while a validator that re-bonds and equivocates
%% AGAIN is new evidence and is slashed again. Keying on the culprit
%% instead would have made the second offence free.

%% Two votes of one kind, at one height and round, for different blocks,
%% both carrying that validator's own signature. `equivocation/3' checks
%% the signatures; nothing here takes anybody's word for what was said.
%%
%% THE VOTES ARE FILTERED BEFORE THEY ARE WEIGHED, and the reason is the
%% same one `library(coco)' states over its own two gates: evidence is
%% bytes a stranger chose, and `secp256k1_verify/3' RAISES on a malformed
%% signature rather than failing. Handing `equivocation/3' a list with
%% one piece of rubbish in it would end the turn of whichever node was
%% asked to look -- so each vote is verified under a `catch/3' first, and
%% what survives is a list every check downstream can trust. Rubbish is
%% not evidence; it is also not an emergency.
slash_for_equivocation(Votes0, Reporter, slashed(Who, Taken, Reward)) :-
    sound_votes(Votes0, Votes),
    equivocation(Votes, Who, Ev),
    evidence_id(Ev, Id),
    \+ slashed_evidence(Id),
    coco_authority_account(Who, Addr),
    Addr \== Reporter,
    coco_slash(Addr, Reporter, Taken, Reward),
    ( assertz(slashed(Who, Id)),
      assertz(slashed_evidence(Id)) ).

%% Two quorum certificates for different blocks at one height. By the 2/3
%% arithmetic the validators in both cannot be an empty set, and their
%% stake is strictly more than the fault bound -- so this does not merely
%% observe a disagreement, it NAMES the keys that signed both sides. Each
%% culprit is slashed under the same evidence id, so the pair of
%% certificates is one report however many names it carries.
%%
%% BOTH CERTIFICATES ARE VALIDATED FIRST, and leaving that out would have
%% been a hole big enough to rob anybody through: `culprits/3' intersects
%% two lists of voter NAMES and takes no position on whether either
%% certificate is real, so a stranger could hand a node two fabrications
%% naming whoever they liked. `qc_valid/1' is the check -- every vote's
%% signature, every vote matching the certificate it is in, and a quorum
%% of the stake behind each -- and it runs before a name is read.
slash_for_certificates(QC1, QC2, Reporter, report(Names, Taken, Reward)) :-
    sound_qc(QC1),
    sound_qc(QC2),
    culprits(QC1, QC2, Names),
    Names \== [],
    evidence_id(certificates(QC1, QC2), Id),
    \+ slashed_evidence(Id),
    slash_each(Names, Reporter, Id, '0', Taken, '0', Reward),
    assertz(slashed_evidence(Id)).

slash_each([], _, _, T, T, R, R).
slash_each([Who|Rest], Reporter, Id, T0, Taken, R0, Reward) :-
    (   coco_authority_account(Who, Addr),
        Addr \== Reporter,
        coco_slash(Addr, Reporter, T, R)
    ->  u256_add(T0, T, T1),
        u256_add(R0, R, R1),
        assertz(slashed(Who, Id))
    ;   T1 = T0, R1 = R0        % nothing at risk: named, and nothing to take
    ),
    slash_each(Rest, Reporter, Id, T1, Taken, R1, Reward).

%% The two total gates. A vote or a certificate that raises is not
%% evidence and is not an emergency either: it fails, and the node's turn
%% survives the stranger who sent it.
%%
%% THE CATCH HAS TO BE INSIDE THE `findall/3', and that cost a debugging
%% round. `catch(qc_valid(QC), _, fail)' does NOT hold: `qc_valid/1'
%% checks its votes with `forall/2', `forall/2' is built on `findall/3',
%% and cocolog's `findall/3' lets an uncaught throw end the query with a
%% message no `catch/3' sees -- which cocolog's own MODULES.md says
%% outright, and which is the one place a fence made of `catch/3' leaks.
%% So each vote is verified on its own, under its own catch, and what
%% reaches `qc_valid/1' cannot raise inside anybody's `forall'.
sound_votes(Votes, Good) :-
    is_list(Votes),
    findall(V, ( member(V, Votes), catch(valid_vote(V), _, fail) ), Good).

%% A certificate is sound when EVERY vote in it verifies -- `sound_votes'
%% answering the same list back is that sentence -- and the counting rule
%% then holds over votes that are already known good.
sound_qc(qc(K, H, R, B, Votes)) :-
    Votes \== [],
    sound_votes(Votes, Votes),
    qc_valid(qc(K, H, R, B, Votes)).

%% THE ID IS THE HASH OF THE EVIDENCE, canonically written -- so two
%% nodes holding the same two votes compute the same id without talking,
%% which is the same property every other identifier here has.
evidence_id(Ev, Id) :-
    term_to_atom(Ev, Text),
    sha256(Text, Id).

%% ---- reporting -------------------------------------------------------

stake_report :-
    stake_table(Pairs),
    total_stake(T),
    quorum(T, Q),
    format("stake ~w total ~w quorum ~w~n", [Pairs, T, Q]).
