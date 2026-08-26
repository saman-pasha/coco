%% contracts/lending/aave -- supplying, borrowing, and the moment a
%% position stops being safe.
%%
%%   aave_init(+Asset, +Ltv, +Threshold, +Bonus, +ReserveFactor)
%%   aave_rate_model(+Asset, +Base, +Slope1, +Slope2, +Optimal)
%%   aave_price(+Asset, +Price)              the oracle, and it is one
%%   aave_supply(+Asset, +Who, +Amount)      aave_withdraw(+Asset, +Who, +Amount)
%%   aave_borrow(+Asset, +Who, +Amount)      aave_repay(+Asset, +Who, +Amount)
%%   aave_accrue(+Asset, +Now)               carry the indexes to a time
%%   aave_supplied(+Asset, +Who, -Amount)    aave_debt(+Asset, +Who, -Amount)
%%   aave_utilization(+Asset, -U)            aave_rates(+Asset, -Supply, -Borrow)
%%   aave_health(+Who, -HealthFactor)        aave_liquidate(...)
%%   aave_solvent(+Asset)                    aave_available(+Asset, -Liquidity)
%%
%% WHAT A LENDING POOL IS. Everyone's deposits of one asset go into one
%% pot; borrowers take from the pot against collateral they have posted
%% elsewhere in the protocol; the interest borrowers pay is what
%% suppliers earn. Nobody is matched to anybody -- there are no
%% counterparties here, only a pot and a rule -- which is why a supplier
%% can leave whenever there is liquidity and a borrower can hold a loan
%% with no term.
%%
%% A BALANCE IS A SCALED AMOUNT TIMES AN INDEX, and this is the whole
%% trick. Interest cannot be credited to every account on every
%% transaction -- that is work proportional to the number of users, on
%% every block. So the pool keeps ONE index per side, growing with time,
%% and stores each user's balance DIVIDED by the index at the moment
%% they touched it. Multiply back and the interest is there. Constant
%% work per operation, exact per user, and the same device
%% contracts/dex/uniswap-v3.pl uses for fee growth -- once you have seen
%% it in one protocol you see it in all of them.
%%
%% TIME COMES FROM THE CALLER, NEVER FROM A CLOCK. `aave_accrue/2' takes
%% the moment to accrue TO, and the caller is the node, which got it from
%% the block it is executing. A contract that read the time itself would
%% be a contract two nodes could disagree about -- which is exactly why
%% library(contract)'s fence forbids it -- and interest that depended on
%% when a node happened to run would not be interest, it would be a
%% race. Here the block says what time it is and every node agrees.
%%
%% RAY IS 1e27, and the arithmetic is Aave's own WadRayMath: rayMul is
%% (a*b + RAY/2)/RAY and rayDiv is (a*RAY + b/2)/b, both rounding half
%% up. The products stay far inside 256 bits at any realistic size -- an
%% index near 1e27 times an amount near 1e24 is 1e51 against a ceiling
%% of 1.16e77 -- and u256 raises rather than wraps if that ever stops
%% being true.
%%
%% SUPPLY INTEREST IS LINEAR AND BORROW INTEREST COMPOUNDS, which is
%% Aave's choice and not an approximation of it: the borrow index uses
%% the binomial expansion of (1+r)^t to three terms, which is what the
%% contract on Ethereum actually computes. Suppliers therefore earn a
%% little less than borrowers pay even before the reserve factor, and
%% that gap is real rather than rounding.
%%
%% THE ORACLE IS THE TRUST ASSUMPTION, and it should be said plainly
%% rather than buried. Every health factor is a price question, and
%% `aave_price/2' is a fact somebody asserts. A protocol like this is
%% exactly as honest as its prices: a wrong price liquidates a healthy
%% position or lets an unhealthy one stand, and no amount of correct
%% interest arithmetic protects against that. On a real chain this is a
%% signed feed with its own quorum; here it is a fact, and the suite
%% moves it to show what moves with it.
%%
%% WHAT IS NOT HERE: stable-rate borrowing (Aave's second debt token,
%% since deprecated), isolation mode, e-mode, flash loans, the
%% protocol's treasury accounting for the reserve factor it collects,
%% and interest-rate strategy contracts per asset beyond the four
%% parameters below. A borrow that would leave a position unhealthy is
%% refused rather than approximated, and a liquidation of a healthy
%% position is refused outright.

