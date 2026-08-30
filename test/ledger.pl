%% Rung 2: the PoA federation ledger, and mallory attacking it.
%%
%% WHAT IT IS CHECKING, in three parts.
%%
%%   THE CHAIN WORKS. Three authorities on three knowledge bases seal in
%%   turn, gossip, and every one of them ends on the same head with a
%%   clean audit -- where an audit means every hash recomputed, every
%%   signature re-checked and every parent link walked back to genesis,
%%   by a process that was told nothing.
%%
%%   THE FORK CLOSES BY RULE. Two authorities seal at the same height
%%   while neither has heard the other, which is what a partition looks
%%   like from inside. Both chains are valid and the same length. Every
%%   node must land on the same one, and must land on it because the rule
%%   prefers the in-turn block -- not because of arrival order, which is
%%   exactly what differs between them.
%%
%%   MALLORY GETS NOTHING. Seven attacks on the five laws the chain has,
%%   each refused, plus one that SUCCEEDS and is supposed to. A test
%%   suite that reported every attack refused would be lying, and the one
%%   that gets through is the one worth understanding: ECDSA signatures
%%   are malleable by anyone, so she can produce a different signature for
%%   alice's block -- and it buys her nothing, because the block's hash
%%   does not cover the signature. Bitcoin's did, and that was
%%   transaction malleability.
%%
%%   AND ONE ATTACK COMES FROM INSIDE. A member of the federation can seal
%%   a valid block that rewrites history, and nothing refuses it -- it is
%%   properly signed by a real authority. It is not REFUSED, it is
%%   OUTWEIGHED, and the distinction is the whole difference between
%%   validity and consensus.
%%
%% WHICH HALF SPAWNS, AND WHY. The attacks are about the RULES, and the
%% rules are clauses: each is one isolated proof in this process, which
%% is what the .sh was paying a whole cocolog per attack to get. The
%% chain is about THREE NODES -- three knowledge bases, and gossip is one
%% process reading another's export -- so that half still starts real
%% processes, and SKIPs without a Zigurat server. run_isolated/2 cannot
%% make a claim about two processes, and using it here would keep the
%% suite green while deleting the proof.
%%
%% Run:  cocolog -s test/ledger.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

ledger_program :-
    use_module(library(poa)),
    use_module('ledger/federation.pl'),
    use_module('ledger/node.pl'),
    use_module('ledger/mallory.pl').

carol_key('3333333333333333333333333333333333333333333333333333333333333333').

