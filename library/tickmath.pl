%% library(tickmath) -- prices as ticks, and ticks as square roots.
%%
%% The arithmetic a CONCENTRATED-LIQUIDITY exchange is built on, and it
%% is a library rather than a contract because it holds nothing: every
%% predicate here is a pure function of its arguments, usable by any
%% protocol that prices in ranges.
%%
%%   tm_sqrt_ratio_at_tick(+Tick, -SqrtPriceX96)
%%   tm_amount0_delta(+SqrtA, +SqrtB, +Liquidity, -Amount0)
%%   tm_amount1_delta(+SqrtA, +SqrtB, +Liquidity, -Amount1)
%%   tm_min_tick(-T)  tm_max_tick(-T)
%%   tm_min_sqrt_ratio(-R)  tm_max_sqrt_ratio(-R)  tm_q96(-Q)
%%
%% WHY A PRICE IS A TICK. A pool that concentrates liquidity has to name
%% the ENDS of a range, and naming them as prices means storing a real
%% number nobody can agree on. So the price axis is cut into ticks at
%% 1.0001 apart -- one basis point each -- and a range is two integers.
%% Tick t means price 1.0001^t, and every position, every fee boundary
%% and every crossing is an integer comparison rather than a float.
%%
%% AND WHY THE SQUARE ROOT. The pool stores sqrt(price), not price,
%% because every quantity a swap computes is linear in sqrt(price):
%% amount1 = L * (sqrtB - sqrtA) and amount0 = L * (1/sqrtA - 1/sqrtB).
%% Storing the price itself would put a square root in the middle of
%% every swap, and an integer square root is both slow and lossy. Stored
%% as sqrt, the swap is subtraction.
%%
%% Q64.96 IS THE FORMAT. sqrt(price) is a fraction, and the pool keeps
%% it as a 160-bit fixed-point number with 96 fractional bits: the value
%% is `SqrtPriceX96 / 2^96'. Tick 0 is price 1, so its ratio is exactly
%% 2^96 = 79228162514264337593543950336, and that constant is the first
%% thing the suite checks.
%%
%% HOW THE POWER IS TAKEN, and it is not by exponentiation. 1.0001^t for
%% t up to 887272 cannot be computed by repeated multiplication without
%% either a float or a hundred thousand rounds. Uniswap's answer is a
%% BINARY DECOMPOSITION: |t| is written in binary, and for each set bit
%% there is a precomputed constant equal to 1.0001^(that power of two),
%% in Q128. Twenty constants, twenty conditional multiplies, and the
%% error is bounded well below one tick. THE CONSTANTS BELOW ARE
%% UNISWAP'S OWN, copied digit for digit from TickMath.sol -- they are
%% not derived here, and the suite pins the two endpoints against the
%% values that library publishes: MIN_SQRT_RATIO 4295128739 and
%% MAX_SQRT_RATIO 1461446703485210103287273052203988822378723970342.
%%
%% A NEGATIVE TICK IS THE RECIPROCAL, which is why the decomposition is
%% done on |t| and inverted at the end for positive t rather than the
%% other way about: the constants are all just below 1, so multiplying
%% them keeps every intermediate inside Q128 and nothing has to be
%% renormalised on the way.
%%
%% THE TICK ITSELF IS AN ORDINARY INTEGER, and deliberately so. It is at
%% most 887272, it indexes and it counts, and `is/2' is honest 64-bit
%% work for that. Everything that is a PRICE or an AMOUNT is u256 --
%% see contracts/dex/uniswap.pl on why money has a type.

:- use_module(library(u256)).

%% The ends of the axis. Beyond these the ratio leaves the 160 bits the
%% format has, so a tick outside them is not a price at all.
tm_min_tick(-887272).
tm_max_tick(887272).

%% Uniswap's own published endpoints -- what the suite checks against.
tm_min_sqrt_ratio('4295128739').
tm_max_sqrt_ratio('1461446703485210103287273052203988822378723970342').

tm_q96('79228162514264337593543950336').            % 2^96
tm_q128('340282366920938463463374607431768211456'). % 2^128
tm_q32('4294967296').                               % 2^32
tm_u256_max('115792089237316195423570985008687907853269984665640564039457584007913129639935').