:- use_module(library(u256)).
:- use_module(library(lists)).

%% Balances are real: the pool is an account in contracts/token/fungible,
%% which must be loaded beside this file.

:- dynamic aave_reserve/6.   % aave_reserve(Asset,Ltv,Threshold,Bonus,Factor,LastAccrual)
:- dynamic aave_model/5.     % aave_model(Asset, Base, Slope1, Slope2, Optimal)
:- dynamic aave_index/3.     % aave_index(Asset, LiquidityIndex, BorrowIndex)
:- dynamic aave_scaled_supply/3.   % aave_scaled_supply(Asset, Who, Scaled)
:- dynamic aave_scaled_debt/3.     % aave_scaled_debt(Asset, Who, Scaled)
:- dynamic aave_total_scaled/3.    % aave_total_scaled(Asset, SupplyScaled, DebtScaled)
:- dynamic aave_oracle/2.    % aave_oracle(Asset, Price)

aave_ray('1000000000000000000000000000').        % 1e27
aave_half_ray('500000000000000000000000000').
aave_bps('10000').                               % basis points
aave_year('31536000').                           % seconds
aave_close_factor('5000').                       % half a debt, in bps

%% ---- ray arithmetic, Aave's own --------------------------------------

aave_ray_mul(A, B, C) :-
    u256_mul(A, B, P),
    aave_half_ray(Half),
    u256_add(P, Half, P2),
    aave_ray(Ray),
    u256_div(P2, Ray, C).

aave_ray_div(A, B, C) :-
    u256_cmp(B, '0', '>'),
    aave_ray(Ray),
    u256_mul(A, Ray, P),
    u256_div(B, '2', HalfB),
    u256_add(P, HalfB, P2),
    u256_div(P2, B, C).

%% ---- the reserve -----------------------------------------------------

aave_account(Asset, pool(aave, Asset)).

aave_init(Asset, Ltv, Threshold, Bonus, Factor) :-
    ground(Asset),
    \+ aave_reserve(Asset, _, _, _, _, _),
    %% A threshold BELOW the LTV would let a position be born
    %% liquidatable, which is not a risk parameter, it is a trap.
    \+ u256_cmp(Ltv, Threshold, '>'),
    aave_bps(Bps),
    \+ u256_cmp(Threshold, Bps, '>'),
    aave_ray(Ray),
    assertz(aave_reserve(Asset, Ltv, Threshold, Bonus, Factor, '0')),
    assertz(aave_index(Asset, Ray, Ray)),
    assertz(aave_total_scaled(Asset, '0', '0')),
    %% a sane default curve, replaceable by aave_rate_model/5
    assertz(aave_model(Asset, '0', '40000000000000000000000000',
                       '600000000000000000000000000',
                       '800000000000000000000000000')).

aave_rate_model(Asset, Base, Slope1, Slope2, Optimal) :-
    aave_reserve(Asset, _, _, _, _, _),
    retract(aave_model(Asset, _, _, _, _)),
    assertz(aave_model(Asset, Base, Slope1, Slope2, Optimal)).

aave_price(Asset, Price) :-
    ( retract(aave_oracle(Asset, _)) -> true ; true ),
    u256_dec(Price, P),
    assertz(aave_oracle(Asset, P)).

%% ---- what is in the pot ----------------------------------------------

aave_supplied(Asset, Who, Amount) :-
    aave_index(Asset, Li, _),
    ( aave_scaled_supply(Asset, Who, S) -> true ; S = '0' ),
    aave_ray_mul(S, Li, Amount).

aave_debt(Asset, Who, Amount) :-
    aave_index(Asset, _, Bi),
    ( aave_scaled_debt(Asset, Who, S) -> true ; S = '0' ),
    aave_ray_mul(S, Bi, Amount).

aave_total_supplied(Asset, Amount) :-
    aave_total_scaled(Asset, S, _),
    aave_index(Asset, Li, _),
    aave_ray_mul(S, Li, Amount).

aave_total_debt(Asset, Amount) :-
    aave_total_scaled(Asset, _, D),
    aave_index(Asset, _, Bi),
    aave_ray_mul(D, Bi, Amount).

