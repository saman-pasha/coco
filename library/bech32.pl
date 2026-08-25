%% library(bech32) -- bech32, bech32m, and segwit addresses, in Prolog.
%%
%%   bech32_encode(+Hrp, +Data, -Atom)      the bech32 constant (1)
%%   bech32m_encode(+Hrp, +Data, -Atom)     the bech32m constant
%%   bech32_decode(+Atom, -Hrp, -Data, -Kind)   Kind is bech32 or bech32m
%%   segwit_encode(+Hrp, +Ver, +ProgHex, -Addr)
%%   segwit_decode(+Hrp, +Addr, -Ver, -ProgHex)
%%
%% Data is a list of 5-BIT VALUES, which is what bech32 is defined over;
%% `segwit_encode/4' takes the hex a caller actually has and does the
%% 8-to-5 regrouping itself.
%%
%% WHY THIS IS PROLOG AND NOT A MODULE, again: the whole of bech32 is a
%% checksum over small integers and a change of grouping. There is no
%% buffer to permute and nothing to make fast -- an address is ninety
%% characters at most, by rule.
%%
%% THE CHECKSUM IS A BCH CODE, not a hash, and that is the entire reason
%% bech32 exists: it is designed to CATCH the errors humans and QR
%% scanners actually make, and guarantees detection of up to four wrong
%% characters. A truncated SHA-256 like base58check's catches a typo only
%% on average. That is why the generator constants below are what they
%% are, and why one wrong bit in them silently weakens the guarantee
%% rather than breaking anything visibly -- they are checked against
%% published addresses in test/crypto.sh, which is the only way to know.
%%
%% TWO CONSTANTS, AND WHICH ONE IS A CONSENSUS RULE. BIP-173 ends the
%% checksum by XOR with 1. That turned out to have a flaw: for some
%% lengths, a final character could be inserted or deleted without
%% breaking the checksum. BIP-350 fixes it with a different constant,
%% 0x2bc830a3, and Bitcoin's rule is now: witness version 0 (P2WPKH,
%% P2WSH) uses bech32, and version 1 and up (taproot) uses bech32m.
%% Encoding a taproot output with the old constant produces a string that
%% looks perfectly good and that no node will accept, so
%% `segwit_encode/4' picks the constant from the version rather than
%% taking it as an argument -- the caller cannot get it wrong because the
%% caller is not asked.

:- use_module(library(bytes)).

bech32_charset('qpzry9x8gf2tvdw0s3jn54khce6mua7l').

bech32_const(bech32, 1).
bech32_const(bech32m, 0x2bc830a3).

%% The five generator constants of the BCH code.
%% The five generator constants of the BCH code. Written in hex because
%% that is how BIP-173 writes them and how anyone checking them will have
%% them; the first draft of this file carried them as decimal, three of
%% the five transcribed wrong, and every address it produced was
%% well-formed, self-consistent and worthless.
bech32_gen([0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]).

%% ---- the checksum ---------------------------------------------------
%%
%% chk starts at 1; each value shifts the register five bits and folds in
%% a generator for every high bit that fell off the top. `mod' does the
%% masking that `/\' would: both are exact here because chk is never
%% negative, and the engine's integers are 64-bit while chk never exceeds
%% thirty.

bech32_polymod(Values, Chk) :- bech32_polymod_(Values, 1, Chk).

bech32_polymod_([], Chk, Chk).
bech32_polymod_([V|T], Chk0, Chk) :-
    B is Chk0 >> 25,
    Chk1 is ((Chk0 /\ 0x1ffffff) << 5) xor V,
    bech32_gen(Gen),
    bech32_fold(Gen, 0, B, Chk1, Chk2),
    bech32_polymod_(T, Chk2, Chk).

bech32_fold([], _, _, Chk, Chk).
bech32_fold([G|Gs], I, B, Chk0, Chk) :-
    (   (B >> I) /\ 1 =:= 1
    ->  Chk1 is Chk0 xor G
    ;   Chk1 = Chk0
    ),
    I1 is I + 1,
    bech32_fold(Gs, I1, B, Chk1, Chk).

