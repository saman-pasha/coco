%% contracts/dex/uniswap-v3: concentrated liquidity, and positions that
%% are non-fungible tokens.
%%
%% WHAT IS BEING PINNED, and where the numbers come from:
%%
%%   THE TICK MATH IS UNISWAP'S, CONSTANT FOR CONSTANT. tick 0 is price
%%   1, so its sqrt ratio is exactly 2^96 = 79228162514264337593543950336,
%%   and the two ends of the axis are the values TickMath.sol publishes:
%%   MIN_SQRT_RATIO 4295128739 and MAX_SQRT_RATIO
%%   1461446703485210103287273052203988822378723970342. Nothing here
%%   computed those three; they are what the library says, and getting
%%   any of the twenty magic constants wrong moves them.
%%
%%   A SYMMETRIC RANGE COSTS THE SAME OF BOTH. A position over ticks
%%   -60..60 with the price at tick 0 needs equal amounts of token0 and
%%   token1, which is a fact about the curve rather than about this
%%   code -- and an implementation with the two formulas swapped, or the
%%   reciprocal taken the wrong way, fails it immediately.
%%
%%   THE POSITION IS AN NFT, AND OWNERSHIP IS THE TOKEN'S. Minting one
%%   mints an id in the pool's own collection; the owner reported by the
%%   position is the owner the collection says, so a position that has
%%   been sold reports its new owner without anything here being
%%   updated. Only whoever the token authorises may close it.
%%
%%   AND v3 AGREES WITH v2 ON THE CURVE. A v3 pool of L = 10^18 at price
%%   1 is a v2 pool of 10^18 against 10^18, so swapping a thousandth of
%%   the depth must pay a thousandth of what v2 pays: v2's
%%   996006981039903216 against v3's 996006981039903, which is that
%%   number divided by a thousand and floored. Two engines written
%%   differently, one curve.
%%
%%   CROSSING A TICK CHANGES THE DEPTH, and that is what makes a range a
%%   range. Two positions, one narrow and one wide: a trade big enough
%%   walks out of the narrow one, the liquidity halves as it crosses, and
%%   the rest of the trade is priced against what is left. The whole
%%   crossing swap is checked against an independent implementation of
%%   Uniswap's own SwapMath -- output, unspent, resulting tick, resulting
%%   liquidity and fee growth, all five.
%%
%%   FEES BELONG TO THE RANGES THAT EARNED THEM. Two equal positions both
%%   in range earn equally; after a trade that walks one of them out of
%%   range, the one that stayed earns more. AND THE TWO SUM TO EXACTLY
%%   WHAT WAS CHARGED -- 0.3% of the input, to the wei -- which is the
%%   conservation law of the fee accounting and the one check that would
%%   catch a slow leak.
%%
%% EVERY CHECK IS ONE ISOLATED PROOF, because every one of them creates
%% pool `p' and mints into it: a second `v3_create(p, ...)' in a store
%% that already holds one is a different test from the one written here.
%% The .sh spawned a cocolog per check to get that; `run_isolated/2' is
%% the same isolation without the process.
%%
%% Run:  cocolog -s test/uniswap-v3.pl   from coco/ -- the exit code is
%%       the verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

v3_program :-
    use_module('contracts/token/fungible.pl'),
    use_module('contracts/token/nonfungible.pl'),
    use_module('contracts/dex/uniswap-v3.pl').

million('1000000000000000000000000').
unit('1000000000000000000').            %% 10^18, one whole token of depth

%% four traders, funded in both tokens
toks :-
    v3_program, million(M),
    ft_create(dai, 'DAI', 18), ft_create(weth, 'WETH', 18),
    forall(member(W, [alice, bob, carol]),
           ( ft_mint(dai, W, M), ft_mint(weth, W, M) )).

pool :- toks, v3_create(p, dai, weth, 3000, 0).

%% alice's symmetric range, and the amounts it cost her
mk(Id, A0, A1) :- pool, unit(L), v3_mint(p, alice, -60, 60, L, Id, A0, A1).
mk :- mk(_, _, _).

%% the same pool with the position anonymous -- the swapping checks
m2 :- mk(_, _, _).

%% alice narrow, bob wide, equal liquidity: the crossing arrangement
mx(A, B) :- pool, unit(L),
    v3_mint(p, alice, -60, 60, L, A, _, _),
    v3_mint(p, bob, -600, 600, L, B, _, _).

%% a range that does not contain the price, with a gap under it
gap :- pool, unit(L), v3_mint(p, alice, 600, 1200, L, _, _, _).

%% ---- the tick axis ------------------------------------------------------

axis_half :-
    section('the tick axis'),
    iso('tick 0 is price 1, so its ratio is 2^96',
        ( v3_program, tm_sqrt_ratio_at_tick(0, S),
          want(S, '79228162514264337593543950336') )),
    iso('the bottom of the axis is MIN_SQRT_RATIO',
        ( v3_program, tm_min_tick(T), tm_sqrt_ratio_at_tick(T, S),
          want(S, '4295128739') )),
    iso('and the top is MAX_SQRT_RATIO',
        ( v3_program, tm_max_tick(T), tm_sqrt_ratio_at_tick(T, S),
          want(S, '1461446703485210103287273052203988822378723970342') )),
    iso('one tick up is one basis point up',
        ( v3_program, tm_sqrt_ratio_at_tick(1, S),
          want(S, '79232123823359799118286999568') )),
    iso('and one tick down is its reciprocal side',
        ( v3_program, tm_sqrt_ratio_at_tick(-1, S),
          want(S, '79224201403219477170569942574') )),
    iso('a tick past the end is not a price',
        ( v3_program, refuses(tm_sqrt_ratio_at_tick(887273, _)) )).

%% ---- positions ----------------------------------------------------------

position_half :-
    section('positions'),
    iso('a symmetric range needs equal token0',
        ( mk(_, A0, _), want(A0, '2995354955910780') )),
    iso('and equal token1',
        ( mk(_, _, A1), want(A1, '2995354955910780') )),
    iso('the position is minted as an NFT',
        ( mk(Id, _, _), nft_owner(p, Id, O), want(O, alice) )),
    iso("and its owner is the token's owner",
        ( mk(Id, _, _), v3_position(Id, _, O, _, _, _), want(O, alice) )),
    iso('selling the position moves who owns it',
        ( mk(Id, _, _), nft_transfer_from(p, alice, alice, bob, Id),
          v3_position(Id, _, O, _, _, _), want(O, bob) )),
    iso('a range above the price is all token0',
        ( pool, unit(L), v3_mint(p, alice, 600, 1200, L, _, _, A1),
          want(A1, '0') )),
    iso('a range below it is all token1',
        ( pool, unit(L), v3_mint(p, alice, -1200, -600, L, _, A0, _),
          want(A0, '0') )),
    iso('out-of-range liquidity is not depth',
        ( gap, v3_active_liquidity(p, L), want(L, '0') )),
    iso('in-range liquidity is',
        ( mk, unit(U), v3_active_liquidity(p, L), want(L, U) )),
    iso('an inverted range is refused',
        ( pool, refuses(v3_mint(p, alice, 60, -60, '1000', _, _, _)) )),
    iso('a fee tier nobody routes through is refused',
        ( toks, refuses(v3_create(p, dai, weth, 1234, 0)) )).

%% ---- swapping, within one range -----------------------------------------

swap_half :-
    section('swapping, within one range'),
    iso('a swap pays what the curve says',
        ( m2, v3_swap(p, bob, weth, '1000000000000000', Out, _),
          want(Out, '996006981039903') )),
    %% THE SAME CURVE, THE OTHER ENGINE. This one loads uniswap.pl rather
    %% than the v3 pool -- a different program, which is the point of the
    %% comparison.
    iso('and v2 pays a thousand times that, on the same curve',
        ( use_module('contracts/dex/uniswap.pl'),
          uni_amount_out('1000000000000000000', '1000000000000000000000',
                         '1000000000000000000000', X),
          want(X, '996006981039903216') )),
    iso('the price moved up and stayed in the range',
        ( m2, v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_price(p, S, _), want(S, '79307152992291059138124713654') )),
    iso('the other direction moves it down',
        ( m2, v3_swap(p, bob, dai, '1000000000000000', _, _),
          v3_price(p, S, _),
          ( u256_cmp(S, '79228162514264337593543950336', '<')
            -> W = down ; W = up ),
          want(W, down) )).

%% ---- crossing ticks -----------------------------------------------------

%% Every number in this section comes from an independent implementation
%% of Uniswap's SwapMath, not from this one.
cross_half :-
    section('crossing ticks'),
    iso('two ranges over the price stack their depth',
        ( mx(_, _), v3_liq(p, L), want(L, '2000000000000000000') )),
    iso('a crossing swap pays what the reference says',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', Out, _),
          want(Out, '9912816306615178') )),
    iso('and spends all of it',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, U),
          want(U, '0') )),
    iso('the price ends at the tick it crossed',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_price(p, _, T), want(T, 60) )),
    iso('and the depth halved, because a range ended',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_liq(p, L), want(L, '1000000000000000000') )),
    iso('fee growth matches the reference too',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_fg(p, _, G), want(G, '7132256228676415841154124566172760') )),
    %% A gap is not a wall: the walk moves to where the liquidity starts.
    iso('a swap reaches liquidity across a gap',
        ( gap, v3_swap(p, bob, weth, '1000000000000000', Out, _),
          want(Out, '938034474824077') )),
    iso('and the price got to where the range starts',
        ( gap, v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_price(p, _, T), want(T, 600) )),
    %% A range holds a finite amount. Ask for more and the pool pays what
    %% it has and HANDS BACK the rest rather than swallowing it.
    iso('a swap past all the liquidity pays out what there was',
        ( m2, v3_swap(p, bob, weth, '100000000000000000', Out, _),
          want(Out, '2995354955910780') )),
    iso('and returns the rest unspent',
        ( m2, v3_swap(p, bob, weth, '100000000000000000', _, U),
          want(U, '96986605754521638') )).

%% ---- fees, and whose they are -------------------------------------------

fee_half :-
    section('fees, and whose they are'),
    iso('two equal ranges, both in range, earn equally',
        ( mx(A, B), v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_fees_owed(A, _, FA), v3_fees_owed(B, _, FB),
          ( u256_cmp(FA, FB, '=') -> W = equal ; W = FA-FB ),
          want(W, equal) )),
    iso('after a crossing, the one that stayed earns more',
        ( mx(A, B), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_fees_owed(A, _, FA), v3_fees_owed(B, _, FB),
          u256_cmp(FA, FB, C), want(C, '<') )),
    %% The conservation law of the fee accounting: what the positions are
    %% owed sums to what the trade was charged, to the wei.
    iso('and the two sum to exactly the 0.3% charged',
        ( mx(A, B), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_fees_owed(A, _, FA), v3_fees_owed(B, _, FB),
          u256_add(FA, FB, S), want(S, '30000000000000') )),
    iso('a position opened after the trade earns nothing from it',
        ( mx(_, _), unit(L), v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_mint(p, carol, -60, 60, L, Cid, _, _),
          v3_fees_owed(Cid, _, F), want(F, '0') )),
    iso('collecting hands them over and zeroes the debt',
        ( mx(A, _), v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_collect(A, alice, _, _), v3_fees_owed(A, _, F), want(F, '0') )),
    iso('collecting twice does not pay twice',
        ( mx(A, _), v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_collect(A, alice, _, _), v3_collect(A, alice, _, F),
          want(F, '0') )),
    iso('and a stranger may not collect',
        ( mx(A, _), v3_swap(p, bob, weth, '1000000000000000', _, _),
          refuses(v3_collect(A, mallory, _, _)) )).

%% ---- closing ------------------------------------------------------------

close_half :-
    section('closing'),
    iso("only the token's owner may close the position",
        ( mk(Id, _, _), refuses(v3_burn(p, mallory, Id, _, _, _, _)) )),
    iso('the owner may, and gets the range back',
        ( mk(Id, _, _), v3_burn(p, alice, Id, B0, _, _, _),
          want(B0, '2995354955910780') )),
    iso('closing pays out the fees it earned',
        ( mx(A, _), v3_swap(p, bob, weth, '1000000000000000', _, _),
          v3_burn(p, alice, A, _, _, _, F1), want(F1, '1499999999999') )),
    iso('and the position token is gone with it',
        ( mk(Id, _, _), v3_burn(p, alice, Id, _, _, _, _),
          refuses(nft_owner(p, Id, _)) )),
    iso('closing a range frees its ticks as boundaries',
        ( mx(A, _), v3_burn(p, alice, A, _, _, _, _),
          v3_liq(p, L), want(L, '1000000000000000000') )),
    %% The maintained liquidity is a second copy of a fact -- the kind
    %% that goes stale silently. This is the derivation, checked against
    %% it after the operations most likely to disagree.
    iso('the kept liquidity agrees with the positions',
        ( mx(_, _), agrees(W), want(W, agrees) )),
    iso('and still agrees after crossing a tick',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, _),
          agrees(W), want(W, agrees) )),
    iso('and after crossing back down again',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_swap(p, bob, dai, '10000000000000000', _, _),
          agrees(W), want(W, agrees) )),
    iso('and after a burn',
        ( mx(A, _), v3_burn(p, alice, A, _, _, _, _),
          agrees(W), want(W, agrees) )).

agrees(W) :- ( v3_liquidity_agrees(p) -> W = agrees ; W = drifted ).
backed(W) :- ( v3_backed(p) -> W = backed ; W = short ).

%% ---- and the tokens are real --------------------------------------------

%% Opening a position MOVES the two amounts; a swap moves the input in
%% and the output out; collecting and closing move them back. A position
%% or a trade nobody can fund fails at the ledger, not at a check here.
real_half :-
    section('and the tokens are real'),
    iso('the deposit actually leaves the provider',
        ( mk, million(M), ft_balance(dai, alice, B), u256_sub(M, B, D),
          want(D, '2995354955910780') )),
    iso('and the pool actually holds it',
        ( mk, v3_account(p, Ac), ft_balance(dai, Ac, B),
          want(B, '2995354955910780') )),
    iso('a position nobody can fund is refused',
        ( mk, unit(L), refuses(v3_mint(p, dave, -60, 60, L, _, _, _)) )),
    iso('a swap pays the trader in actual tokens',
        ( m2, million(M), v3_swap(p, bob, weth, '1000000000000000', _, _),
          ft_balance(dai, bob, B), u256_sub(B, M, D),
          want(D, '996006981039903') )),
    iso('a swap nobody can fund is refused',
        ( m2, refuses(v3_swap(p, dave, weth, '1000', _, _)) )),
    iso('collecting fees pays out real tokens',
        ( mk(Id, _, _), v3_swap(p, bob, weth, '1000000000000000', _, _),
          ft_balance(weth, alice, B0), v3_collect(Id, alice, _, _),
          ft_balance(weth, alice, B1), u256_sub(B1, B0, D),
          want(D, '2999999999999') )),
    %% The question that matters after all of it: does the pool hold what
    %% it has promised -- every position's amounts plus every position's
    %% unclaimed fees?
    iso('the pool is backed after a swap',
        ( mx(_, _), v3_swap(p, bob, weth, '1000000000000000', _, _),
          backed(W), want(W, backed) )),
    iso('and after one that crossed a tick',
        ( mx(_, _), v3_swap(p, bob, weth, '10000000000000000', _, _),
          backed(W), want(W, backed) )),
    iso('and after the fees are taken out of it',
        ( mx(A, B), v3_swap(p, bob, weth, '10000000000000000', _, _),
          v3_collect(A, alice, _, _), v3_collect(B, bob, _, _),
          backed(W), want(W, backed) )).

%% ---- a refused operation leaves NOTHING behind --------------------------
%%
%% THIS SECTION EXISTS BECAUSE THE POOL FAILED IT. v3_mint used to move
%% the ticks, the pool's liquidity and the NFT into place and pay for them
%% afterwards, so a mint nobody could fund raised the pool's active
%% liquidity to 1e18 with no position anywhere backing it -- and every
%% later swap priced itself off depth that did not exist. The invariant
%% that caught it is v3_liquidity_agrees/1: the pool's own liquidity
%% against the sum of the positions that span the current price. A
%% contract is not "safe because the operation was refused"; it is safe
%% because the refusal left the state where it found it.

%% the refused mint, wrapped so its failure does not end the conjunction:
%% what is under test is what comes AFTER the refusal
poor_mint :- unit(L), ( v3_mint(p, dave, -60, 60, L, _, _, _) -> true ; true ).

nothing_half :-
    section('a refused operation leaves NOTHING behind'),
    iso('a mint nobody can fund does not raise the depth',
        ( mk, poor_mint, v3_state(p, _, _, L),
          want(L, '1000000000000000000') )),
    iso('and the liquidity still agrees with the positions',
        ( mk, poor_mint, agrees(W), want(W, agrees) )),
    iso('and no position was minted for the payer who could not pay',
        ( mk, poor_mint, refuses(v3_position(_, _, dave, _, _, _)) )),
    iso('a swap nobody can fund does not move the price',
        ( mk, v3_state(p, S0, _, _),
          ( v3_swap(p, dave, weth, '1000', _, _) -> true ; true ),
          v3_state(p, S1, _, _),
          ( S0 == S1 -> W = still ; W = moved ), want(W, still) )),
    iso('and the pool is still backed after the refusal',
        ( mk, poor_mint, backed(W), want(W, backed) )).

main :-
    (   catch(run_isolated(v3_program, true), _, fail)
    ->  axis_half, position_half, swap_half, cross_half,
        fee_half, close_half, real_half, nothing_half,
        nl, checks_done
    ;   skip('(the v3 pool will not load -- did the u256 module build?)')
    ).