%% What can actually be taken out today: what was supplied, less what is
%% out on loan. A pool can be perfectly solvent and still have nothing
%% available, which is the difference between being owed and being paid.
aave_available(Asset, Liquidity) :-
    aave_total_supplied(Asset, S),
    aave_total_debt(Asset, D),
    ( u256_cmp(S, D, '<') -> Liquidity = '0' ; u256_sub(S, D, Liquidity) ).

%% THE SOLVENCY CHECK, and it is about the pot rather than any user: the
%% tokens the pool actually holds must cover what is not on loan.
aave_solvent(Asset) :-
    aave_account(Asset, Acct),
    ft_balance(Asset, Acct, Held),
    aave_available(Asset, Owed),
    \+ u256_cmp(Held, Owed, '<').

%% ---- the interest rate, which is a function of scarcity --------------
%%
%% Utilization is how much of the pot is out on loan. The curve has a
%% KINK at the optimal point: gentle below it, brutal above -- which is
%% not a preference but a mechanism. The steep half exists to make the
%% last of the liquidity expensive enough that somebody repays or
%% supplies before the pool runs dry, because a pool with no liquidity
%% cannot honour a withdrawal at any price.
aave_utilization(Asset, U) :-
    aave_total_debt(Asset, D),
    (   u256_cmp(D, '0', '=')
    ->  U = '0'
    ;   aave_total_supplied(Asset, S),
        aave_ray_div(D, S, U)
    ).

aave_rates(Asset, SupplyRate, BorrowRate) :-
    aave_model(Asset, Base, Slope1, Slope2, Optimal),
    aave_reserve(Asset, _, _, _, Factor, _),
    aave_utilization(Asset, U),
    aave_ray(Ray),
    (   \+ u256_cmp(U, Optimal, '>')
    ->  aave_ray_div(U, Optimal, Ratio),
        aave_ray_mul(Slope1, Ratio, Part),
        u256_add(Base, Part, BorrowRate)
    ;   u256_sub(U, Optimal, Excess),
        u256_sub(Ray, Optimal, Room),
        aave_ray_div(Excess, Room, Ratio),
        aave_ray_mul(Slope2, Ratio, Part),
        u256_add(Base, Slope1, B1),
        u256_add(B1, Part, BorrowRate)
    ),
    %% WHAT SUPPLIERS EARN IS NOT WHAT BORROWERS PAY, and the gap is not
    %% a fee hidden anywhere: the idle part of the pot earns nothing, so
    %% the borrow rate is diluted by utilization, and the reserve factor
    %% is the protocol's own cut of what is left.
    aave_ray_mul(BorrowRate, U, Earned),
    aave_bps(Bps),
    u256_sub(Bps, Factor, Kept),
    u256_muldiv(Earned, Kept, Bps, SupplyRate).

%% ---- carrying the indexes forward ------------------------------------
%%
%% Called with the time to accrue TO. Everything that reads a balance
%% reads it through the indexes, so accruing is the only place interest
%% is ever created, and it is a single multiply per side no matter how
%% many accounts exist.
aave_accrue(Asset, Now) :-
    aave_reserve(Asset, Ltv, Th, Bonus, Factor, Last),
    u256_dec(Now, N),
    \+ u256_cmp(N, Last, '<'),
    u256_sub(N, Last, Dt),
    (   u256_cmp(Dt, '0', '=')
    ->  true
    ;   aave_rates(Asset, SupplyRate, BorrowRate),
        aave_index(Asset, Li, Bi),
        aave_linear(SupplyRate, Dt, LinearFactor),
        aave_compound(BorrowRate, Dt, CompoundFactor),
        aave_ray_mul(Li, LinearFactor, Li2),
        aave_ray_mul(Bi, CompoundFactor, Bi2),
        retract(aave_index(Asset, _, _)),
        assertz(aave_index(Asset, Li2, Bi2)),
        retract(aave_reserve(Asset, _, _, _, _, _)),
        assertz(aave_reserve(Asset, Ltv, Th, Bonus, Factor, N))
    ).