%% ---- part one: mallory, in this process ---------------------------------
%%
%% No server, and no spawning either: an attack the chain refuses is an
%% attack `valid_block/6' refuses, and one isolated proof per attack makes
%% that plain -- the verdict is the goal's own binding rather than a word
%% grepped out of a process's output.

attack(A, L, Want) :-
    iso(L, ( ledger_program, G =.. [A, V], call(G), want(V, Want) )).

mallory_half :-
    section('mallory attacks the laws'),
    attack(attack_not_a_member,     'not a member of the federation',      refused),
    attack(attack_impersonate,      "alice's name, mallory's key",         refused),
    attack(attack_tamper,           "a sealed block's payload changed",    refused),
    attack(attack_forged_hash,      'a hash the block does not have',      refused),
    attack(attack_replay_signature, 'a real signature on another block',   refused),
    attack(attack_wrong_parent,     'a real block re-pointed at a parent', refused),
    attack(attack_orphan,           'a block whose parent is missing',     refused),
    %% The one that works, and the reason it does not matter.
    %% ...and it says so in the LABEL, not only in the value: test/secure.pl
    %% counts the deliberate successes across the three consensus rungs by
    %% that marker, to require that TLS did not turn one of them into a
    %% refusal. spine and votes already spelled it this way.
    attack(attack_malleate, 'the malleated twin verifies -- SUCCEEDS, and must',
           'ACCEPTED'),
    iso('and is the same block, so it gains nothing',
        ( ledger_program,
          honest_block(block(H, Pv, A, P, Sg, Hs)),
          malleate(Sg, _),
          block_hash(H, Pv, A, P, H2),
          want(H2, Hs) )),
    iso('the rewritten block is VALID (a member signed it)',
        ( ledger_program, carol_key(K), genesis_prev(G),
          seal(K, 0, G, carol, 'a history I prefer', S, H),
          ( valid_block(0, G, carol, 'a history I prefer', S, H)
            -> V = valid ; V = refused ),
          want(V, valid) )).

%% ---- the three nodes, as three knowledge bases --------------------------

kb_of(Who, KB) :- atom_concat(ledger_, Who, KB).

%% every goal a node runs loads library(poa) first, exactly as the .sh's
%% node() did -- federation.pl and node.pl are already IN the base
node_goal(G0, G) :-
    ( is_list(G0) -> sh_join(G0, G1) ; G1 = G0 ),
    sh_join(['use_module(library(poa)), ', G1], G).

node_do(Who, G0) :-
    kb_of(Who, KB), node_goal(G0, G),
    ( wire_as(Who, KB, G, '.', _) -> true ; true ).

node_ans(Who, G0, Pattern, A) :-
    kb_of(Who, KB), node_goal(G0, G),
    ( wire_as(Who, KB, G, Pattern, A0) -> A = A0 ; A = none ).

%% ONE HEAD, AS TEXT: height and hash, so two nodes' answers compare as
%% one atom. `write/1' rather than format/2 because a format string is
%% double-quoted and this goal travels through a double-quoted shell word.
head_of(Who, H) :-
    node_ans(Who, 'ledger_head(head(Ht,Hs,_)), write(Ht), write('' ''), write(Hs), nl',
             '^[0-9-]+ [0-9a-f]{64}$', H).

audit_of(Who, S) :-
    node_ans(Who, 'ledger_audit(S), write(S), nl', '^(ok|broken)$', S).

%% GOSSIP IS ONE PROCESS READING ANOTHER'S EXPORT -- the peer's blocks,
%% as terms, offered to this node's ledger_sync/1, which re-verifies every
%% one of them before it keeps it.
blocks_of(Who, L) :-
    kb_of(Who, KB), node_goal(ledger_export, G),
    (   as(Who, wire_lines(KB, G, '^block\\(.*\\)\\.$', Ls))
    ->  true ;  Ls = [] ),
    findall(B, ( member(Cs, Ls), atom_codes(A, Cs), strip_dot(A, B) ), Bs),
    join_comma(Bs, L).

strip_dot(A, B) :-
    atom_length(A, N), N1 is N - 1,
    ( sub_atom(A, N1, 1, 0, '.') -> sub_atom(A, 0, N1, 1, B) ; B = A ).

join_comma([], '').
join_comma([X], X) :- !.
join_comma([X|Xs], J) :- join_comma(Xs, R), sh_join([X, ',', R], J).

gossip(Me) :-
    forall(( member(Peer, [alice, bob, carol]), Peer \== Me ),
           ( blocks_of(Peer, L),
             ( L == '' -> true ; node_do(Me, ['ledger_sync([', L, '])']) ) )).

gossip_round :- forall(member(W, [alice, bob, carol]), gossip(W)).

all_audit(L) :-
    forall(member(W, [alice, bob, carol]),
           ( atom_concat(W, L, Lb),
             iso(Lb, ( audit_of(W, S), want(S, ok) )) )).

%% ---- the chain half -----------------------------------------------------