%% ---- the constants, from TickMath.sol ---------------------------------
%%
%% Each is 1.0001^(bit/2) in Q128 -- the square root already taken, which
%% is why the answer is a sqrt ratio and no root is ever computed here.
%% The bit for 0x1 is not in this table: it is the STARTING value, since
%% a decomposition has to begin at either 1.0001^(1/2) or 1.
tm_const(     2, '0xfff97272373d413259a46990580e213a').
tm_const(     4, '0xfff2e50f5f656932ef12357cf3c7fdcc').
tm_const(     8, '0xffe5caca7e10e4e61c3624eaa0941cd0').
tm_const(    16, '0xffcb9843d60f6159c9db58835c926644').
tm_const(    32, '0xff973b41fa98c081472e6896dfb254c0').
tm_const(    64, '0xff2ea16466c96a3843ec78b326b52861').
tm_const(   128, '0xfe5dee046a99a2a811c461f1969c3053').
tm_const(   256, '0xfcbe86c7900a88aedcffc83b479aa3a4').
tm_const(   512, '0xf987a7253ac413176f2b074cf7815e54').
tm_const(  1024, '0xf3392b0822b70005940c7a398e4b70f3').
tm_const(  2048, '0xe7159475a2c29b7443b29c7fa6e889d9').
tm_const(  4096, '0xd097f3bdfd2022b8845ad8f792aa5825').
tm_const(  8192, '0xa9f746462d870fdf8a65dc1f90e061e5').
tm_const( 16384, '0x70d869a156d2a1b890bb3df62baf32f7').
tm_const( 32768, '0x31be135f97d08fd981231505542fcfa6').
tm_const( 65536, '0x9aa508b5b7a84e1c677de54f3e99bc9').
tm_const(131072, '0x5d6af8dedb81196699c329225ee604').
tm_const(262144, '0x2216e584f5fa1ea926041bedfe98').
tm_const(524288, '0x48a170391f7dc42444e8fa2').

%% ---- the tick, as a square root of a price ----------------------------

tm_sqrt_ratio_at_tick(Tick, Sqrt) :-
    integer(Tick),
    tm_min_tick(Lo), tm_max_tick(Hi),
    Tick >= Lo, Tick =< Hi,
    Abs is abs(Tick),
    %% the bit for 1: either 1.0001^(1/2) in Q128, or exactly 1 in Q128
    (   1 is Abs mod 2
    ->  Start = '0xfffcb933bd6fad37aa2d162d1a594001'
    ;   tm_q128(Start)
    ),
    u256_dec(Start, R0),
    findall(B-C, tm_const(B, C), Table),
    tm_apply(Table, Abs, R0, R1),
    %% A POSITIVE tick is the reciprocal of what was just built, because
    %% the decomposition was done on |t| with constants below one.
    (   Tick > 0
    ->  tm_u256_max(Max), u256_div(Max, R1, R2)
    ;   R2 = R1
    ),
    %% Q128 down to Q96, ROUNDING UP -- a ratio rounded down would let a
    %% position claim a price fractionally better than the tick it named.
    tm_q32(Q32),
    u256_div(R2, Q32, Q),
    u256_mod(R2, Q32, Rem),
    (   u256_cmp(Rem, '0', '=')
    ->  Sqrt = Q
    ;   u256_add(Q, '1', Sqrt)
    ).