%% 1 + rate*dt/year. What a supplier earns, and Aave keeps it linear.
aave_linear(Rate, Dt, Factor) :-
    aave_year(Year),
    u256_mul(Rate, Dt, P),
    u256_div(P, Year, Growth),
    aave_ray(Ray),
    u256_add(Ray, Growth, Factor).

%% (1 + rate/year)^dt, as the binomial to three terms -- which is what
%% Aave's calculateCompoundedInterest computes, not an approximation of
%% what it computes. Beyond three terms the correction is far below the
%% rounding of the amounts it will multiply.
aave_compound(Rate, Dt, Factor) :-
    aave_ray(Ray),
    (   u256_cmp(Dt, '0', '=')
    ->  Factor = Ray
    ;   aave_year(Year),
        u256_sub(Dt, '1', DtMinusOne),
        (   u256_cmp(Dt, '2', '>')
        ->  u256_sub(Dt, '2', DtMinusTwo)
        ;   DtMinusTwo = '0'
        ),
        u256_mul(Year, Year, YearSq),
        aave_ray_mul(Rate, Rate, RateSq),
        u256_div(RateSq, YearSq, BasePow2),
        aave_ray_mul(BasePow2, Rate, B3a),
        u256_div(B3a, Year, BasePow3),
        u256_mul(Dt, DtMinusOne, T2),
        u256_mul(T2, BasePow2, T2b),
        u256_div(T2b, '2', SecondTerm),
        u256_mul(T2, DtMinusTwo, T3),
        u256_mul(T3, BasePow3, T3b),
        u256_div(T3b, '6', ThirdTerm),
        u256_mul(Rate, Dt, FirstA),
        u256_div(FirstA, Year, FirstTerm),
        u256_add(Ray, FirstTerm, F1),
        u256_add(F1, SecondTerm, F2),
        u256_add(F2, ThirdTerm, Factor)
    ).

%% ---- supplying and withdrawing ---------------------------------------
%%
%% DETERMINISM IS A SAFETY PROPERTY HERE, not a tidiness one. These
%% operations WRITE -- assertz and retract -- and Prolog backtracking
%% does not undo a write. So an operation that must write, check, and
%% then reverse itself has to refuse FINALLY: the cuts below say that a
%% refusal is the answer and not a branch to be retried, and every path
%% that undoes a write ends in one.
%%
%% THE SUITE CAUGHT THIS FILE GRANTING A LOAN ITS OWN LTV RULE REFUSED
%% -- 9000 against 100 WETH at 100, where the ceiling is 7500. What is
%% checked now is the ceiling itself, at the wei: 7500 is granted, 7501
%% is refused, and a refusal leaves no debt, no payout and no drift in
%% the pot. Those are the four things test/lending.sh reads back, and
%% they are worth more than any account of how the write got out --
%% a refusal that leaves state behind is the bug, whatever let it
%% through.
%%

aave_supply(Asset, Who, Amount) :-
    aave_reserve(Asset, _, _, _, _, _),
    ground(Who),
    u256_cmp(Amount, '0', '>'),
    aave_index(Asset, Li, _),
    aave_ray_div(Amount, Li, Scaled),
    u256_cmp(Scaled, '0', '>'),
    aave_account(Asset, Acct),
    ft_transfer(Asset, Who, Acct, Amount),
    aave_bump_supply(Asset, Who, Scaled, up),
    !.

aave_withdraw(Asset, Who, Amount) :-
    aave_reserve(Asset, _, _, _, _, _),
    u256_cmp(Amount, '0', '>'),
    aave_supplied(Asset, Who, Have),
    \+ u256_cmp(Amount, Have, '>'),
    %% THE POT MAY BE EMPTY EVEN WHEN THE CLAIM IS GOOD. A withdrawal is
    %% refused for want of liquidity, not for want of entitlement, and
    %% the two are different answers to different questions.
    aave_available(Asset, Liquid),
    \+ u256_cmp(Amount, Liquid, '>'),
    aave_index(Asset, Li, _),
    aave_ray_div(Amount, Li, Scaled),
    aave_bump_supply(Asset, Who, Scaled, down),
    %% and it must not leave the withdrawer's own position unhealthy
    (   aave_healthy(Who)
    ->  aave_account(Asset, Acct),
        ft_transfer(Asset, Acct, Who, Amount)
    ;   aave_bump_supply(Asset, Who, Scaled, up),
        !, fail
    ).

