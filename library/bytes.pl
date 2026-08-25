%% library(bytes) -- hex text to a list of byte integers, and back.
%%
%% The plumbing every encoding needs and none of them should carry its
%% own copy of. The compiled crypto modules take hex atoms and answer hex
%% atoms because a C half wants a flat buffer; an ENCODING works on the
%% bytes themselves, digit by digit, and this is the seam between the
%% two.
%%
%%   hex_bytes(+Hex, -Bytes)   '0a1b' --> [10, 27]
%%   bytes_hex(+Bytes, -Hex)   [10, 27] --> '0a1b'
%%
%% A leading `0x' is accepted and dropped, because that is how a hex atom
%% is usually written down and refusing it would only mean every caller
%% stripping it first. An ODD number of digits FAILS rather than assuming
%% a leading zero: half a byte is not a byte, and guessing which half was
%% meant is how a transaction becomes a different transaction.

hex_bytes(Hex, Bytes) :-
    atom_chars(Hex, Cs0),
    strip_0x(Cs0, Cs),
    hex_pairs_(Cs, Bytes).

strip_0x(['0',x|T], T) :- !.
strip_0x(['0','X'|T], T) :- !.
strip_0x(Cs, Cs).

hex_pairs_([], []).
hex_pairs_([A,B|T], [V|R]) :-
    hex_digit(A, Hi),
    hex_digit(B, Lo),
    V is Hi * 16 + Lo,
    hex_pairs_(T, R).

hex_digit(C, V) :-
    char_code(C, Code),
    (   Code >= 0'0, Code =< 0'9 -> V is Code - 0'0
    ;   Code >= 0'a, Code =< 0'f -> V is Code - 0'a + 10
    ;   Code >= 0'A, Code =< 0'F -> V is Code - 0'A + 10
    ).

bytes_hex(Bytes, Hex) :-
    bytes_chars_(Bytes, Cs),
    atom_chars(Hex, Cs).

bytes_chars_([], []).
bytes_chars_([B|T], [H,L|R]) :-
    Hi is B >> 4,
    Lo is B /\ 15,
    nibble_char(Hi, H),
    nibble_char(Lo, L),
    bytes_chars_(T, R).

nibble_char(V, C) :-
    (   V < 10 -> Code is 0'0 + V
    ;   Code is 0'a + V - 10
    ),
    char_code(C, Code).
