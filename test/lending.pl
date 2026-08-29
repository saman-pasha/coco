%% Aave's shape: a pot lent against collateral, priced by an oracle.
%%
%% FOUR THINGS ARE BEING PINNED, and the last is the one a lending pool
%% written as arithmetic gets wrong:
%%
%%   THE RATE IS A CURVE WITH A KINK. Half the pot lent is 50%
%%   utilization and costs 2.5% at a 4% slope; past the kink at 90% it is
%%   34%. Suppliers get a share of what borrowers pay, never more, and
%%   the borrow rate always exceeds the supply rate -- if it did not, the
%%   pot would be paying people to hold it.
%%
%%   INTEREST IS AN INDEX, NOT A LOOP. Nobody is credited; the index
%%   moves and every position is read through it. The borrow index
%%   compounds and the supply index is linear, which is why the first
%%   passes the second, and time cannot run backwards.
%%
%%   HEALTH IS A PRICE QUESTION. The same position is healthy at 1.6 and
%%   unsafe at 0.96 with no transaction in between -- only the oracle
%%   moved. Owing nothing is `infinite' rather than a large number,
%%   because a ratio with zero underneath is not a number.
%%
%%   AND A REFUSED OPERATION LEAVES NOTHING BEHIND. Six checks at the end
%%   do nothing but that: a borrow past the LTV leaves no debt AND pays
%%   out no tokens AND leaves the pot solvent; an unfundable supply
%%   leaves no balance; a refused liquidation seizes nothing. A pool that
%%   half-performs a refused operation is a pool with a hole in it, and
%%   the hole is invisible to any check that only looks at the return
%%   value.
%%
%% SOLVENCY IS CHECKED AFTER EVERY KIND OF OPERATION, because a pot that
%% only balances at rest is not solvent, it is lucky.
%%
%% SKIPs when the pool will not load (did the u256 module build?).
%%
%% Run:  cocolog -s test/lending.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

rich('1000000000000000000000000').

%% two tokens, two holders, a pool configured, and an oracle
init :- rich(M),
        ft_create(dai, 'DAI', 18), ft_create(weth, 'WETH', 18),
        ft_mint(dai, alice, M), ft_mint(dai, bob, M),
        ft_mint(weth, alice, M), ft_mint(weth, bob, M),
        aave_init(dai, '7500', '8000', '500', '1000'),
        aave_init(weth, '7500', '8000', '500', '1000'),
        aave_price(dai, 1), aave_price(weth, 100).

%% half the dai pot lent
half :- init, aave_supply(dai, alice, '1000'), aave_supply(weth, bob, '100'),
        aave_borrow(dai, bob, '500').
%% nine tenths of it
ninety :- init, aave_supply(dai, alice, '1000'), aave_supply(weth, bob, '100'),
          aave_borrow(dai, bob, '900').
%% alice borrowing against weth, with bob's dai in the pot
pos :- init, aave_supply(dai, bob, '100000'), aave_supply(weth, alice, '100'),
       aave_borrow(dai, alice, '5000').
%% the same position after the oracle moves against her
sick :- pos, aave_price(weth, 60).
%% the pot, funded, before a borrow that will be refused
ready :- init, aave_supply(weth, alice, '100'), aave_supply(dai, bob, '100000').

main :-
    (   catch(( use_module('contracts/token/fungible.pl'),
                use_module('contracts/lending/aave.pl') ), _, fail)
    ->  checks
    ;   skip('(the lending pool will not load -- did the u256 module build?)')
    ).

checks :-
    section('the pot'),
    iso('supplying puts it in and it reads back',
        ( init, aave_supply(dai, alice, '1000'), aave_supplied(dai, alice, A),
          want(A, '1000') )),
    iso('and the pool actually holds the tokens',
        ( init, aave_supply(dai, alice, '1000'), aave_account(dai, Ac),
          ft_balance(dai, Ac, B), want(B, '1000') )),
    iso('supplying what you do not have is refused',
        ( init, refuses(aave_supply(dai, dave, '1000')) )),
    iso('withdrawing more than you supplied is refused',
        ( init, aave_supply(dai, alice, '1000'),
          refuses(aave_withdraw(dai, alice, '2000')) )),
    iso('a withdrawal past the LIQUIDITY is refused too',
        ( init, aave_supply(dai, alice, '1000'), aave_supply(weth, bob, '100'),
          aave_borrow(dai, bob, '900'),
          refuses(aave_withdraw(dai, alice, '1000')) )),

    section('the rate curve'),
    iso('half the pot lent is 50% utilization',
        ( half, aave_utilization(dai, U), want(U, '500000000000000000000000000') )),
    iso('which costs 2.5% at a 4% slope to 80%',
        ( half, aave_rates(dai, _, B), want(B, '25000000000000000000000000') )),
    iso('and suppliers get 1.125% of that',
        ( half, aave_rates(dai, S, _), want(S, '11250000000000000000000000') )),
    iso('past the kink at 90%, the rate is 34%',
        ( ninety, aave_rates(dai, _, B), want(B, '340000000000000000000000000') )),
    iso('the borrow rate always exceeds the supply rate',
        ( half, aave_rates(dai, S, B), u256_cmp(S, B, C), want(C, <) )),

    section('interest, through the indexes'),
    iso('a year on, the debt has grown',
        ( pos, aave_accrue(dai, '31536000'), aave_debt(dai, alice, D),
          want(D, '5013') )),
    iso('and the supplier has earned, without being credited',
        ( pos, aave_accrue(dai, '31536000'), aave_supplied(dai, bob, S),
          want(S, '100011') )),
    iso('no time passing means no interest',
        ( pos, aave_accrue(dai, '0'), aave_debt(dai, alice, D), want(D, '5000') )),
    iso('accruing backwards is refused',
        ( pos, aave_accrue(dai, '31536000'),
          refuses(aave_accrue(dai, '1000')) )),
    iso('the borrow index compounds past the linear one',
        ( pos, aave_accrue(dai, '31536000'), aave_index(dai, L, B),
          u256_cmp(B, L, C), want(C, >) )),

    section('health, which is a price question'),
    iso('the position is healthy at 1.6',
        ( pos, aave_health(alice, H), want(H, '1600000000000000000000000000') )),
    iso('owing nothing is not a number',
        ( init, aave_supply(weth, alice, '100'), aave_health(alice, H),
          want(H, infinite) )),
    iso('borrowing right up to the LTV is allowed',
        ( ready, aave_borrow(dai, alice, '7500') )),
    iso('and one wei past it is not',
        ( ready, refuses(aave_borrow(dai, alice, '7501')) )),
    iso('borrowing past the LTV is refused',
        ( ready, refuses(aave_borrow(dai, alice, '9000')) )),
    iso('the oracle moves and the position becomes unsafe',
        ( sick, aave_health(alice, H), want(H, '960000000000000000000000000') )),
    iso('a withdrawal that would unbalance it is refused',
        ( pos, refuses(aave_withdraw(weth, alice, '90')) )),

    section('liquidation'),
    iso('a healthy position may not be liquidated',
        ( pos, refuses(aave_liquidate(dai, weth, bob, alice, '2500', _)) )),
    iso('an unhealthy one may, seizing collateral plus 5%',
        ( sick, aave_liquidate(dai, weth, bob, alice, '2500', S), want(S, '43') )),
    iso('the close factor caps it at half the debt',
        ( sick, aave_liquidate(dai, weth, bob, alice, '99999', S), want(S, '43') )),
    iso('the debt fell by what was repaid',
        ( sick, aave_liquidate(dai, weth, bob, alice, '2500', _),
          aave_debt(dai, alice, D), want(D, '2500') )),
    iso('and the position is healthy again',
        ( sick, aave_liquidate(dai, weth, bob, alice, '2500', _),
          aave_health(alice, H), want(H, '1094400000000000000000000000') )),
    iso('the liquidator is really paid in tokens',
        ( sick, ft_balance(weth, bob, B0),
          aave_liquidate(dai, weth, bob, alice, '2500', _),
          ft_balance(weth, bob, B1), u256_sub(B1, B0, D), want(D, '43') )),

    section('solvency, after each kind of operation'),
    iso('after supplying and borrowing',
        ( pos, aave_solvent(dai), aave_solvent(weth) )),
    iso('after a repayment',
        ( pos, aave_repay(dai, alice, '2000'), aave_solvent(dai) )),
    iso('after a year of interest',
        ( pos, aave_accrue(dai, '31536000'), aave_solvent(dai) )),
    iso('and after a liquidation',
        ( sick, aave_liquidate(dai, weth, bob, alice, '2500', _),
          aave_solvent(dai), aave_solvent(weth) )),
    iso('repaying more than owed repays only what is owed',
        ( pos, aave_repay(dai, alice, '99999'), aave_debt(dai, alice, D),
          want(D, '0') )),

    section('a refused operation leaves NOTHING behind'),
    iso('a borrow past the LTV leaves no debt behind',
        ( ready, ( aave_borrow(dai, alice, '9000') -> true ; true ),
          aave_debt(dai, alice, D), want(D, '0') )),
    iso('and it did not pay out the tokens either',
        ( ready, ft_balance(dai, alice, B0),
          ( aave_borrow(dai, alice, '9000') -> true ; true ),
          ft_balance(dai, alice, B1), u256_sub(B1, B0, D), want(D, '0') )),
    iso('and the pot is still solvent after the refusal',
        ( ready, ( aave_borrow(dai, alice, '9000') -> true ; true ),
          aave_solvent(dai) )),
    iso('a supply nobody can fund leaves no balance behind',
        ( init, ( aave_supply(dai, dave, '1000') -> true ; true ),
          aave_supplied(dai, dave, A), want(A, '0') )),
    iso('a withdrawal past the balance leaves the balance alone',
        ( init, aave_supply(dai, alice, '1000'),
          ( aave_withdraw(dai, alice, '2000') -> true ; true ),
          aave_supplied(dai, alice, A), want(A, '1000') )),
    iso('and a refused liquidation seizes nothing',
        ( pos, ft_balance(weth, bob, B0),
          ( aave_liquidate(dai, weth, bob, alice, '2500', _) -> true ; true ),
          ft_balance(weth, bob, B1), u256_sub(B1, B0, D), want(D, '0') )),

    nl, checks_done.