aave_bump_supply(Asset, Who, Scaled, Dir) :-
    ( aave_scaled_supply(Asset, Who, S0) -> true ; S0 = '0' ),
    aave_total_scaled(Asset, TS, TD),
    (   Dir == up
    ->  u256_add(S0, Scaled, S1), u256_add(TS, Scaled, TS1)
    ;   u256_sub(S0, Scaled, S1), u256_sub(TS, Scaled, TS1)
    ),
    ( retract(aave_scaled_supply(Asset, Who, _)) -> true ; true ),
    assertz(aave_scaled_supply(Asset, Who, S1)),
    retract(aave_total_scaled(Asset, _, _)),
    assertz(aave_total_scaled(Asset, TS1, TD)),
    !.

%% ---- borrowing and repaying ------------------------------------------

aave_borrow(Asset, Who, Amount) :-
    aave_reserve(Asset, _, _, _, _, _),
    ground(Who),
    u256_cmp(Amount, '0', '>'),
    aave_available(Asset, Liquid),
    \+ u256_cmp(Amount, Liquid, '>'),
    aave_index(Asset, _, Bi),
    aave_ray_div(Amount, Bi, Scaled),
    u256_cmp(Scaled, '0', '>'),
    aave_bump_debt(Asset, Who, Scaled, up),
    %% THE BORROW IS ALLOWED BY THE POSITION, NOT BY THE POT. The
    %% liquidity check above says the money is there; this says the
    %% borrower may have it -- against their LTV, which is a stricter
    %% line than the liquidation threshold, so a loan does not begin one
    %% tick away from being seized.
    (   aave_within_ltv(Who)
    ->  aave_account(Asset, Acct),
        ft_transfer(Asset, Acct, Who, Amount)
    ;   aave_bump_debt(Asset, Who, Scaled, down),
        !, fail
    ).

aave_repay(Asset, Who, Amount) :-
    aave_debt(Asset, Who, Owed),
    u256_cmp(Owed, '0', '>'),
    u256_cmp(Amount, '0', '>'),
    ( u256_cmp(Amount, Owed, '>') -> Pay = Owed ; Pay = Amount ),
    aave_index(Asset, _, Bi),
    aave_ray_div(Pay, Bi, Scaled),
    aave_account(Asset, Acct),
    ft_transfer(Asset, Who, Acct, Pay),
    aave_bump_debt(Asset, Who, Scaled, down),
    !.

aave_bump_debt(Asset, Who, Scaled, Dir) :-
    ( aave_scaled_debt(Asset, Who, S0) -> true ; S0 = '0' ),
    aave_total_scaled(Asset, TS, TD),
    (   Dir == up
    ->  u256_add(S0, Scaled, S1), u256_add(TD, Scaled, TD1)
    ;   (   u256_cmp(Scaled, S0, '>') -> S1 = '0' ; u256_sub(S0, Scaled, S1) ),
        (   u256_cmp(Scaled, TD, '>') -> TD1 = '0' ; u256_sub(TD, Scaled, TD1) )
    ),
    ( retract(aave_scaled_debt(Asset, Who, _)) -> true ; true ),
    assertz(aave_scaled_debt(Asset, Who, S1)),
    retract(aave_total_scaled(Asset, _, _)),
    assertz(aave_total_scaled(Asset, TS, TD1)),
    !.

%% ---- how safe a position is ------------------------------------------
%%
%% Everything is valued through the oracle into one unit. The health
%% factor is the collateral, each part weighted by ITS OWN liquidation
%% threshold, over the debt. One means the edge: above it the position
%% stands, below it anyone may liquidate part of it.
aave_collateral_value(Who, Weighted, Ltv_weighted) :-
    findall(W-L,
            ( aave_reserve(A, Ltv, Th, _, _, _),
              aave_supplied(A, Who, Amt),
              u256_cmp(Amt, '0', '>'),
              aave_oracle(A, P),
              u256_mul(Amt, P, V),
              aave_bps(Bps),
              u256_muldiv(V, Th, Bps, W),
              u256_muldiv(V, Ltv, Bps, L) ),
            Parts),
    aave_sum_pairs(Parts, '0', '0', Weighted, Ltv_weighted).

