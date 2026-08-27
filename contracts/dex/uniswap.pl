%% contracts/dex/uniswap -- Uniswap v2, as rules over 256-bit money.
%%
%% A CONTRACT, NOT A LIBRARY, which is why it lives here and not under
%% library/. A library is machinery The Coco offers -- the fence, the
%% money type, the encodings -- and anything may load one by name. This
%% holds state, it is a thing deployed on a chain, and it is reached by
%% PATH: a node should not be able to pick up a pool by name without
%% having been given it.
%%
%%   uni_create(+T0, +T1)                     a pool, empty
%%   uni_account(+T0, +T1, -Account)          the pool's own account
%%   uni_lp_token(+T0, +T1, -LpToken)         the share, which is a token
%%   uni_reserves(+T0, +T1, -R0, -R1)         what it thinks it holds
%%   uni_balances(+T0, +T1, -B0, -B1)         what it actually holds
%%   uni_supply(+T0, +T1, -Total)             LP tokens outstanding
%%   uni_mint(+T0, +T1, +Who, +A0, +A1, -Liquidity)
%%   uni_burn(+T0, +T1, +Who, +Liquidity, -A0, -A1)
%%   uni_swap(+TIn, +TOut, +Who, +AmountIn, -AmountOut)
%%   uni_sync(+T0, +T1)      uni_skim(+T0, +T1, +To)   uni_backed(+T0, +T1)
%%   uni_amount_out(+AmountIn, +RIn, +ROut, -AmountOut)    the quote, pure
%%   uni_amount_in(+AmountOut, +RIn, +ROut, -AmountIn)     and its inverse
%%   uni_k(+T0, +T1, -K)                      the invariant, as a number
%%
%% THE WHOLE THING IS THE INVARIANT. A constant-product pool promises
%% one thing: x*y does not go down. Everything else -- the price, the
%% slippage, the fee, the depth -- is a consequence of that sentence, and
%% `uni_swap/4' REFUSES any swap that would break it rather than trusting
%% the formula that produced the number. The formula is right; the check
%% is what makes it checkable by someone who does not believe the
%% formula, which is the only kind of check worth having on a chain.
%%
%% ARITHMETIC IS library(u256), NEVER `is/2'. This is not a stylistic
%% preference. cocolog's integers are 64 bits and they wrap in silence:
%%
%%     ?- X is 1000000000000000000 * 997.
%%     X = 875820019684212736.
%%
%% That is the FIRST product a swap computes, at the scale every ERC-20
%% token uses (one token is 10^18), and it is simply not the answer. A
%% pool built on `is/2' would quote wrong prices confidently and its
%% invariant check would pass on the wrong numbers. So every amount here
%% is an atom of decimal digits and every operation is a u256 one.
%%
%% u256 IS THE TYPE MONEY IS WRITTEN IN, throughout The Coco -- balances,
%% prices, amounts, and whatever a contract holds. It is 256 bits wide
%% because that is what the chains this hub reads are, and NOTHING IN IT
%% WRAPS: an operation that cannot represent its answer raises, the way
%% Solidity 0.8 made overflow revert. A refused transaction is a fact; a
%% wrapped balance is a lie that spends. (cocolog's own library(bigint)
%% is arbitrary precision and is the right tool for arithmetic that is
%% not money -- it has no ceiling, which is exactly what money needs.)
%%
%% AMOUNTS ARE ATOMS. '1000000000000000000' is one token. Small numbers
%% may be written as plain integers -- u256 takes either -- but what
%% comes back is always an atom, because that is the only spelling that
%% survives the range.
%%
%% WHAT IS FAITHFUL TO v2 AND WHAT IS NOT. The fee is 0.3%, taken on the
%% way in, exactly as v2 takes it: 997/1000 of the input joins the pool
%% and the whole input stays. The first deposit mints sqrt(a0*a1) minus
%% MINIMUM_LIQUIDITY, and those 1000 units are burned to nobody, so a
%% pool can never be emptied to the point where one unit of liquidity is
%% worth the entire reserve -- the donation attack v2 closed this way.
%% Later deposits mint the SMALLER of the two proportional shares, which
%% is what makes depositing off-ratio cost the depositor rather than
%% everyone else.
%%
%% THE POOL IS AN ACCOUNT, AND THE TOKENS ARE REAL. A swap does not
%% adjust two numbers: it MOVES BALANCES in
%% contracts/token/fungible.pl, from the trader to the pool and back
%% again, and it can only move what the trader actually has. So a trade
%% that could not be paid for fails at the ledger rather than at a
%% bookkeeping check, which is where it fails on a chain.
%%
%% AND THE SHARE IS A TOKEN TOO. A Uniswap v2 pair IS an ERC-20 -- the
%% LP share is fungible, transferable, and poolable in turn -- so the
%% share here is a fungible token like any other, and `uni_supply/3' is
%% simply its total supply rather than a number this file keeps. One
%% fact, one place.
%%
%% WHICH MAKES THE RESERVES A CACHE, exactly as they are in v2. The pool
%% stores reserve0 and reserve1, but the truth is the pool account's
%% BALANCE, and the two can differ: anyone may send tokens to a pool
%% without trading. That is why v2 has `sync' (believe the balances) and
%% `skim' (give the excess away), and why both are here. `uni_backed/2'
%% is the invariant that matters -- the balances are never LESS than the
%% reserves -- because a pool that had promised more than it held would
%% be insolvent, and no amount of correct swap arithmetic would fix it.
%%
%% What is not here: the protocol fee (v2's feeTo, off by default and
%% off here), the price accumulators for the TWAP oracle, flash swaps,
%% and the periphery's router. Those are additions to this, not
%% corrections of it.

