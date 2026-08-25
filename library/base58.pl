%% library(base58) -- base58 and base58check, in Prolog.
%%
%%   base58_encode(+Hex, -Atom)          base58_decode(+Atom, -Hex)
%%   base58check_encode(+VerHex, +PayloadHex, -Atom)
%%   base58check_decode(+Atom, -VerHex, -PayloadHex)
%%
%% THIS IS WHERE AN ENCODING BELONGS. Every hash and every curve The Coco
%% needs is a compiled Cicili module, because a permutation over a byte
%% buffer is what C is for. base58 is not that: it is a change of base
%% over an arbitrarily long integer, and the whole of it is
%% divide-with-remainder over a list. Prolog holds a list better than C
%% does, and the code below is the algorithm rather than an
%% implementation of it -- which is the argument for the split, made
%% concrete.
%%
%% THE ALPHABET IS THE POINT OF BASE58. It is base64 with the four
%% characters that a human copying a string gets wrong removed: 0, O, I
%% and l. Nothing else about the encoding is clever, and the ordering
%% below (digits, then upper case, then lower) is Bitcoin's own and NOT
%% the ASCII order -- getting it from ASCII gives a plausible string
%% that decodes to something else.
%%
%% LEADING ZERO BYTES ARE NOT DIGITS. A number does not have leading
%% zeros, so base conversion loses them -- but in an address they are
%% version bytes and they matter. Each one is encoded as a separate '1'
%% in front, which is why a mainnet P2PKH address (version byte 0x00)
%% always starts with a 1.

:- use_module(library(bytes)).
:- use_module(library(sha256)).

b58_alphabet('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz').

b58_char(V, C) :-
    b58_alphabet(A),
    atom_chars(A, Cs),
    b58_nth(V, Cs, C).

%% The two directions are NOT one predicate run backwards. Encoding has
%% the index and wants the character, so it walks down to it; decoding has
%% the character and wants the index, so it counts forward. Written as one
%% predicate with an unbound index, the arithmetic in the countdown clause
%% throws instantiation_error -- which it did, and which is the honest
%% answer: `N > 0' cannot be asked about a variable.
b58_nth(0, [C|_], C) :- !.
b58_nth(N, [_|T], C) :- N > 0, M is N - 1, b58_nth(M, T, C).

b58_value(C, V) :-
    b58_alphabet(A),
    atom_chars(A, Cs),
    b58_index(Cs, C, 0, V),
    !.

b58_index([C|_], C, N, N) :- !.
b58_index([_|T], C, N0, N) :- N1 is N0 + 1, b58_index(T, C, N1, N).

%% ---- encoding -------------------------------------------------------

base58_encode(Hex, Atom) :-
    hex_bytes(Hex, Bytes),
    b58_leading_zeros(Bytes, Z, Rest),
    b58_digits(Rest, Ds),
    b58_ones(Z, Ones),
    append(Ones, Ds, Cs),
    atom_chars(Atom, Cs).

b58_leading_zeros([0|T], N, Rest) :- !, b58_leading_zeros(T, M, Rest), N is M + 1.
b58_leading_zeros(L, 0, L).

b58_ones(0, []) :- !.
b58_ones(N, ['1'|T]) :- M is N - 1, b58_ones(M, T).

%% Repeatedly divide the whole number by 58, most significant byte
%% first, collecting remainders. The remainders come out least
%% significant first, so the result is reversed at the end.
b58_digits([], []) :- !.
b58_digits(Bytes, Ds) :-
    b58_digits_(Bytes, Rs),
    reverse(Rs, Vs),
    b58_chars(Vs, Ds).

b58_digits_(Bytes, [R|Rs]) :-
    div58(Bytes, Q, R),
    (   all_zero(Q)
    ->  Rs = []
    ;   b58_digits_(Q, Rs)
    ).

all_zero([]).
all_zero([0|T]) :- all_zero(T).

%% Long division by 58 in base 256. The carry never exceeds 57, so the
%% widest value here is 57*256+255 = 14847 -- nowhere near the engine's
%% 64-bit integers, which is why this needs no bignum of its own.
div58(Bytes, Q, R) :- div58_(Bytes, 0, Q, R).

div58_([], Carry, [], Carry).
div58_([B|Bs], Carry, [Q|Qs], R) :-
    V is Carry * 256 + B,
    Q is V // 58,
    C is V mod 58,
    div58_(Bs, C, Qs, R).

b58_chars([], []).
b58_chars([V|T], [C|R]) :- b58_char(V, C), b58_chars(T, R).

%% ---- decoding -------------------------------------------------------

base58_decode(Atom, Hex) :-
    atom_chars(Atom, Cs),
    b58_leading_ones(Cs, Z, Rest),
    b58_values(Rest, Vs),
    b58_number(Vs, Bytes0),
    b58_zeros(Z, Zeros),
    append(Zeros, Bytes0, Bytes),
    bytes_hex(Bytes, Hex).

b58_leading_ones(['1'|T], N, Rest) :- !, b58_leading_ones(T, M, Rest), N is M + 1.
b58_leading_ones(L, 0, L).

b58_zeros(0, []) :- !.
b58_zeros(N, [0|T]) :- M is N - 1, b58_zeros(M, T).

b58_values([], []).
b58_values([C|T], [V|R]) :- b58_value(C, V), b58_values(T, R).

%% The other direction: multiply the accumulated byte list by 58 and add
%% the next digit, carrying into new high bytes as needed.
b58_number(Vs, Bytes) :-
    b58_number_(Vs, [], Rev),
    reverse(Rev, Bytes0),
    strip_zeros(Bytes0, Bytes).

b58_number_([], Acc, Acc).
b58_number_([V|T], Acc, Out) :-
    mul58(Acc, V, Acc1),
    b58_number_(T, Acc1, Out).

%% Acc is LEAST significant first, which makes the carry a plain fold.
mul58([], Carry, Out) :- carry_bytes(Carry, Out).
mul58([B|Bs], Carry, [D|Rest]) :-
    V is B * 58 + Carry,
    D is V /\ 255,
    C is V >> 8,
    mul58(Bs, C, Rest).

carry_bytes(0, []) :- !.
carry_bytes(C, [D|T]) :- D is C /\ 255, N is C >> 8, carry_bytes(N, T).

strip_zeros([0|T], R) :- !, strip_zeros(T, R).
strip_zeros(L, L).

%% ---- base58check ----------------------------------------------------
%%
%% A version byte, the payload, and the FIRST FOUR BYTES of the double
%% SHA-256 of both. Four bytes is not a security property -- it is a
%% typo check, and it is why pasting an address with one character wrong
%% is rejected rather than sending coins to nobody.

base58check_encode(Ver, Payload, Atom) :-
    atom_concat(Ver, Payload, Body),
    b58_checksum(Body, Sum),
    atom_concat(Body, Sum, Full),
    base58_encode(Full, Atom).

base58check_decode(Atom, Ver, Payload) :-
    base58_decode(Atom, Full),
    atom_length(Full, L),
    L >= 10,
    Keep is L - 8,
    sub_atom(Full, 0, Keep, _, Body),
    sub_atom(Full, Keep, 8, 0, Sum),
    b58_checksum(Body, Sum),          % fails on a mistyped address
    sub_atom(Body, 0, 2, _, Ver),
    Rest is Keep - 2,
    sub_atom(Body, 2, Rest, 0, Payload).

b58_checksum(Body, Sum) :-
    sha256d_hex(Body, H),
    sub_atom(H, 0, 8, _, Sum).