aave_debt_value(Who, Value) :-
    findall(V,
            ( aave_reserve(A, _, _, _, _, _),
              aave_debt(A, Who, Amt),
              u256_cmp(Amt, '0', '>'),
              aave_oracle(A, P),
              u256_mul(Amt, P, V) ),
            Vs),
    aave_sum(Vs, '0', Value).

aave_sum([], Acc, Acc).
aave_sum([X|T], Acc, S) :- u256_add(Acc, X, A2), aave_sum(T, A2, S).
aave_sum_pairs([], A, B, A, B).
aave_sum_pairs([X-Y|T], A, B, SA, SB) :-
    u256_add(A, X, A2), u256_add(B, Y, B2), aave_sum_pairs(T, A2, B2, SA, SB).

%% No debt is infinite health, and that is not a special case being
%% dodged -- a position that owes nothing cannot be liquidated at any
%% price, so there is no number that describes it.
aave_health(Who, HealthFactor) :-
    aave_debt_value(Who, D),
    (   u256_cmp(D, '0', '=')
    ->  HealthFactor = infinite
    ;   aave_collateral_value(Who, Weighted, _),
        aave_ray_div(Weighted, D, HealthFactor)
    ).

aave_healthy(Who) :-
    aave_health(Who, HF),
    (   HF == infinite -> true
    ;   aave_ray(Ray), \+ u256_cmp(HF, Ray, '<')
    ).

aave_within_ltv(Who) :-
    aave_debt_value(Who, D),
    (   u256_cmp(D, '0', '=')
    ->  true
    ;   aave_collateral_value(Who, _, LtvValue),
        \+ u256_cmp(D, LtvValue, '>')
    ).

%% ---- liquidation ------------------------------------------------------
%%
%% When a position falls below one, anyone may repay part of its debt and
%% take collateral for it at a discount. The bonus is what pays for the
%% work and the risk of doing so, and it is the reason liquidation
%% happens promptly instead of when someone feels charitable.
%%
%% TWO LIMITS, both of them protections for the borrower. Only a
%% liquidatable position may be touched at all, and only HALF the debt
%% in one go -- the close factor -- so a position that dips barely under
%% is not wound up entirely at a discount.
aave_liquidate(DebtAsset, CollAsset, Liquidator, User, Amount, Seized) :-
    aave_reserve(DebtAsset, _, _, _, _, _),
    aave_reserve(CollAsset, _, _, Bonus, _, _),
    \+ aave_healthy(User),
    aave_debt(DebtAsset, User, Owed),
    u256_cmp(Owed, '0', '>'),
    aave_bps(Bps),
    aave_close_factor(Close),
    u256_muldiv(Owed, Close, Bps, MaxPay),
    ( u256_cmp(Amount, MaxPay, '>') -> Pay = MaxPay ; Pay = Amount ),
    u256_cmp(Pay, '0', '>'),
    %% what that repayment is worth, plus the bonus, in the collateral
    aave_oracle(DebtAsset, Pd),
    aave_oracle(CollAsset, Pc),
    u256_mul(Pay, Pd, PayValue),
    u256_add(Bps, Bonus, WithBonus),
    u256_muldiv(PayValue, WithBonus, Bps, Bonused),
    u256_div(Bonused, Pc, Seized),
    u256_cmp(Seized, '0', '>'),
    aave_supplied(CollAsset, User, HasColl),
    \+ u256_cmp(Seized, HasColl, '>'),
    %% the liquidator pays the debt in and takes the collateral out
    aave_account(DebtAsset, DebtAcct),
    ft_transfer(DebtAsset, Liquidator, DebtAcct, Pay),
    aave_index(DebtAsset, _, Bi),
    aave_ray_div(Pay, Bi, PaidScaled),
    aave_bump_debt(DebtAsset, User, PaidScaled, down),
    aave_index(CollAsset, Lc, _),
    aave_ray_div(Seized, Lc, SeizedScaled),
    aave_bump_supply(CollAsset, User, SeizedScaled, down),
    aave_account(CollAsset, CollAcct),
    ft_transfer(CollAsset, CollAcct, Liquidator, Seized),
    !.