%% One conditional multiply per set bit: ratio = ratio * C / 2^128. The
%% product is up to 2^256 and fits exactly, which is why the constants
%% are Q128 and not something wider.
tm_apply([], _, R, R).
tm_apply([B-C|T], Abs, R0, R) :-
    (   1 is (Abs // B) mod 2
    ->  u256_mul(R0, C, P),
        tm_q128(Q128),
        u256_div(P, Q128, R1)
    ;   R1 = R0
    ),
    tm_apply(T, Abs, R1, R).

%% ---- what a range of liquidity is worth -------------------------------
%%
%% A position of size L between sqrtA and sqrtB holds
%%
%%   amount0 = L * (sqrtB - sqrtA) / (sqrtA * sqrtB)   -- in token0
%%   amount1 = L * (sqrtB - sqrtA)                     -- in token1
%%
%% both scaled by Q96, and BOTH ARE WHY u256_muldiv/4 EXISTS. `L << 96'
%% times a price difference overflows 256 bits routinely at real
%% liquidity, while the quotient is an ordinary token amount -- so the
%% product is kept at its true 512-bit width and divided from there.
%% Doing it as multiply-then-divide would revert on pools that work.
tm_amount0_delta(SqrtA0, SqrtB0, Liquidity, Amount0) :-
    tm_order(SqrtA0, SqrtB0, SqrtA, SqrtB),
    u256_cmp(SqrtA, '0', '>'),
    tm_q96(Q96),
    u256_mul(Liquidity, Q96, Numerator1),
    u256_sub(SqrtB, SqrtA, Numerator2),
    u256_muldiv(Numerator1, Numerator2, SqrtB, Inner),
    u256_div(Inner, SqrtA, Amount0).

tm_amount1_delta(SqrtA0, SqrtB0, Liquidity, Amount1) :-
    tm_order(SqrtA0, SqrtB0, SqrtA, SqrtB),
    u256_sub(SqrtB, SqrtA, Diff),
    tm_q96(Q96),
    u256_muldiv(Liquidity, Diff, Q96, Amount1).

%% The two ends may arrive either way round; the formulas want the
%% smaller first, and a caller who had them backwards meant the range
%% rather than a negative amount.
tm_order(A, B, A, B) :- \+ u256_cmp(A, B, '>'), !.
tm_order(A, B, B, A).

%% ---- rounding, and which way it has to fall ---------------------------
%%
%% A swap that CROSSES ticks computes many small legs, and a rounding
%% that favoured the trader on each one would let a large trade split
%% into small ones and take the difference. So the input a leg needs is
%% rounded UP and the output it pays is rounded DOWN -- every fraction
%% goes to the pool, exactly as Uniswap rounds, and the direction is the
%% reason a leg is never worth splitting.

tm_div_up(A, B, Q) :-
    u256_div(A, B, Q0),
    u256_mod(A, B, R),
    (   u256_cmp(R, '0', '=') -> Q = Q0 ; u256_add(Q0, '1', Q) ).

tm_amount0_delta_up(SqrtA0, SqrtB0, Liquidity, Amount0) :-
    tm_order(SqrtA0, SqrtB0, SqrtA, SqrtB),
    u256_cmp(SqrtA, '0', '>'),
    tm_q96(Q96),
    u256_mul(Liquidity, Q96, Numerator1),
    u256_sub(SqrtB, SqrtA, Numerator2),
    %% muldiv keeps the 512-bit middle; the rounding is applied to the
    %% quotient of each division rather than at the end, because the two
    %% divisions each drop a fraction.
    u256_muldiv(Numerator1, Numerator2, SqrtB, Inner0),
    u256_mul(Numerator1, Numerator2, Wide),
    u256_mod(Wide, SqrtB, Rem1),
    (   u256_cmp(Rem1, '0', '=') -> Inner = Inner0 ; u256_add(Inner0, '1', Inner) ),
    tm_div_up(Inner, SqrtA, Amount0).

tm_amount1_delta_up(SqrtA0, SqrtB0, Liquidity, Amount1) :-
    tm_order(SqrtA0, SqrtB0, SqrtA, SqrtB),
    u256_sub(SqrtB, SqrtA, Diff),
    tm_q96(Q96),
    u256_mul(Liquidity, Diff, Wide),
    tm_div_up(Wide, Q96, Amount1).

%% ---- where a price lands, given what is put in ------------------------
%%
%% Token0 in pushes the price DOWN:
%%
%%   sqrtP' = (L * Q96 * sqrtP) / (L * Q96 + amountIn * sqrtP)
%%
%% rounded UP, so the price does not fall further than it was paid for.
%% The product in the denominator can overflow a word at extreme sizes;
%% Uniswap falls back to a division-first form there, and so does this.
tm_next_sqrt_down(Sqrt, Liquidity, AmountIn, Next) :-
    tm_q96(Q96),
    u256_mul(Liquidity, Q96, Numerator1),
    (   catch(( u256_mul(AmountIn, Sqrt, Product),
                u256_add(Numerator1, Product, Denominator) ),
              _, fail)
    ->  u256_muldiv(Numerator1, Sqrt, Denominator, N0),
        u256_mul(Numerator1, Sqrt, Wide),
        u256_mod(Wide, Denominator, Rem),
        (   u256_cmp(Rem, '0', '=') -> Next = N0 ; u256_add(N0, '1', Next) )
    ;   %% the fallback: divide first, which cannot overflow
        u256_div(Numerator1, Sqrt, Q),
        u256_add(Q, AmountIn, D),
        tm_div_up(Numerator1, D, Next)
    ).

%% Token1 in pushes the price UP, and this one is a plain addition:
%%
%%   sqrtP' = sqrtP + amountIn * Q96 / L
%%
%% rounded DOWN, for the same reason the other is rounded up -- the
%% fraction stays with the pool either way.
tm_next_sqrt_up(Sqrt, Liquidity, AmountIn, Next) :-
    tm_q96(Q96),
    u256_muldiv(AmountIn, Q96, Liquidity, Delta),
    u256_add(Sqrt, Delta, Next).