%% The human-readable part enters the checksum twice: high bits first,
%% then a zero, then low bits. That is what ties the checksum to the
%% prefix, so a mainnet address cannot be read as a testnet one.
bech32_hrp_expand(Hrp, Values) :-
    atom_chars(Hrp, Cs),
    hrp_high(Cs, His),
    hrp_low(Cs, Los),
    append(His, [0|Los], Values).

hrp_high([], []).
hrp_high([C|T], [V|R]) :- char_code(C, X), V is X >> 5, hrp_high(T, R).

hrp_low([], []).
hrp_low([C|T], [V|R]) :- char_code(C, X), V is X /\ 31, hrp_low(T, R).

bech32_checksum(Hrp, Data, Kind, Check) :-
    bech32_hrp_expand(Hrp, Exp),
    append(Exp, Data, A),
    append(A, [0,0,0,0,0,0], Values),      % SIX, one per checksum character
    bech32_polymod(Values, P0),
    bech32_const(Kind, Const),
    P is P0 xor Const,
    check_six(0, P, Check).

check_six(6, _, []) :- !.
check_six(I, P, [V|T]) :-
    Shift is 5 * (5 - I),
    V is (P >> Shift) /\ 31,
    I1 is I + 1,
    check_six(I1, P, T).

%% ---- encoding -------------------------------------------------------

bech32_encode(Hrp, Data, Atom)  :- bech32_encode_(Hrp, Data, bech32, Atom).
bech32m_encode(Hrp, Data, Atom) :- bech32_encode_(Hrp, Data, bech32m, Atom).

bech32_encode_(Hrp, Data, Kind, Atom) :-
    bech32_checksum(Hrp, Data, Kind, Check),
    append(Data, Check, All),
    values_chars(All, Cs),
    atom_chars(Body, Cs),
    atom_concat(Hrp, '1', Sep),
    atom_concat(Sep, Body, Atom).

values_chars([], []).
values_chars([V|T], [C|R]) :-
    bech32_charset(A), atom_chars(A, Cs),
    b32_nth(V, Cs, C),
    values_chars(T, R).

b32_nth(0, [C|_], C) :- !.
b32_nth(N, [_|T], C) :- N > 0, M is N - 1, b32_nth(M, T, C).

%% ---- decoding -------------------------------------------------------
%%
%% MIXED CASE IS INVALID, by rule, and not merely unusual: the checksum is
%% computed over one case, so allowing both in one string would let two
%% different strings carry the same checksum. All upper is legal (it makes
%% a denser QR code) and is folded down here; anything mixed fails.

bech32_decode(Atom, Hrp, Data, Kind) :-
    atom_chars(Atom, Cs0),
    single_case(Cs0),
    downcase_chars(Cs0, Cs),
    last_sep(Cs, 0, -1, Pos),
    Pos > 0,
    length(Cs, Len),
    Len =< 90,
    DataLen is Len - Pos - 1,
    DataLen >= 6,
    split_at(Pos, Cs, HrpCs, [_|BodyCs]),
    atom_chars(Hrp, HrpCs),
    chars_values(BodyCs, All),
    bech32_hrp_expand(Hrp, Exp),
    append(Exp, All, Values),
    bech32_polymod(Values, P),
    bech32_const(Kind, P),
    Keep is DataLen - 6,
    split_at(Keep, All, Data, _).

single_case(Cs) :- \+ (member(C, Cs), is_upper(C)), !.
single_case(Cs) :- \+ (member(C, Cs), is_lower(C)).

is_upper(C) :- char_code(C, X), X >= 0'A, X =< 0'Z.
is_lower(C) :- char_code(C, X), X >= 0'a, X =< 0'z.

downcase_chars([], []).
downcase_chars([C|T], [D|R]) :-
    (   is_upper(C) -> char_code(C, X), Y is X + 32, char_code(D, Y)
    ;   D = C
    ),
    downcase_chars(T, R).

%% The separator is the LAST '1', because the prefix may contain one.
last_sep([], _, Best, Best).
last_sep([C|T], I, Best0, Best) :-
    (   C == '1' -> Best1 = I ; Best1 = Best0 ),
    I1 is I + 1,
    last_sep(T, I1, Best1, Best).

