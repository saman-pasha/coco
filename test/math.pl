%% library(u256): the width an exchange needs, and the refusals that make
%% it worth having.
%%
%% WHY THIS CASE EXISTS, and it is not a hypothetical. cocolog's integers
%% are 64 bits and they WRAP IN SILENCE. The first check below asserts
%% that -- it asks cocolog's own `is/2' for the first product a Uniswap
%% swap computes at ordinary token scale (one token is 10^18) and pins the
%% WRONG ANSWER it gives. That check passing is the reason every other
%% check here exists, and if a future cocolog grows wide integers it will
%% fail and this file should be read again rather than patched.
%%
%% WHAT IS BEING PINNED, beyond the arithmetic:
%%
%%   NOTHING WRAPS. Every operation that cannot represent its answer
%%   raises instead: over 2^256-1, below zero, a zero divisor, a quotient
%%   too wide, a value too big for a cocolog integer. Solidity 0.8 made
%%   overflow revert for this reason, and a wrapped balance is a lie that
%%   spends.
%%
%%   MULDIV KEEPS THE MIDDLE. floor(A*B/C) where A*B does not fit 256
%%   bits and the answer does -- the shape of every price an exchange
%%   quotes. The check uses 2^255 * 4 / 8, whose intermediate is 2^257.
%%
%%   THE SQUARE ROOT IS THE FLOOR, exactly, including at the top of the
%%   range where sqrt(2^256-1) must be 2^128-1 and not one more.
%%
%%   AND THE ARITHMETIC ADDS UP TO UNISWAP. The last block computes v2's
%%   getAmountOut at pool scale and requires 996006981039903216 -- a
%%   number this repository did not invent; it is what the constant
%%   product formula with a 0.3% fee pays for one token into a 1000/1000
%%   pool, and anyone can recompute it. Then it swaps back and requires
%%   the input to return exactly, and requires k to have GROWN, which is
%%   what the fee is.
%%
%% THE REFUSALS ARE COMPARED AS ERROR TERMS NOW, not as a phrase grepped
%% out of stderr. The .sh case matched `u256 overflow' anywhere in the
%% output, which would also have matched a message that merely mentioned
%% it; `raises/2' hands back the error term the goal actually threw.
%%
%% SKIPs when the module cannot be built (no sbcl, or no CICILI).
%%
%% Run:  cocolog -s test/math.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

max('115792089237316195423570985008687907853269984665640564039457584007913129639935').

%% one token in, a thousand-for-a-thousand pool
pool('1000000000000000000000', '1000000000000000000000', '1000000000000000000').

main :-
    (   modules_ready(math, [u256])
    ->  true
    ;   skip('(the math modules would not build -- no sbcl or CICILI checkout)')
    ),
    ( have_module(u256) -> checks ; true ).