:- use_module(library(u256)).

%% The pool holds real balances, and its share is a real token: both
%% come from contracts/token/fungible.pl, which must be loaded beside
%% this file.

:- dynamic uni_pool/4.          % uni_pool(T0, T1, R0, R1) -- a CACHE

%% MINIMUM_LIQUIDITY, v2's own constant.
uni_minimum_liquidity('1000').

%% AND v2's OTHER CONSTANT, which is the one that makes the arithmetic
%% safe rather than lucky. A v2 reserve is a uint112, and `_update'
%% reverts with OVERFLOW if a balance will not fit one. That is not
%% frugality: with both reserves under 2^112, every product this file
%% takes stays under 2^224 and cannot overflow a 256-bit word at all.
%% The ceiling is the proof, so it is enforced here too.
uni_max_reserve('5192296858534827628530496329220095').   % 2^112 - 1

uni_fits_reserve(R) :-
    uni_max_reserve(Max),
    \+ u256_cmp(R, Max, '>').

%% ---- the pair --------------------------------------------------------
%%
%% A pair is UNORDERED, and stored under the sorted order, so that
%% `uni_swap(dai, weth, ...)' and `uni_swap(weth, dai, ...)' reach the
%% same pool. v2 does this by address; here by the standard order of
%% terms, which is the same idea and needs no addresses.
uni_key(A, B, A, B) :- A @< B, !.
uni_key(A, B, B, A).

%% The pool's own account in the token ledger, and the token its shares
%% are. Both are derived from the pair, so nothing has to be remembered.
uni_account(A, B, pool(T0, T1)) :- uni_key(A, B, T0, T1).
uni_lp_token(A, B, lp(T0, T1))  :- uni_key(A, B, T0, T1).

uni_create(A, B) :-
    uni_key(A, B, T0, T1),
    \+ uni_pool(T0, T1, _, _),
    assertz(uni_pool(T0, T1, '0', '0')),
    uni_lp_token(T0, T1, Lp),
    ft_create(Lp, 'UNI-V2', 18).

uni_reserves(A, B, R0, R1) :-
    uni_key(A, B, T0, T1),
    uni_pool(T0, T1, R0, R1).

%% The supply of the share token: not a number this file keeps.
uni_supply(A, B, Total) :-
    uni_lp_token(A, B, Lp),
    ft_total(Lp, Total).

%% What the pool ACTUALLY holds, as opposed to what it believes.
uni_balances(A, B, B0, B1) :-
    uni_key(A, B, T0, T1),
    uni_account(T0, T1, Acct),
    ft_balance(T0, Acct, B0),
    ft_balance(T1, Acct, B1).

