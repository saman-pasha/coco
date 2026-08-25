%% library(btc) -- Bitcoin identity, from the two hash modules.
%%
%% The companion to library(eth), and the same demonstration: a Prolog
%% library that loads two COMPILED Cicili modules and composes them into
%% the primitive a chain actually uses. Bitcoin's is `hash160' --
%% RIPEMD-160 over SHA-256 -- which is what a P2PKH address, a script
%% and a witness program are all built from.
%%
%%   hash160_hex(+HexIn, -Hex)   ripemd160(sha256(bytes))
%%   btc_compress(+XYHex, -Hex)  the 33-byte form of a public key: an
%%                               02 or 03 in front of x, the digit
%%                               saying whether y is even -- which is
%%                               all the information the other
%%                               coordinate carries
%%   btc_hash160(+XYHex, -Hex)   a key straight to its hash160
%%   btc_txid(+RawTxHex, -Hex)   a transaction id: SHA-256 twice, read
%%                               BACKWARDS, because Bitcoin displays
%%                               hashes in the reverse of the byte order
%%                               it hashes them in -- the single most
%%                               common way to get a txid wrong
%%
%% The base58check that turns a hash160 into the `1...' string people
%% paste is an ENCODING, and encodings belong in Prolog with the rest of
%% the parsing -- they are on the ladder, not in here.

:- use_module(library(sha256)).
:- use_module(library(ripemd160)).

hash160_hex(Hex, H) :-
    sha256_hex(Hex, S),
    ripemd160_hex(S, H).

even_hex_digit(D) :- memberchk(D, ['0','2','4','6','8',a,c,e,'A','C','E']).

btc_compress(XY, C) :-
    sub_atom(XY, 0, 64, _, X),
    sub_atom(XY, 127, 1, 0, Last),
    ( even_hex_digit(Last) -> P = '02' ; P = '03' ),
    atom_concat(P, X, C).

btc_hash160(XY, H) :-
    btc_compress(XY, C),
    hash160_hex(C, H).

hex_pairs([], []).
hex_pairs([A,B|T], [p(A,B)|R]) :- hex_pairs(T, R).

pairs_chars([], []).
pairs_chars([p(A,B)|T], [A,B|R]) :- pairs_chars(T, R).

%% Byte-reverse a hex atom: pair the digits, reverse the pairs, join.
hex_reverse(Hex, Rev) :-
    atom_chars(Hex, Cs),
    hex_pairs(Cs, Ps),
    reverse(Ps, Rs),
    pairs_chars(Rs, Out),
    atom_chars(Rev, Out).

btc_txid(RawHex, Txid) :-
    sha256d_hex(RawHex, H),
    hex_reverse(H, Txid).
