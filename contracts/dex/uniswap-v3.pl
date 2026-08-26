%% contracts/dex/uniswap-v3 -- concentrated liquidity: crossing ticks,
%% and fees that belong to the ranges that earned them.
%%
%%   v3_create(+Pool, +Token0, +Token1, +FeePips, +Tick)
%%   v3_state(+Pool, -SqrtPriceX96, -Tick, -Liquidity)
%%   v3_mint(+Pool, +Owner, +Lower, +Upper, +Liquidity, -Id, -Amount0, -Amount1)
%%   v3_position(+Id, -Pool, -Owner, -Lower, -Upper, -Liquidity)
%%   v3_account(+Pool, -Account)   v3_backed(+Pool)
%%   v3_swap(+Pool, +Who, +TokenIn, +AmountIn, -AmountOut, -Unspent)
%%   v3_fees_owed(+Id, -Owed0, -Owed1)     v3_collect(+Id, +Caller, -F0, -F1)
%%   v3_burn(+Pool, +Caller, +Id, -Amount0, -Amount1, -Fees0, -Fees1)
%%   v3_fee_growth_inside(+Pool, +Lower, +Upper, -Inside0, -Inside1)
%%
%% WHAT v3 IS FOR. A v2 position is spread from zero to infinity and
%% almost all of it is never used. v3 lets a provider name a RANGE and
%% put their whole capital inside it, so the same money is many times
%% deeper where the trading is -- and idle, one-sided, outside it.
%%
%% A POSITION IS AN NFT because two providers in one v3 pool own
%% DIFFERENT things: different ranges, different fee exposure. A share
%% cannot be a balance, so it is an object with an identity, minted from
%% contracts/token/nonfungible.pl exactly as Uniswap's periphery does.
%%
%% ---- CROSSING A TICK ---------------------------------------------------
%%
%% This is what makes a range a range. A swap does not move the price in
%% one step: it walks, and at every initialised tick the liquidity
%% CHANGES, because that is where somebody's range begins or ends. So a
%% trade is a sequence of legs, each priced against the depth that
%% actually exists over that stretch, and a large trade genuinely gets a
%% worse price than a small one -- not by a fudge factor but because it
%% eats through ranges.
%%
%% A tick remembers the liquidity that STARTS there and the liquidity
%% that ENDS there, as two unsigned numbers rather than one signed one.
%% Crossing upward adds the first and subtracts the second; crossing
%% downward does the reverse. Keeping them apart is not squeamishness
%% about signs: money is u256 here and u256 has no negatives, and a
%% "net liquidity" that had to be signed would be the one number in this
%% file that could not be a balance.
%%
%% ---- FEE GROWTH --------------------------------------------------------
%%
%% The hard part, and the reason v3's accounting looks strange. A fee is
%% earned by whoever was IN RANGE when the trade happened, and positions
%% come and go -- so the pool cannot credit positions as it swaps
%% without touching every one of them. Instead it keeps ONE number per
%% token: fees per unit of liquidity, ever, in Q128. A position records
%% that number when it is opened and asks again when it collects; the
%% difference times its liquidity is what it earned. Constant work per
%% swap, exact per position.
%%
%% For a RANGE, the number wanted is fees per unit earned INSIDE it,
%% which is the global total minus what accrued below the range and
%% above it. Each tick therefore remembers the growth on the far side of
%% itself, and flips that memory every time it is crossed -- `outside'
%% means outside relative to the current price, so it changes meaning
%% when the price walks past.
%%
%% AND THE SUBTRACTION IS MODULAR ON PURPOSE. Those differences are
%% taken as unsigned numbers that may pass below zero and come out right
%% anyway, because only the DIFFERENCE of two of them is ever used and
%% that difference is correct modulo 2^256. Solidity gets this by
%% wrapping silently in `unchecked'; u256 refuses to wrap, which is why
%% `v3_sub_wrap/3' exists and is named. It is the one place in The Coco
%% where wrapping is the algorithm rather than a bug, and it is spelled
%% out rather than inherited.
%%
%% THE POOL IS AN ACCOUNT, AND THE TOKENS ARE REAL. Opening a position
%% MOVES the two amounts out of the provider's balance in
%% contracts/token/fungible.pl; a swap moves the input in and the output
%% out; closing and collecting move them back. So a position nobody can
%% fund fails at the ledger, and `v3_backed/1' asks the question that
%% matters afterwards: does the pool actually hold what it has promised?
%%
%% THE SHARE IS STILL AN NFT and not a fungible token, which is the one
%% place v3 differs from v2 in kind rather than degree -- see above.
%%
%% WHAT IS STILL NOT HERE: the protocol fee (Uniswap's feeProtocol, off
%% by default), the TWAP oracle's accumulators, flash swaps, and exact
%% -OUTPUT swaps. A swap that runs out of initialised ticks stops and
%% reports what it could not spend rather than pretending.