%% THE SOLVENCY INVARIANT: never less than promised. Anyone may send a
%% pool tokens, so more is ordinary; less would mean the pool had
%% promised what it does not hold.
uni_backed(A, B) :-
    uni_reserves(A, B, R0, R1),
    uni_balances(A, B, B0, B1),
    \+ u256_cmp(B0, R0, '<'),
    \+ u256_cmp(B1, R1, '<').

%% v2's own two answers to a donation. `sync' believes the balances;
%% `skim' hands the difference to whoever asks and leaves the reserves
%% alone.
uni_sync(A, B) :-
    uni_key(A, B, T0, T1),
    uni_balances(T0, T1, B0, B1),
    uni_set_reserves(T0, T1, B0, B1).

uni_skim(A, B, To) :-
    uni_key(A, B, T0, T1),
    uni_account(T0, T1, Acct),
    uni_reserves(T0, T1, R0, R1),
    uni_balances(T0, T1, B0, B1),
    u256_sub(B0, R0, X0),
    u256_sub(B1, R1, X1),
    ( u256_cmp(X0, '0', '>') -> ft_transfer(T0, Acct, To, X0) ; true ),
    ( u256_cmp(X1, '0', '>') -> ft_transfer(T1, Acct, To, X1) ; true ).

uni_k(A, B, K) :-
    uni_reserves(A, B, R0, R1),
    u256_mul(R0, R1, K).

uni_set_reserves(T0, T1, R0, R1) :-
    retract(uni_pool(T0, T1, _, _)),
    assertz(uni_pool(T0, T1, R0, R1)).

%% ---- the quote, which is pure ---------------------------------------
%%
%% amountOut = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997)
%%
%% Written exactly as v2 writes it, including WHERE THE FLOOR FALLS.
%% Integer division truncates, and the truncation always favours the
%% pool -- which is why the invariant holds strictly rather than by
%% luck, and why a formula rearranged to look tidier is a different
%% formula.
uni_amount_out(AmountIn, RIn, ROut, AmountOut) :-
    u256_cmp(AmountIn, '0', '>'),
    u256_cmp(RIn, '0', '>'),
    u256_cmp(ROut, '0', '>'),
    u256_mul(AmountIn, '997', WithFee),
    u256_mul(WithFee, ROut, Numerator),
    u256_mul(RIn, '1000', Scaled),
    u256_add(Scaled, WithFee, Denominator),
    u256_div(Numerator, Denominator, AmountOut).

%% The other direction: what must go in for a wanted output. The `+1' is
%% v2's, and it is not a rounding error -- it is the pool refusing to be
%% short-changed by the division that truncated.
uni_amount_in(AmountOut, RIn, ROut, AmountIn) :-
    u256_cmp(AmountOut, '0', '>'),
    u256_cmp(ROut, AmountOut, '>'),
    u256_mul(RIn, AmountOut, N0),
    u256_mul(N0, '1000', Numerator),
    u256_sub(ROut, AmountOut, Left),
    u256_mul(Left, '997', Denominator),
    u256_div(Numerator, Denominator, Q),
    u256_add(Q, '1', AmountIn).

%% ---- swapping --------------------------------------------------------
%%
%% The quote is computed, the reserves are moved, AND THEN THE INVARIANT
%% IS CHECKED AGAINST THE NUMBERS THAT ACTUALLY LANDED. If k went down
%% the swap does not happen -- no state is written, because the write is
%% the last thing and a failed check never reaches it.
uni_swap(TIn, TOut, Who, AmountIn, AmountOut) :-
    uni_key(TIn, TOut, T0, T1),
    uni_pool(T0, T1, R0, R1),
    (   TIn == T0
    ->  RIn = R0, ROut = R1
    ;   RIn = R1, ROut = R0
    ),
    uni_amount_out(AmountIn, RIn, ROut, AmountOut),
    u256_cmp(ROut, AmountOut, '>'),
    u256_add(RIn, AmountIn, RIn2),
    u256_sub(ROut, AmountOut, ROut2),
    %% k, before and after, on the reserves themselves
    u256_mul(RIn, ROut, KBefore),
    u256_mul(RIn2, ROut2, KAfter),
    \+ u256_cmp(KAfter, KBefore, '<'),
    uni_fits_reserve(RIn2),
    %% THE MONEY MOVES, and it moves before the reserves are believed:
    %% the trader pays first, out of a balance they must actually have,
    %% and the pool pays out of its own. A trade nobody could fund fails
    %% at the ledger, which is where it fails on a chain.
    uni_account(T0, T1, Acct),
    ft_transfer(TIn, Who, Acct, AmountIn),
    ft_transfer(TOut, Acct, Who, AmountOut),
    (   TIn == T0
    ->  uni_set_reserves(T0, T1, RIn2, ROut2)
    ;   uni_set_reserves(T0, T1, ROut2, RIn2)
    ).

