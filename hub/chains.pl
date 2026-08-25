%% The member chains, and the rules each one publishes about itself.
%%
%% THESE ARE NOT THE HOST'S RULES. Every clause below is sealed onto the
%% chain it belongs to, as an ordinary block payload, and the host reads
%% it back. Nothing here is compiled into the aggregator, and the
%% aggregator has no idea what any of these chains are until it reads
%% them.
%%
%% THREE CHAINS, THREE REGIMES, ONE HOST:
%%
%%   zeta   a proof-of-authority chain. Two authorities, and the longest
%%          chain wins -- rung 2's shape.
%%   omega  a stake-weighted chain. Different validators, and the head
%%          with the most stake behind it wins, whatever its height --
%%          which is a fork choice zeta would call wrong.
%%   psi    mallory's chain, and its rules are impeccable. See
%%          `attack_captured_chain'.
%%
%% The keys are the demonstration keys, the same ones ledger/federation.pl
%% and votes/federation.pl publish, so anyone can rederive them.

chain_source(zeta, [
  ( zeta_valid(block(H, P, A, Pay, S, Hash)) :-
      block_hash(H, P, A, Pay, Hash),
      zeta_authority(A, K),
      secp256k1_verify(Hash, S, K) ),
  zeta_authority(alice,
    '4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa385b6b1b8ead809ca67454d9683fcf2ba03456d6fe2c4abe2b07f0fbdbb2f1c1'),
  zeta_authority(bob,
    '466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f276728176c3c6431f8eeda4538dc37c865e2784f3a9e77d044f33e407797e1278a'),
  %% the longest chain wins, and a tie goes to the lower hash
  ( zeta_better(head(HA, _, _), head(HB, _, _)) :- HA > HB ),
  ( zeta_better(head(H, A, _), head(H, B, _)) :- A @< B ),
  ( zeta_final(head(HA, _, _), Depth) :- Depth >= 6, HA >= 0 )
]).

chain_source(omega, [
  ( omega_valid(block(H, P, A, Pay, S, Hash)) :-
      block_hash(H, P, A, Pay, Hash),
      omega_validator(A, K),
      secp256k1_verify(Hash, S, K) ),
  omega_validator(carol,
    '3c72addb4fdf09af94f0c94d7fe92a386a7e70cf8a1d85916386bb2535c7b1b13b306b0fe085665d8fc1b28ae1676cd3ad6e08eaeda225fe38d0da4de55703e0'),
  omega_validator(alice,
    '4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa385b6b1b8ead809ca67454d9683fcf2ba03456d6fe2c4abe2b07f0fbdbb2f1c1'),
  %% NOT the longest: the head with the most stake behind it, however
  %% short. zeta would call this the wrong answer, and omega would say
  %% the same about zeta's. Neither has to be persuaded.
  ( omega_better(head(_, _, SA), head(_, _, SB)) :- SA > SB ),
  ( omega_final(head(_, _, S), Total) :- Q is (Total * 2) // 3 + 1, S >= Q )
]).

chain_source(psi, [
  ( psi_valid(block(H, P, A, Pay, S, Hash)) :-
      block_hash(H, P, A, Pay, Hash),
      psi_validator(A, K),
      secp256k1_verify(Hash, S, K) ),
  psi_validator(mallory,
    '2c0b7cf95324a07d05398b240174dc0c2be444d96b159aa6c7f7b1e668680991ae31a9c671a36543f46cea8fce6984608aa316aa0472a7eed08847440218cb2f'),
  ( psi_better(head(HA, _, _), head(HB, _, _)) :- HA > HB ),
  ( psi_final(head(_, _, S), Total) :- Q is (Total * 2) // 3 + 1, S >= Q )
]).

%% What each chain's stake adds up to, for its own `_final' rule. On psi
%% it adds up to mallory, which is the whole point of psi.
chain_total(zeta, 100).
chain_total(omega, 100).
chain_total(psi, 100).
