%% contracts/token/units -- a game's units as non-fungible tokens.
%%
%% The Coco's future-work page says it in one line: "Units are NFTs by
%% construction -- CivV's capture clause already retracts one
%% `unit_owner' row and asserts another, which IS transfer; production
%% mints, the kill burns." This is that sentence as a deployed contract.
%%
%% It is a FENCED contract and not a library, which is the whole point:
%% it is meant to be reached BY TRANSACTION, so a match's referee mints
%% by sending a signed `call(units, unit_mint(...))' and pays gas for it
%% like anybody else. That is only safe because of the capability this
%% rung added underneath it -- `caller/1'. A contract that cannot ask who
%% is calling cannot own anything, and every ownership predicate in this
%% repository took its owner as an ARGUMENT until now.
%%
%%   unit_open_match(M)          the caller becomes M's referee
%%   unit_referee(M, Who)
%%   unit_mint(Id, Kind, M, To)  the referee of M produces a unit
%%   unit_capture(Id, To)        the referee moves it -- no consent
%%   unit_give(Id, To)           the HOLDER moves it -- a trade
%%   unit_kill(Id)               the referee burns it, forever
%%   unit_holder(Id, Who)  unit_kind(Id, K)  unit_home(Id, M)
%%   unit_alive(Id)        unit_dead(Id)
%%
%% CAPTURE IS NOT A TRANSFER THE OWNER AGREES TO, and that is the one
%% place this collection departs from ERC-721 on purpose. The standard's
%% whole structure is consent: the owner moves their own, or somebody
%% they approved does. A captured unit is taken. So the referee of a
%% unit's own match may move it without asking -- and that power is
%% fenced by the two things that make it bearable: a referee is named
%% per MATCH and reaches nothing outside it, and a unit carries the match
%% it was produced in for its whole life.
%%
%% A HOLDER CAN STILL TRADE, which is what makes these tokens rather than
%% rows: `unit_give/2' is the ordinary consented move, and only the
%% holder may call it.
%%
%% A BURNT ID IS NEVER REISSUED. State here is append-only, so
%% `unit_mint/4' refuses any id that has ever existed -- not merely any
%% id alive now. A collection that reissued a dead id would have two
%% units with one provenance, and provenance is the only thing a chain
%% can actually offer a game.
%%
%% WHAT THE CHAIN CANNOT CHECK, and it is the honest limit of the whole
%% idea: THE GAME'S OWN RULES. A referee's signature is the only evidence
%% that a unit was produced legally -- that the side had the production,
%% the technology, the room. A referee who lies mints an army out of
%% nothing and this contract will hold it. The answer is not more rules
%% here; it is the dispute verifier the plan names as its last rung -- a
%% bare process replays the match's order log and the signatures decide
%% who lied. Until that exists, a unit NFT is exactly as honest as its
%% referee, and saying so is cheaper than implying otherwise.
%%
%% The other stated limit: a unit crossing into ANOTHER match must pass
%% that match's own production fences, which this contract has no way to
%% enforce either. Owning a Musketeer does not mean you may field one.

contract_source(units, [

    %% ---- the referee -------------------------------------------------
    %% Permissionless, and first come: opening a match makes you its
    %% referee and nobody else's. `nobody' is what a direct call reports,
    %% so every guard here refuses it -- ownership can only be exercised
    %% through a signed transaction.
    ( unit_open_match(M) :-
        ground(M),
        caller(Who), Who \== nobody,
        \+ state_has(ref(M)),
        state_put(ref(M), Who) ),

    ( unit_referee(M, Who) :- state_get(ref(M), Who) ),

    %% ---- production, capture, trade, death ---------------------------
    ( unit_mint(Id, Kind, M, To) :-
        ground(Id), ground(Kind), ground(To), To \== nobody,
        caller(Who), Who \== nobody,
        state_get(ref(M), Who),
        \+ state_has(kind_of(Id)),
        state_put(kind_of(Id), Kind),
        state_put(home_of(Id), M),
        state_put(hold(Id), To) ),

    ( unit_capture(Id, To) :-
        ground(To), To \== nobody,
        unit_alive(Id),
        caller(Who), Who \== nobody,
        state_get(home_of(Id), M),
        state_get(ref(M), Who),
        state_put(hold(Id), To) ),

    ( unit_give(Id, To) :-
        ground(To), To \== nobody,
        unit_alive(Id),
        caller(Who), Who \== nobody,
        state_get(hold(Id), Who),
        state_put(hold(Id), To) ),

    ( unit_kill(Id) :-
        unit_alive(Id),
        caller(Who), Who \== nobody,
        state_get(home_of(Id), M),
        state_get(ref(M), Who),
        state_put(gone(Id), true) ),

    %% ---- reading it --------------------------------------------------
    ( unit_alive(Id) :- state_has(kind_of(Id)), \+ state_has(gone(Id)) ),
    ( unit_dead(Id) :- state_has(gone(Id)) ),
    ( unit_holder(Id, Who) :- unit_alive(Id), state_get(hold(Id), Who) ),
    ( unit_kind(Id, K) :- state_get(kind_of(Id), K) ),
    ( unit_home(Id, M) :- state_get(home_of(Id), M) )
]).
