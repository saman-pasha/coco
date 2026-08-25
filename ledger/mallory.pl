%% mallory -- the criminal node.
%%
%% Every ledger needs one. A federation that has only ever been offered
%% honest blocks has not been tested; it has been rehearsed. So mallory
%% is a first-class part of this arrangement rather than an afterthought
%% in a test file: she holds a real key, speaks the real protocol, and
%% attacks every law the chain has.
%%
%% Each attack below answers `refused' or `ACCEPTED', and the suite
%% requires `refused' -- with two deliberate exceptions, described where
%% they appear, because "the ledger refuses everything" would be a lie
%% and a lie in a security test is worse than no test.
%%
%%   attack_not_a_member(-V)      seal as herself
%%   attack_impersonate(-V)       seal as alice, with her own key
%%   attack_tamper(-V)            change a sealed block's payload
%%   attack_forged_hash(-V)       claim a hash the block does not have
%%   attack_replay_signature(-V)  move a real signature to another block
%%   attack_wrong_parent(-V)      re-point a real block at another parent
%%   attack_malleate(-V)          flip s to its twin  (verifies -- see below)
%%   attack_orphan(+Node, -V)     offer a block whose parent is missing
%%
%% THE LAWS SHE IS ATTACKING are the three in `valid_block/6' and the two
%% in `extends_known/2'. Between them: the hash is the block's own, the
%% author is a member, the signature is that author's, the parent is
%% held, the height follows. Everything else on this chain is built on
%% those five sentences, so those five are what an attacker gets to
%% touch.

:- use_module(library(poa)).
:- use_module(library(secp256k1)).

%% mallory's key. Not in federation.pl, which is the whole point -- the
%% key is real and valid secp256k1, and it buys her nothing.
mallory_key('4444444444444444444444444444444444444444444444444444444444444444').

%% A genuine, honest, fully valid block from a real authority, which is
%% what she has to work with: everything on a public chain is public, so
%% an attacker starts with every signature anyone ever published.
honest_block(block(0, Prev, alice, 'an honest payload', Sig, Hash)) :-
    genesis_prev(Prev),
    seal('1111111111111111111111111111111111111111111111111111111111111111',
         0, Prev, alice, 'an honest payload', Sig, Hash).

verdict(Goal, refused) :- \+ call(Goal), !.
verdict(_, 'ACCEPTED').

%% 1. SEAL AS HERSELF. A perfectly formed block, correctly hashed,
%% honestly signed -- by someone who is not in the federation. This is
%% the base case and the cheapest attack there is: anyone can make one.
attack_not_a_member(V) :-
    genesis_prev(Prev),
    mallory_key(K),
    seal(K, 0, Prev, mallory, 'mallory was here', Sig, Hash),
    verdict(valid_block(0, Prev, mallory, 'mallory was here', Sig, Hash), V).

%% 2. IMPERSONATE. Put alice's name on it and sign with her own key. The
%% author field is just an atom, so nothing stops her writing it -- what
%% stops her is that the signature is checked against ALICE's public key,
%% which is the one thing in the block she cannot produce.
attack_impersonate(V) :-
    genesis_prev(Prev),
    mallory_key(K),
    seal(K, 0, Prev, alice, 'signed by the wrong hand', Sig, Hash),
    verdict(valid_block(0, Prev, alice, 'signed by the wrong hand', Sig, Hash), V).

%% 3. TAMPER. Take alice's real block and change what it says, keeping
%% her real signature. The signature is over the HASH and the hash is
%% over the payload, so the recomputed hash no longer matches -- this is
%% caught at step 1 of valid_block, before any curve arithmetic happens.
attack_tamper(V) :-
    honest_block(block(H, Prev, A, _, Sig, Hash)),
    verdict(valid_block(H, Prev, A, 'a payload she preferred', Sig, Hash), V).

%% 4. FORGE THE HASH. If the block will not hash to what she wants, claim
%% a different hash. A node that trusted the sender's hash would then
%% check a real signature over a real hash and accept a block that says
%% something else entirely -- which is why `valid_block/6' recomputes
%% instead of comparing.
attack_forged_hash(V) :-
    honest_block(block(H, Prev, A, P, Sig, _)),
    sha256('something else', Fake),
    verdict(valid_block(H, Prev, A, P, Sig, Fake), V).