split_at(0, L, [], L) :- !.
split_at(N, [H|T], [H|A], B) :- N > 0, M is N - 1, split_at(M, T, A, B).

chars_values([], []).
chars_values([C|T], [V|R]) :-
    bech32_charset(A), atom_chars(A, Cs),
    b32_index(Cs, C, 0, V),
    chars_values(T, R).

b32_index([C|_], C, N, N) :- !.
b32_index([_|T], C, N0, N) :- N1 is N0 + 1, b32_index(T, C, N1, N).

%% ---- 8 bits to 5, and back ------------------------------------------
%%
%% Regrouping, not conversion. Going 8 to 5 the last group is PADDED with
%% zero bits; coming back the padding is DISCARDED and must have been
%% zero, and there must be fewer than five bits of it -- otherwise a
%% whole group was invented, and two different programs would encode to
%% the same address.

convertbits(Data, From, To, Pad, Out) :-
    MaxAcc is (1 << (From + To - 1)) - 1,
    MaxV is (1 << To) - 1,
    cb_(Data, From, To, MaxAcc, MaxV, 0, 0, [], Bits, Acc, Rev),
    (   Pad == true
    ->  (   Bits > 0
        ->  Shift is To - Bits,
            V is (Acc << Shift) /\ MaxV,
            Rev1 = [V|Rev]
        ;   Rev1 = Rev
        )
    ;   Bits < From,
        Acc /\ ((1 << Bits) - 1) =:= 0,
        Rev1 = Rev
    ),
    reverse(Rev1, Out).

%% THE ACCUMULATOR IS MASKED, which is not decoration. Only the low
%% From+To-1 bits are ever read, but an unmasked accumulator keeps
%% growing -- eight bits per input byte -- and a 40-byte witness program
%% would need 320 of them. The engine's integers are 64 bits, so the
%% overflow arrives silently at the seventeenth byte and every address
%% past that length comes out wrong.
cb_([], _, _, _, _, Bits, Acc, Rev, Bits, Acc, Rev).
cb_([V|T], From, To, MaxAcc, MaxV, Bits0, Acc0, Rev0, Bits, Acc, Rev) :-
    V >= 0,
    V < (1 << From),
    Acc1 is ((Acc0 << From) \/ V) /\ MaxAcc,
    Bits1 is Bits0 + From,
    cb_emit(Bits1, Acc1, To, MaxV, Rev0, Bits2, Rev1),
    cb_(T, From, To, MaxAcc, MaxV, Bits2, Acc1, Rev1, Bits, Acc, Rev).

cb_emit(Bits, _, To, _, Rev, Bits, Rev) :- Bits < To, !.
cb_emit(Bits0, Acc, To, MaxV, Rev0, Bits, Rev) :-
    Bits1 is Bits0 - To,
    V is (Acc >> Bits1) /\ MaxV,
    cb_emit(Bits1, Acc, To, MaxV, [V|Rev0], Bits, Rev).

%% ---- segwit ---------------------------------------------------------

segwit_encode(Hrp, Ver, ProgHex, Addr) :-
    Ver >= 0, Ver =< 16,
    hex_bytes(ProgHex, Bytes),
    length(Bytes, N),
    N >= 2, N =< 40,
    ( Ver =:= 0 -> ( N =:= 20 ; N =:= 32 ) ; true ),
    convertbits(Bytes, 8, 5, true, Five),
    ( Ver =:= 0 -> Kind = bech32 ; Kind = bech32m ),
    bech32_encode_(Hrp, [Ver|Five], Kind, Addr).

segwit_decode(Hrp, Addr, Ver, ProgHex) :-
    bech32_decode(Addr, Hrp, [Ver|Five], Kind),
    Ver >= 0, Ver =< 16,
    ( Ver =:= 0 -> Kind == bech32 ; Kind == bech32m ),
    convertbits(Five, 5, 8, false, Bytes),
    length(Bytes, N),
    N >= 2, N =< 40,
    ( Ver =:= 0 -> ( N =:= 20 ; N =:= 32 ) ; true ),
    bytes_hex(Bytes, ProgHex).