chain_half :-
    forall(member(W, [alice, bob, carol]),
           ( kb_of(W, KB), wire_forget(KB),
             wire_consult(KB, 'ledger/federation.pl'),
             wire_consult(KB, 'ledger/node.pl') )),

    section('three authorities, sealing in turn'),
    node_do(alice, 'ledger_seal(''the genesis of the federation'')'),
    gossip_round,
    node_do(bob,   'ledger_seal(''the second'')'),
    gossip_round,
    node_do(carol, 'ledger_seal(''the third'')'),
    gossip_round,

    head_of(alice, A), head_of(bob, B), head_of(carol, D),
    iso('alice, bob and carol agree on the head',
        ( want(A-B, B-D) )),
    iso('and the head is at height 2',
        ( sub_atom(A, Bf, 1, _, ' '), !, sub_atom(A, 0, Bf, _, Ht),
          want(Ht, '2') )),
    all_audit(' audits its whole chain'),

    section('a fork, and the rule that closes it'),
    %% alice is in turn at height 3; carol is not. Neither has heard the
    %% other, which is what a partition is.
    node_do(alice, 'ledger_seal(''alice, in turn'')'),
    node_do(carol, 'ledger_seal(''carol, out of turn'')'),
    head_of(alice, FA), head_of(carol, FC),
    iso('before gossip the two nodes disagree',
        ( FA == FC -> want(same, disagree) ; true )),

    gossip_round,
    head_of(alice, GA), head_of(bob, GB), head_of(carol, GC),
    iso('after gossip all three agree again', want(GA-GB, GB-GC)),
    iso('and they agreed on the IN-TURN block, not the first seen',
        want(GA, FA)),
    all_audit(' still audits clean after the reorg'),

    section('a member of the federation rewrites history'),
    %% carol is a real authority with a real key. She seals a valid block
    %% at a height already settled. Nothing REFUSES it -- it is properly
    %% signed by somebody entitled to sign. It simply weighs less, and
    %% fork choice is where that is spent.
    head_of(alice, Before),
    carol_key(CK),
    node_do(carol, ['genesis_prev(G), seal(''', CK, ''', 0, G, carol, ''a history I prefer'', S, H), ',
                    'assertz(block(0,G,carol,''a history I prefer'',S,H)), ',
                    '( in_turn(0,carol) -> T=1 ; T=0 ), assertz(head_mark(0,H,T))']),
    gossip_round,
    head_of(alice, After),
    iso('and it is outweighed, not refused: the head does not move',
        want(After, Before)),
    iso('the chain still audits after the attempt',
        ( audit_of(alice, S), want(S, ok) )),

    section('and an auditor that consulted nothing'),
    %% A process that never saw federation.pl or node.pl, reading the
    %% chain out of the knowledge base and checking it under rules it
    %% loads itself. This is the Zeytun reader's position: no write path,
    %% no prior state, and still able to say whether the chain is sound.
    iso('a fresh process re-verifies every block it finds',
        ( bare(ledger_alice,
               ['( forall(block(H,Pv,A,P,S,Hs), valid_block(H,Pv,A,P,S,Hs)) ',
                '-> write(all_verified) ; write(''SOME_INVALID'') ), nl'],
               '^(all_verified|SOME_INVALID)$', V),
          want(V, all_verified) )),
    %% The count is NOT asserted lightly: alice holds the three settled
    %% blocks, both candidates from the fork, and carol's rewrite -- six,
    %% and that number moves whenever the choreography above changes.
    %% What must hold is that EVERY block she kept verifies, including
    %% the ones fork choice rejected. A node stores losing blocks; it
    %% must never store invalid ones.
    iso('and it found the losing fork branches too, not just the head',
        ( bare(ledger_alice,
               'findall(1, block(_,_,_,_,_,_), L), length(L,N), write(N), write('' blocks''), nl',
               '^[0-9]+ blocks$', N),
          want(N, '6 blocks') )).

%% a bare process: nobody's identity, nothing consulted
bare(KB, G0, Pattern, A) :-
    node_goal(G0, G),
    ( wire(KB, G, Pattern, A0) -> A = A0 ; A = none ).

main :-
    mallory_half,
    (   server_up
    ->  chain_half
    ;   nl, skip('no Zigurat server (the chain half)')
    ),
    nl, checks_done.

