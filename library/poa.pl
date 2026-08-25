%% library(poa) -- proof of authority, as rules.
%%
%% The consensus is CLAUSES, not code that implements a consensus. Every
%% predicate below is a rule a node can read, a peer can check, and --
%% because a chain here is a knowledge base and a rule is a row -- the
%% chain itself can eventually carry. That is the aggregator's whole
%% premise, arriving early.
%%
%%   block_hash(+H, +Prev, +Author, +Payload, -Hash)
%%   block_signable(+H, +Prev, +Author, +Payload, -Text)
%%   seal(+PrivHex, +H, +Prev, +Author, +Payload, -Sig, -Hash)
%%   valid_block(+H, +Prev, +Author, +Payload, +Sig, +Hash)
%%   in_turn(+Height, ?Author)     whose turn it is at this height
%%   genesis_prev(-Hash)
%%
%%   better_head(+A, +B)           fork choice: is A a better head than B
%%   chain_weight(+Blocks, -W)     and what it weighs
%%
%% THE AUTHORITY SET IS NOT HERE. `authority(Name, PubKeyHex)' is
%% supplied by whoever loads this -- the federation file, or, later,
%% entries on the chain itself. This library says what a valid block IS;
%% it does not say who the federation is, because those are different
%% questions and only the first one is universal.

:- use_module(library(sha256)).
:- use_module(library(secp256k1)).
:- use_module(library(lists)).

:- dynamic authority/2.

%% The genesis parent: thirty-two zero bytes. A chain has to start
%% somewhere and the start has to be a hash-shaped thing, or the "prev
%% must be the parent's hash" rule needs an exception, and a rule with an
%% exception is two rules.
genesis_prev('0000000000000000000000000000000000000000000000000000000000000000').

%% WHAT IS SIGNED IS A TEXT, and the text is the block. Every field that
%% a node would act on is in it: change the height, the parent, the
%% author or the payload and the hash changes, so the signature no longer
%% verifies. The separator matters -- without it, height 1 with payload
%% '23' and height 12 with payload '3' would hash the same, which is a
%% real attack and not a hypothetical one.
block_signable(H, Prev, Author, Payload, Text) :-
    atomic_list_concat([H, Prev, Author, Payload], '|', Text).

block_hash(H, Prev, Author, Payload, Hash) :-
    block_signable(H, Prev, Author, Payload, Text),
    sha256(Text, Hash).

%% Sealing is signing the hash. The private key never leaves the caller's
%% process, and the nonce never leaves library(secp256k1) -- RFC 6979
%% derives it inside the module from the key and the hash, so two nodes
%% sealing the same block produce the same signature and there is no
%% entropy source to be wrong.
seal(Priv, H, Prev, Author, Payload, Sig, Hash) :-
    block_hash(H, Prev, Author, Payload, Hash),
    secp256k1_sign(Priv, Hash, Sig).

%% A BLOCK IS VALID WHEN THREE THINGS HOLD, and a node checks all three
%% on every block it is offered, including the ones it is told are
%% already agreed:
%%
%%   1. the hash is the hash OF THIS BLOCK -- recomputed here, never
%%      taken on the sender's word, because a hash a peer supplies is a
%%      claim and not a fact;
%%   2. the author is in the federation;
%%   3. the signature is that author's over that hash.
%%
%% Height and parent are NOT checked here: a block can be perfectly valid
%% and not belong on this chain yet (an orphan whose parent has not
%% arrived), and conflating "well-formed and signed" with "extends what I
%% have" is what makes a gossip loop drop blocks it should have kept.
valid_block(H, Prev, Author, Payload, Sig, Hash) :-
    block_hash(H, Prev, Author, Payload, Recomputed),
    Recomputed == Hash,
    authority(Author, Pub),
    secp256k1_verify(Hash, Sig, Pub).

%% ---- whose turn ------------------------------------------------------
%%
%% Round robin over the sorted authority names. This is what makes the
%% schedule a FUNCTION OF HEIGHT rather than of who is fastest: at every
%% height exactly one authority is in turn, everyone can compute which,
%% and nobody has to be told.
%%
%% An out-of-turn block is still VALID -- that is what keeps the chain
%% alive when the scheduled authority is down, and it is the difference
%% between proof of authority and a queue. It is merely worth less, and
%% `better_head/2' is where that is spent.

authorities(Names) :-
    findall(N, authority(N, _), Raw),
    sort(Raw, Names).

in_turn(Height, Author) :-
    authorities(Names),
    length(Names, N),
    N > 0,
    I is Height mod N,
    nth0(I, Names, Author).

%% ---- fork choice -----------------------------------------------------
%%
%% Two nodes can hold different chains -- the network partitioned, or two
%% authorities sealed at the same height while neither had heard the
%% other. Both chains are valid. A rule has to choose, every node has to
%% choose the SAME one, and the choice must not depend on what arrived
%% first, because arrival order is exactly what differs between nodes.
%%
%% So the comparison is over facts the chain itself carries, in order:
%%
%%   1. LENGTH. More blocks is more authority-work.
%%   2. IN-TURN COUNT. At equal length, prefer the chain whose blocks
%%      were sealed by the authority whose turn it was. A minority that
%%      seals out of turn cannot outweigh the schedule.
%%   3. THE HASH ITSELF, lower first. Not a quality -- a coin toss that
%%      every node makes the same way. Without it two equally good chains
%%      would both be kept and the fork would never close.
%%
%% head(Height, Hash, InTurnCount) is the summary each side is compared
%% by, which is all three numbers and nothing about who is asking.

better_head(head(HA, _, _), head(HB, _, _)) :- HA > HB, !.
better_head(head(HA, _, _), head(HB, _, _)) :- HA < HB, !, fail.
better_head(head(_, _, TA), head(_, _, TB)) :- TA > TB, !.
better_head(head(_, _, TA), head(_, _, TB)) :- TA < TB, !, fail.
better_head(head(_, A, _), head(_, B, _)) :- A @< B.

%% The weight of a chain given as a list of block/6 terms, YOUNGEST
%% FIRST -- so the head is the first element and the in-turn count is
%% over the whole list.
chain_weight([], head(-1, '', 0)).
chain_weight([B|Bs], head(H, Hash, T)) :-
    B = block(H, _, _, _, _, Hash),
    chain_in_turn([B|Bs], 0, T).

%% How many of these blocks were sealed by the authority in turn.
chain_in_turn([], Acc, Acc).
chain_in_turn([block(H, _, Author, _, _, _)|T], Acc0, Acc) :-
    (   in_turn(H, Author) -> Acc1 is Acc0 + 1 ; Acc1 = Acc0 ),
    chain_in_turn(T, Acc1, Acc).