checks :-
    max(MAX),

    section('the reason this module exists'),
    %% NOT A STRAW MAN: this is cocolog's own arithmetic, asked for the
    %% first product a swap computes, answering a number that is not it.
    iso('cocolog\'s 64-bit is/2 wraps, silently',
        ( X is 1000000000000000000 * 997, want(X, 875820019684212736) )),
    iso('u256 gets it right',
        ( use_module(library(u256)),
          u256_mul('1000000000000000000', 997, X),
          want(X, '997000000000000000000') )),

    section('the four operations, and their refusals'),
    iso('add', ( use_module(library(u256)),
                 u256_add(MAX, 0, X), want(X, MAX) )),
    iso('add past the top raises',
        ( use_module(library(u256)),
          raises(u256_add(MAX, 1, _), K), want(K, cocolog_error('u256 overflow: the sum is above 2^256-1')) )),
    iso('sub', ( use_module(library(u256)),
                 u256_sub(1000, 1, X), want(X, '999') )),
    iso('sub below zero raises',
        ( use_module(library(u256)),
          raises(u256_sub(0, 1, _), K), want(K, cocolog_error('u256 underflow: the difference is below zero')) )),
    iso('mul past the top raises',
        ( use_module(library(u256)),
          raises(u256_mul(MAX, 2, _), K),
          want(K, cocolog_error('u256 overflow: the product is above 2^256-1')) )),
    iso('div is the floor', ( use_module(library(u256)),
                              u256_div(7, 2, X), want(X, '3') )),
    iso('mod', ( use_module(library(u256)), u256_mod(7, 2, X), want(X, '1') )),
    iso('div by zero raises',
        ( use_module(library(u256)),
          raises(u256_div(5, 0, _), K),
          want(K, cocolog_error('u256 division by zero: the divisor is zero')) )),

    section('muldiv: the product is never narrowed'),
    %% 2^255 * 4 / 8. The intermediate is 2^257 -- two bits wider than the
    %% type -- and the answer is 2^254, which fits comfortably. A muldiv
    %% that multiplied first and stored the result would be wrong here,
    %% and this is exactly the shape every AMM price has.
    iso('muldiv: 2^255*4/8 = 2^254, middle 2^257',
        ( use_module(library(u256)),
          u256_muldiv('57896044618658097711785492504343953926634992332820282019728792003956564819968',
                      4, 8, X),
          want(X, '28948022309329048855892746252171976963317496166410141009864396001978282409984') )),
    iso('muldiv quotient too wide raises',
        ( use_module(library(u256)),
          raises(u256_muldiv(MAX, MAX, 1, _), K),
          want(K, cocolog_error('u256 overflow: the quotient is above 2^256-1')) )),

    section('the square root, floored exactly'),
    iso('sqrt(0)', ( use_module(library(u256)), u256_sqrt(0, X), want(X, '0') )),
    iso('sqrt(1)', ( use_module(library(u256)), u256_sqrt(1, X), want(X, '1') )),
    iso('sqrt(10^36) is 10^18 exactly',
        ( use_module(library(u256)),
          u256_sqrt('1000000000000000000000000000000000000', X),
          want(X, '1000000000000000000') )),
    iso('sqrt(10^36 - 1) is one less',
        ( use_module(library(u256)),
          u256_sqrt('999999999999999999999999999999999999', X),
          want(X, '999999999999999999') )),
    iso('sqrt(2^256-1) is 2^128-1',
        ( use_module(library(u256)),
          u256_sqrt(MAX, X), want(X, '340282366920938463463374607431768211455') )),

    section('how a number is spelled'),
    iso('the top of the range round-trips',
        ( use_module(library(u256)), u256_dec(MAX, X), want(X, MAX) )),
    iso('hex in, decimal out',
        ( use_module(library(u256)), u256_dec('0xff', X), want(X, '255') )),
    iso('decimal in, hex out',
        ( use_module(library(u256)), u256_hex(255, X),
          want(X, '00000000000000000000000000000000000000000000000000000000000000ff') )),
    iso('hex and decimal agree at the top',
        ( use_module(library(u256)), u256_hex(MAX, X),
          want(X, 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff') )),
    iso('an integer comes back an integer',
        ( use_module(library(u256)), u256_int('42', X), want(X, 42) )),
    iso('2^64 will not fit one, and says so',
        ( use_module(library(u256)),
          raises(u256_int('18446744073709551616', _), K),
          want(K, cocolog_error('u256 does not fit an integer: above 2^63-1, so it would wrap')) )),
    iso('cmp <', ( use_module(library(u256)), u256_cmp(1, 2, X), want(X, <) )),
    iso('cmp =', ( use_module(library(u256)), u256_cmp(MAX, MAX, X), want(X, =) )),
    iso('cmp > across the 64-bit line',
        ( use_module(library(u256)),
          u256_cmp('18446744073709551616', '18446744073709551615', X), want(X, >) )),

    section('and it adds up to Uniswap'),
    %% getAmountOut, at the scale a real pool holds: one token into a
    %% thousand-for-a-thousand pool, 0.3% fee. 996006981039903216 is not
    %% this repository's number -- it is what the formula pays, and it is
    %% quoted wherever the formula is explained.
    iso('v2 getAmountOut at pool scale',
        ( use_module(library(u256)), pool(Rin, Rout, Ain),
          u256_mul(Ain, 997, F),
          u256_mul(Rin, 1000, T), u256_add(T, F, Den),
          u256_muldiv(F, Rout, Den, Out),
          want(Out, '996006981039903216') )),
    %% And back the other way: the input needed for that exact output is
    %% the input we started with. A formula that is not its own inverse
    %% here leaks value on every round trip.
    iso('v2 getAmountIn returns the input',
        ( use_module(library(u256)), pool(Rin, Rout, _),
          Out = '996006981039903216',
          u256_muldiv(Rin, Out, 1, N0), u256_mul(N0, 1000, N),
          u256_sub(Rout, Out, R2), u256_mul(R2, 997, D2),
          u256_div(N, D2, Q), u256_add(Q, 1, Ain2),
          want(Ain2, '1000000000000000000') )),
    %% The invariant, which is the only thing a pool really promises:
    %% after a swap the product of the reserves has GROWN, and the growth
    %% is the fee.
    iso('k grows across the swap -- that is the fee',
        ( use_module(library(u256)), pool(Rin, Rout, Ain),
          Out = '996006981039903216',
          u256_add(Rin, Ain, R1), u256_sub(Rout, Out, R2),
          u256_mul(R1, R2, K1), u256_mul(Rin, Rout, K0),
          u256_cmp(K1, K0, C), want(C, >) )),

    nl, checks_done.