%% ---- liquidity -------------------------------------------------------
%%
%% The first deposit sets the price, so there is no ratio to hold it to
%% and the share is the geometric mean of what arrived. MINIMUM_LIQUIDITY
%% is subtracted from what the depositor gets and added to the supply
%% anyway -- burned to nobody. That is v2's answer to the donation
%% attack: with a permanent thousand units outstanding, the value of one
%% unit of liquidity cannot be inflated by emptying the pool.
uni_mint(A, B, Who, A0, A1, Liquidity) :-
    uni_key(A, B, T0, T1),
    uni_pool(T0, T1, R0, R1),
    uni_supply(T0, T1, Total),
    (   A == T0 -> Amt0 = A0, Amt1 = A1 ; Amt0 = A1, Amt1 = A0 ),
    u256_cmp(Amt0, '0', '>'),
    u256_cmp(Amt1, '0', '>'),
    uni_lp_token(T0, T1, Lp),
    (   u256_cmp(Total, '0', '=')
    ->  uni_minimum_liquidity(Min),
        u256_mul(Amt0, Amt1, Product),
        u256_sqrt(Product, Root),
        u256_cmp(Root, Min, '>'),
        u256_sub(Root, Min, Liquidity),
        %% MINIMUM_LIQUIDITY is minted to an account nobody holds the
        %% key to. v2 sends it to address zero; here it goes to `zero'
        %% and stays there, which is what makes it unrecoverable and
        %% therefore what makes the donation attack cost more than it
        %% can win.
        ft_mint(Lp, zero, Min)
    ;   u256_mul(Amt0, Total, X0), u256_div(X0, R0, L0),
        u256_mul(Amt1, Total, X1), u256_div(X1, R1, L1),
        (   u256_cmp(L0, L1, '<') -> Liquidity = L0 ; Liquidity = L1 ),
        u256_cmp(Liquidity, '0', '>')
    ),
    u256_add(R0, Amt0, NR0),
    u256_add(R1, Amt1, NR1),
    uni_fits_reserve(NR0),
    uni_fits_reserve(NR1),
    %% the deposit is a real transfer, and the share a real token
    uni_account(T0, T1, Acct),
    ft_transfer(T0, Who, Acct, Amt0),
    ft_transfer(T1, Who, Acct, Amt1),
    ft_mint(Lp, Who, Liquidity),
    uni_set_reserves(T0, T1, NR0, NR1).

%% And back out, in proportion. The division floors, so what comes out
%% is never more than the share is worth -- the remainder stays with the
%% pool, which is where every rounding in this file goes.
uni_burn(A, B, Who, Liquidity, Out0, Out1) :-
    uni_key(A, B, T0, T1),
    uni_pool(T0, T1, R0, R1),
    uni_supply(T0, T1, Total),
    u256_cmp(Liquidity, '0', '>'),
    \+ u256_cmp(Liquidity, Total, '>'),
    u256_mul(Liquidity, R0, P0), u256_div(P0, Total, B0),
    u256_mul(Liquidity, R1, P1), u256_div(P1, Total, B1),
    u256_sub(R0, B0, NR0),
    u256_sub(R1, B1, NR1),
    %% the share is burned out of the holder's own balance, so only what
    %% they hold can be redeemed -- the ledger enforces it, not a check
    uni_lp_token(T0, T1, Lp),
    ft_burn(Lp, Who, Liquidity),
    uni_account(T0, T1, Acct),
    ft_transfer(T0, Acct, Who, B0),
    ft_transfer(T1, Acct, Who, B1),
    uni_set_reserves(T0, T1, NR0, NR1),
    (   A == T0 -> Out0 = B0, Out1 = B1 ; Out0 = B1, Out1 = B0 ).