:- use_module(library(u256)).
:- use_module(library(tickmath)).
:- use_module(library(lists)).

%% The positions are NFTs and the pool holds real balances, so both
%% contracts/token/nonfungible.pl and contracts/token/fungible.pl must
%% be loaded beside this file.

:- dynamic v3_pool/4.       % v3_pool(Pool, Token0, Token1, FeePips)
:- dynamic v3_price/3.      % v3_price(Pool, SqrtPriceX96, Tick)
:- dynamic v3_liq/2.        % v3_liq(Pool, ActiveLiquidity)
:- dynamic v3_fg/3.         % v3_fg(Pool, FeeGrowthGlobal0, FeeGrowthGlobal1)
:- dynamic v3_tickinfo/6.   % v3_tickinfo(Pool, Tick, Starts, Ends, Outside0, Outside1)
:- dynamic v3_pos/9.        % v3_pos(Id,Pool,Lo,Hi,L, Inside0Last,Inside1Last, Owed0,Owed1)
:- dynamic v3_next_id/2.

v3_fee_tier(500).
v3_fee_tier(3000).
v3_fee_tier(10000).
v3_fee_denominator('1000000').

%% ---- the pool --------------------------------------------------------

%% The pool's own account in the token ledger, wrapped so it cannot
%% collide with a token or a trader of the same name.
v3_account(Pool, pool(Pool)).

%% Does it hold what it owes? Every position's amounts at the current
%% price, plus every position's unclaimed fees, against the balance the
%% pool actually has. More is ordinary -- anyone may send a pool tokens
%% -- and less would mean it had promised what it does not hold.
v3_backed(Pool) :-
    v3_account(Pool, Acct),
    v3_pool(Pool, Token0, Token1, _),
    v3_price(Pool, Sqrt, Tick),
    findall(A0-A1,
            ( v3_pos(Id, Pool, Lo, Hi, L, _, _, _, _),
              v3_amounts(Sqrt, Tick, Lo, Hi, L, P0, P1),
              v3_fees_owed(Id, F0, F1),
              u256_add(P0, F0, A0), u256_add(P1, F1, A1) ),
            Pairs),
    v3_owed_sum(Pairs, '0', '0', Owed0, Owed1),
    ft_balance(Token0, Acct, B0),
    ft_balance(Token1, Acct, B1),
    \+ u256_cmp(B0, Owed0, '<'),
    \+ u256_cmp(B1, Owed1, '<').

v3_owed_sum([], A0, A1, A0, A1).
v3_owed_sum([X0-X1|T], A0, A1, S0, S1) :-
    u256_add(A0, X0, N0), u256_add(A1, X1, N1),
    v3_owed_sum(T, N0, N1, S0, S1).