%% 5. REPLAY A SIGNATURE. Alice signed SOMETHING, honestly. Move those
%% 64 bytes onto a block she never saw. The signature is bound to the
%% hash and the hash is bound to every field, so a signature is only ever
%% valid for the one block it was made for.
attack_replay_signature(V) :-
    honest_block(block(_, Prev, A, _, Sig, _)),
    block_hash(1, Prev, A, 'a block alice never sealed', Other),
    verdict(valid_block(1, Prev, A, 'a block alice never sealed', Sig, Other), V).

%% 6. RE-POINT THE PARENT. Take a real block and hang it off a different
%% parent -- the move that would let an attacker graft honest history
%% onto a chain of her own. Prev is inside the hash, so the block's
%% identity changes and the signature stops matching.
attack_wrong_parent(V) :-
    honest_block(block(H, _, A, P, Sig, Hash)),
    sha256('a parent of my choosing', Elsewhere),
    verdict(valid_block(H, Elsewhere, A, P, Sig, Hash), V).

%% 7. MALLEATE -- AND THIS ONE SUCCEEDS, which is the point.
%%
%% For every ECDSA signature (r, s) the pair (r, n-s) is equally valid,
%% and anyone can compute it without the key. So mallory CAN produce a
%% different-looking signature for alice's block, and it WILL verify.
%% That is not a flaw in the verifier -- it is what ECDSA is, and a
%% verifier that refused it would be refusing valid signatures.
%%
%% What matters is what she gains, and the answer here is nothing. The
%% block's hash is over height, parent, author and payload and NOT over
%% the signature, so a malleated signature is the same block: same hash,
%% same identity, same position in the chain. Bitcoin learned this the
%% expensive way -- its transaction ids covered the signature, so
%% flipping s changed the txid and an unconfirmed transaction could be
%% made to "disappear". `block_signable/5' is where that lesson lives.
%%
%% (library(secp256k1) signs low-s regardless, per BIP-62, so the
%% malleated twin is never the one this chain produces.)
attack_malleate(V) :-
    honest_block(block(H, Prev, A, P, Sig, Hash)),
    malleate(Sig, Flipped),
    Flipped \== Sig,
    verdict(valid_block(H, Prev, A, P, Flipped, Hash), V).

%% n - s, in hex, without a bignum: the order is a constant, so this is
%% one subtraction done with the two halves of a 256-bit number.
secp_order('fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141').

malleate(Sig, Flipped) :-
    sub_atom(Sig, 0, 64, _, R),
    sub_atom(Sig, 64, 64, 0, S),
    secp_order(N),
    hex_minus(N, S, S2),
    atom_concat(R, S2, Flipped).

%% Subtract two 64-digit hex numbers, digit by digit from the right.
hex_minus(A, B, C) :-
    atom_chars(A, AC), atom_chars(B, BC),
    reverse(AC, AR), reverse(BC, BR),
    hex_sub_digits(AR, BR, 0, CR),
    reverse(CR, CC),
    atom_chars(C, CC).

hex_sub_digits([], [], _, []).
hex_sub_digits([A|As], [B|Bs], Borrow, [C|Cs]) :-
    hex_val(A, AV), hex_val(B, BV),
    D is AV - BV - Borrow,
    ( D < 0 -> D1 is D + 16, B1 = 1 ; D1 = D, B1 = 0 ),
    hex_val(C, D1),
    hex_sub_digits(As, Bs, B1, Cs).

hex_val('0',0). hex_val('1',1). hex_val('2',2). hex_val('3',3).
hex_val('4',4). hex_val('5',5). hex_val('6',6). hex_val('7',7).
hex_val('8',8). hex_val('9',9). hex_val(a,10).  hex_val(b,11).
hex_val(c,12).  hex_val(d,13).  hex_val(e,14).  hex_val(f,15).

%% 8. THE ORPHAN. A block that is valid in every way but whose parent
%% this node does not hold. It must NOT be adopted -- not because it is
%% bad, but because a node that accepts blocks it cannot link to genesis
%% is a node whose chain has holes, and a chain with holes cannot be
%% audited. `extends_known/2' is the rule, and it is separate from
%% `valid_block/6' on purpose: this block may be perfectly good and
%% simply early.
attack_orphan(V) :-
    sha256('a parent nobody has', Ghost),
    seal('1111111111111111111111111111111111111111111111111111111111111111',
         7, Ghost, alice, 'from a chain you do not have', Sig, Hash),
    ( valid_block(7, Ghost, alice, 'from a chain you do not have', Sig, Hash)
    -> true                      % it IS a valid block, and that is fine
    ;  true ),
    verdict(extends_known(7, Ghost), V).