v3_create(Pool, Token0, Token1, FeePips, Tick) :-
    ground(Pool), ground(Token0), ground(Token1),
    Token0 @< Token1,
    \+ v3_pool(Pool, _, _, _),
    v3_fee_tier(FeePips),
    tm_sqrt_ratio_at_tick(Tick, Sqrt),
    assertz(v3_pool(Pool, Token0, Token1, FeePips)),
    assertz(v3_price(Pool, Sqrt, Tick)),
    assertz(v3_liq(Pool, '0')),
    assertz(v3_fg(Pool, '0', '0')),
    assertz(v3_next_id(Pool, 1)),
    nft_create(Pool, Pool).

v3_state(Pool, Sqrt, Tick, Liquidity) :-
    v3_price(Pool, Sqrt, Tick),
    v3_liq(Pool, Liquidity).

%% Modular subtraction: A - B in the ring of 256-bit numbers. See the
%% header -- this is deliberate, and it is the only place it is allowed.
v3_sub_wrap(A, B, R) :-
    (   u256_cmp(A, B, '<')
    ->  tm_u256_max(Max),
        u256_sub(Max, B, T),
        u256_add(T, A, T2),
        u256_add(T2, '1', R)
    ;   u256_sub(A, B, R)
    ).

%% ---- ticks -----------------------------------------------------------
%%
%% A tick is created the first time a position names it. `outside' is
%% initialised to the global growth when the tick is at or below the
%% current price and to zero when it is above -- Uniswap's convention,
%% and the one that makes the subtraction below come out right whether
%% a position is opened in range or out of it.
v3_touch_tick(Pool, Tick, Liquidity, Which) :-
    v3_price(Pool, _, Current),
    v3_fg(Pool, G0, G1),
    (   v3_tickinfo(Pool, Tick, S0, E0, O0, O1)
    ->  retract(v3_tickinfo(Pool, Tick, S0, E0, O0, O1))
    ;   S0 = '0', E0 = '0',
        (   Tick =< Current -> O0 = G0, O1 = G1 ; O0 = '0', O1 = '0' )
    ),
    (   Which == starts
    ->  u256_add(S0, Liquidity, S), E = E0
    ;   S = S0, u256_add(E0, Liquidity, E)
    ),
    assertz(v3_tickinfo(Pool, Tick, S, E, O0, O1)).

v3_tick_outside(Pool, Tick, O0, O1) :-
    (   v3_tickinfo(Pool, Tick, _, _, A, B) -> O0 = A, O1 = B
    ;   O0 = '0', O1 = '0'
    ).

%% Crossing flips every tick's memory of what happened on the far side
%% of it, and moves the active liquidity by what starts and ends there.
v3_cross(Pool, Tick, Zfo) :-
    v3_fg(Pool, G0, G1),
    (   retract(v3_tickinfo(Pool, Tick, S, E, O0, O1))
    ->  v3_sub_wrap(G0, O0, N0),
        v3_sub_wrap(G1, O1, N1),
        assertz(v3_tickinfo(Pool, Tick, S, E, N0, N1))
    ;   S = '0', E = '0'
    ),
    v3_liq(Pool, L),
    (   Zfo == true
    ->  u256_add(L, E, T), u256_sub(T, S, L2)     % downward: undo the range
    ;   u256_add(L, S, T), u256_sub(T, E, L2)     % upward: apply it
    ),
    retract(v3_liq(Pool, _)),
    assertz(v3_liq(Pool, L2)).

%% The next initialised tick in the direction of travel. Downward wants
%% the highest at or below the current tick; upward the lowest above it.
%% A real engine keeps a bitmap and searches a word at a time; with the
%% tick set small this asks it directly, which is the same answer.
v3_next_tick(Pool, true, Next) :-
    v3_price(Pool, _, Tick),
    findall(T, ( v3_tickinfo(Pool, T, _, _, _, _), T =< Tick ), Ts),
    Ts \== [],
    max_list(Ts, Next).
v3_next_tick(Pool, false, Next) :-
    v3_price(Pool, _, Tick),
    findall(T, ( v3_tickinfo(Pool, T, _, _, _, _), T > Tick ), Ts),
    Ts \== [],
    min_list(Ts, Next).

%% ---- fee growth ------------------------------------------------------

v3_fee_growth_inside(Pool, Lower, Upper, In0, In1) :-
    v3_price(Pool, _, Tick),
    v3_fg(Pool, G0, G1),
    v3_tick_outside(Pool, Lower, LO0, LO1),
    v3_tick_outside(Pool, Upper, UO0, UO1),
    (   Tick >= Lower
    ->  B0 = LO0, B1 = LO1
    ;   v3_sub_wrap(G0, LO0, B0), v3_sub_wrap(G1, LO1, B1)
    ),
    (   Tick < Upper
    ->  A0 = UO0, A1 = UO1
    ;   v3_sub_wrap(G0, UO0, A0), v3_sub_wrap(G1, UO1, A1)
    ),
    v3_sub_wrap(G0, B0, T0), v3_sub_wrap(T0, A0, In0),
    v3_sub_wrap(G1, B1, T1), v3_sub_wrap(T1, A1, In1).

%% What a position has earned: its liquidity times the growth per unit
%% since it last looked, plus whatever was already banked for it.
v3_fees_owed(Id, Owed0, Owed1) :-
    v3_pos(Id, Pool, Lo, Hi, L, Last0, Last1, Acc0, Acc1),
    v3_fee_growth_inside(Pool, Lo, Hi, In0, In1),
    tm_q128(Q128),
    v3_sub_wrap(In0, Last0, D0), u256_muldiv(L, D0, Q128, F0), u256_add(Acc0, F0, Owed0),
    v3_sub_wrap(In1, Last1, D1), u256_muldiv(L, D1, Q128, F1), u256_add(Acc1, F1, Owed1).

%% Taking them: only whoever the position's token authorises, and the
%% baseline is reset so the same fees cannot be collected twice.
v3_collect(Id, Caller, F0, F1) :-
    v3_pos(Id, Pool, Lo, Hi, L, _, _, _, _),
    nft_may_move(Pool, Caller, Id),
    v3_fees_owed(Id, F0, F1),
    v3_fee_growth_inside(Pool, Lo, Hi, In0, In1),
    retract(v3_pos(Id, Pool, Lo, Hi, L, _, _, _, _)),
    assertz(v3_pos(Id, Pool, Lo, Hi, L, In0, In1, '0', '0')),
    v3_pool(Pool, Token0, Token1, _),
    v3_account(Pool, Acct),
    ( u256_cmp(F0, '0', '>') -> ft_transfer(Token0, Acct, Caller, F0) ; true ),
    ( u256_cmp(F1, '0', '>') -> ft_transfer(Token1, Acct, Caller, F1) ; true ).

%% ---- positions -------------------------------------------------------

v3_amounts(Sqrt, Tick, Lower, Upper, Liquidity, Amount0, Amount1) :-
    tm_sqrt_ratio_at_tick(Lower, SqrtLo),
    tm_sqrt_ratio_at_tick(Upper, SqrtHi),
    (   Tick < Lower
    ->  tm_amount0_delta(SqrtLo, SqrtHi, Liquidity, Amount0), Amount1 = '0'
    ;   Tick >= Upper
    ->  Amount0 = '0', tm_amount1_delta(SqrtLo, SqrtHi, Liquidity, Amount1)
    ;   tm_amount0_delta(Sqrt, SqrtHi, Liquidity, Amount0),
        tm_amount1_delta(SqrtLo, Sqrt, Liquidity, Amount1)
    ).

v3_mint(Pool, Owner, Lower, Upper, Liquidity, Id, Amount0, Amount1) :-
    v3_pool(Pool, _, _, _),
    ground(Owner),
    integer(Lower), integer(Upper), Lower < Upper,
    tm_min_tick(Min), tm_max_tick(Max),
    Lower >= Min, Upper =< Max,
    u256_cmp(Liquidity, '0', '>'),
    v3_price(Pool, Sqrt, Tick),
    v3_amounts(Sqrt, Tick, Lower, Upper, Liquidity, Amount0, Amount1),
    v3_touch_tick(Pool, Lower, Liquidity, starts),
    v3_touch_tick(Pool, Upper, Liquidity, ends),
    (   Lower =< Tick, Tick < Upper
    ->  retract(v3_liq(Pool, L0)), u256_add(L0, Liquidity, L1),
        assertz(v3_liq(Pool, L1))
    ;   true
    ),
    retract(v3_next_id(Pool, N)),
    N2 is N + 1,
    assertz(v3_next_id(Pool, N2)),
    u256_dec(N, Id),
    nft_mint(Pool, Owner, Id),
    %% the deposit is a real transfer, out of a balance the provider
    %% must actually have
    v3_pool(Pool, Token0, Token1, _),
    v3_account(Pool, Acct),
    ( u256_cmp(Amount0, '0', '>') -> ft_transfer(Token0, Owner, Acct, Amount0) ; true ),
    ( u256_cmp(Amount1, '0', '>') -> ft_transfer(Token1, Owner, Acct, Amount1) ; true ),
    %% THE BASELINE IS TAKEN NOW, after the ticks exist, so the position
    %% earns from this moment and not from the pool's beginning.
    v3_fee_growth_inside(Pool, Lower, Upper, In0, In1),
    assertz(v3_pos(Id, Pool, Lower, Upper, Liquidity, In0, In1, '0', '0')).

v3_position(Id, Pool, Owner, Lower, Upper, Liquidity) :-
    v3_pos(Id, Pool, Lower, Upper, Liquidity, _, _, _, _),
    nft_owner(Pool, Id, Owner).

v3_burn(Pool, Caller, Id, Amount0, Amount1, Fees0, Fees1) :-
    v3_pos(Id, Pool, Lower, Upper, Liquidity, _, _, _, _),
    nft_may_move(Pool, Caller, Id),
    v3_fees_owed(Id, Fees0, Fees1),
    v3_price(Pool, Sqrt, Tick),
    v3_amounts(Sqrt, Tick, Lower, Upper, Liquidity, Amount0, Amount1),
    v3_untouch_tick(Pool, Lower, Liquidity, starts),
    v3_untouch_tick(Pool, Upper, Liquidity, ends),
    (   Lower =< Tick, Tick < Upper
    ->  retract(v3_liq(Pool, L0)), u256_sub(L0, Liquidity, L1),
        assertz(v3_liq(Pool, L1))
    ;   true
    ),
    retract(v3_pos(Id, Pool, _, _, _, _, _, _, _)),
    nft_burn(Pool, Id),
    %% the range and the fees it earned both come back as real tokens
    v3_pool(Pool, Token0, Token1, _),
    v3_account(Pool, Acct),
    nft_owner_or(Pool, Id, Caller, To),
    u256_add(Amount0, Fees0, Pay0),
    u256_add(Amount1, Fees1, Pay1),
    ( u256_cmp(Pay0, '0', '>') -> ft_transfer(Token0, Acct, To, Pay0) ; true ),
    ( u256_cmp(Pay1, '0', '>') -> ft_transfer(Token1, Acct, To, Pay1) ; true ).

%% Whoever closes it is paid, which is the caller -- the token said they
%% were allowed, and an approved spender closing on the owner's behalf
%% is a v3 periphery arrangement rather than something this decides.
nft_owner_or(_, _, Caller, Caller).

v3_untouch_tick(Pool, Tick, Liquidity, Which) :-
    retract(v3_tickinfo(Pool, Tick, S0, E0, O0, O1)),
    (   Which == starts -> u256_sub(S0, Liquidity, S), E = E0
    ;   S = S0, u256_sub(E0, Liquidity, E)
    ),
    %% A tick nobody's range touches any more is not a boundary, and
    %% leaving it initialised would make swaps stop at a price where
    %% nothing happens.
    (   u256_cmp(S, '0', '='), u256_cmp(E, '0', '=')
    ->  true
    ;   assertz(v3_tickinfo(Pool, Tick, S, E, O0, O1))
    ).

%% ---- one leg of a swap ------------------------------------------------
%%
%% Uniswap's computeSwapStep, and the shape is the whole of it: work out
%% what it would cost to reach the next tick, and either reach it or
%% stop short. The fee is taken off the input BEFORE the price moves, so
%% a trade pays for the distance it actually travels.
v3_step(Sqrt, Target, L, Remaining, Fee, Next, AmountIn, AmountOut, FeeAmt) :-
    (   \+ u256_cmp(Target, Sqrt, '>') -> Zfo = true ; Zfo = false ),
    v3_fee_denominator(Denom),
    u256_dec(Fee, F),
    u256_sub(Denom, F, Kept),
    u256_muldiv(Remaining, Kept, Denom, Less),
    (   Zfo == true
    ->  tm_amount0_delta_up(Target, Sqrt, L, ToTarget)
    ;   tm_amount1_delta_up(Sqrt, Target, L, ToTarget)
    ),
    (   \+ u256_cmp(Less, ToTarget, '<')
    ->  Next = Target, Max = true
    ;   (   Zfo == true
        ->  tm_next_sqrt_down(Sqrt, L, Less, Next)
        ;   tm_next_sqrt_up(Sqrt, L, Less, Next)
        ),
        Max = false
    ),
    (   Zfo == true
    ->  (   Max == true -> AmountIn = ToTarget
        ;   tm_amount0_delta_up(Next, Sqrt, L, AmountIn) ),
        tm_amount1_delta(Next, Sqrt, L, AmountOut)
    ;   (   Max == true -> AmountIn = ToTarget
        ;   tm_amount1_delta_up(Sqrt, Next, L, AmountIn) ),
        tm_amount0_delta(Sqrt, Next, L, AmountOut)
    ),
    %% Stopping short spends everything that is left; reaching the tick
    %% pays the fee on what was actually used.
    (   Max == false
    ->  u256_sub(Remaining, AmountIn, FeeAmt)
    ;   u256_mul(AmountIn, F, X), tm_div_up(X, Kept, FeeAmt)
    ).

v3_accrue(Pool, Zfo, FeeAmt, L) :-
    (   u256_cmp(L, '0', '=')
    ->  true
    ;   tm_q128(Q128),
        u256_muldiv(FeeAmt, Q128, L, Delta),
        retract(v3_fg(Pool, G0, G1)),
        (   Zfo == true
        ->  u256_add(G0, Delta, N0), N1 = G1     % the fee is the INPUT token
        ;   N0 = G0, u256_add(G1, Delta, N1)
        ),
        assertz(v3_fg(Pool, N0, N1))
    ).

%% ---- the swap, walking ------------------------------------------------

v3_swap(Pool, Who, TokenIn, AmountIn, AmountOut, Unspent) :-
    v3_pool(Pool, Token0, Token1, _),
    (   TokenIn == Token0 -> Zfo = true, TokenOut = Token1
    ;   TokenIn == Token1 -> Zfo = false, TokenOut = Token0
    ),
    u256_cmp(AmountIn, '0', '>'),
    %% THE TRADER MUST HAVE IT BEFORE THE WALK BEGINS. Checking after
    %% would mean a swap that moved the price and then failed to be
    %% paid for -- the price change is the part that cannot be undone by
    %% a failing goal, since it is written as it goes.
    ft_balance(TokenIn, Who, Have),
    \+ u256_cmp(AmountIn, Have, '>'),
    v3_walk(Pool, Zfo, AmountIn, '0', AmountOut, Unspent),
    %% only what was actually spent changes hands
    u256_sub(AmountIn, Unspent, Spent),
    v3_account(Pool, Acct),
    ( u256_cmp(Spent, '0', '>') -> ft_transfer(TokenIn, Who, Acct, Spent) ; true ),
    ( u256_cmp(AmountOut, '0', '>') -> ft_transfer(TokenOut, Acct, Who, AmountOut) ; true ).

v3_walk(Pool, Zfo, Remaining, Acc, Out, Unspent) :-
    (   u256_cmp(Remaining, '0', '=')
    ->  Out = Acc, Unspent = '0'
    ;   v3_next_tick(Pool, Zfo, NextTick)
    ->  v3_leg(Pool, Zfo, NextTick, Remaining, Acc, Out, Unspent)
    ;   %% NO MORE BOUNDARIES. The pool has run out of ranges in this
        %% direction; what is left is handed back rather than swallowed.
        Out = Acc, Unspent = Remaining
    ).

v3_leg(Pool, Zfo, NextTick, Remaining, Acc, Out, Unspent) :-
    v3_price(Pool, Sqrt, _),
    v3_liq(Pool, L),
    v3_pool(Pool, _, _, Fee),
    tm_sqrt_ratio_at_tick(NextTick, Target),
    (   u256_cmp(L, '0', '=')
    ->  %% a gap: nothing to trade against, so move to the boundary and
        %% pick up whatever starts there
        v3_arrive(Pool, NextTick, Target, Zfo),
        v3_walk(Pool, Zfo, Remaining, Acc, Out, Unspent)
    ;   v3_step(Sqrt, Target, L, Remaining, Fee, Next, In, StepOut, FeeAmt),
        u256_add(In, FeeAmt, Spent),
        u256_sub(Remaining, Spent, Rem2),
        u256_add(Acc, StepOut, Acc2),
        v3_accrue(Pool, Zfo, FeeAmt, L),
        (   u256_cmp(Next, Target, '=')
        ->  v3_arrive(Pool, NextTick, Target, Zfo),
            v3_walk(Pool, Zfo, Rem2, Acc2, Out, Unspent)
        ;   retract(v3_price(Pool, _, T0)),
            assertz(v3_price(Pool, Next, T0)),
            Out = Acc2, Unspent = Rem2
        )
    ).

%% Landing on a tick: the price is exactly there, the tick is crossed,
%% and the current tick becomes one BELOW the boundary going down --
%% because a tick's range is closed at the bottom and open at the top,
%% so standing on it means being inside the range above.
v3_arrive(Pool, Tick, Target, Zfo) :-
    retract(v3_price(Pool, _, _)),
    (   Zfo == true -> T is Tick - 1 ; T = Tick ),
    assertz(v3_price(Pool, Target, T)),
    v3_cross(Pool, Tick, Zfo).

%% ---- the liquidity, and proving the copy -------------------------------
%%
%% v3_liq/2 is MAINTAINED rather than derived: mint adds to it, burn
%% subtracts, and crossing a tick moves it by what starts and ends
%% there. That is what makes a swap constant-work per leg instead of a
%% walk of every position -- and it is also a second copy of a fact,
%% which is the kind that goes stale silently.
%%
%% So the derivation is kept too, as a predicate nothing else calls:
%% `v3_liquidity_agrees/1' adds up the positions that actually contain
%% the current tick and requires the maintained number to match. A
%% crossing that moved liquidity the wrong way, or a burn that forgot to
%% take it back out, shows up here and nowhere else.
v3_active_liquidity(Pool, Liquidity) :- v3_liq(Pool, Liquidity).

v3_liquidity_agrees(Pool) :-
    v3_price(Pool, _, Tick),
    findall(L, ( v3_pos(_, Pool, Lo, Hi, L, _, _, _, _), Lo =< Tick, Tick < Hi ), Ls),
    v3_sum(Ls, '0', Derived),
    v3_liq(Pool, Kept),
    u256_cmp(Derived, Kept, '=').

v3_sum([], Acc, Acc).
v3_sum([X|T], Acc, Sum) :- u256_add(Acc, X, A2), v3_sum(T, A2, Sum).
