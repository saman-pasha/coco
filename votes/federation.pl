%% The federation for rung 6: whose key is whose.
%%
%% PUBLIC KEYS ONLY, exactly as ledger/federation.pl -- and it is the
%% same predicate, `authority/2', because it answers the same question:
%% which key belongs to which name. What it does NOT answer any more is
%% who may vote and how much they weigh. That is the STAKE, and the stake
%% is not here: it is on the chain, read back by `stake_from_chain/0'.
%%
%% TWO QUESTIONS, TWO SOURCES, and the split is the rung. Admission is a
%% roster -- a certificate authority's business, distributed out of band.
%% Weight is a query over blocks every node already holds. Conflating
%% them is how a system ends up unable to change its validator set
%% without redistributing a file.
%%
%% DAVE IS HERE AND HAS NO STAKE, on purpose: an admitted party who never
%% staked. His signature is perfectly good and his vote counts for
%% nothing, which is what makes "in the federation" and "may vote" two
%% different facts. `attack_no_stake' is that case.
%%
%% MALLORY IS HERE AND DOES HAVE STAKE, also on purpose. Every earlier
%% rung's criminal was an outsider; a Byzantine fault is an INSIDER, and
%% a rung about tolerating faults that only ever tested strangers would
%% have tested nothing. Her keys are the obvious ones (0x4444…, 0x5555…)
%% so anyone can rederive these lines with `secp256k1_pubkey'.

authority(alice,
  '4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa385b6b1b8ead809ca67454d9683fcf2ba03456d6fe2c4abe2b07f0fbdbb2f1c1').
authority(bob,
  '466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f276728176c3c6431f8eeda4538dc37c865e2784f3a9e77d044f33e407797e1278a').
authority(carol,
  '3c72addb4fdf09af94f0c94d7fe92a386a7e70cf8a1d85916386bb2535c7b1b13b306b0fe085665d8fc1b28ae1676cd3ad6e08eaeda225fe38d0da4de55703e0').
authority(mallory,
  '2c0b7cf95324a07d05398b240174dc0c2be444d96b159aa6c7f7b1e668680991ae31a9c671a36543f46cea8fce6984608aa316aa0472a7eed08847440218cb2f').
authority(dave,
  '9ac20335eb38768d2052be1dbbc3c8f6178407458e51e6b4ad22f1d91758895baf102a603fa09b366705fd727757a5abd614410a6e3f802ab8da8dfe84289d64').

%% ---- the stake distribution this rung demonstrates -------------------
%%
%% NOT ASSERTED HERE. These are the amounts votes/run.sh SEALS onto the
%% chain as ordinary blocks, written down so a reader can check the
%% arithmetic the suite depends on:
%%
%%   alice 40   bob 25   carol 20   mallory 15   dave 0
%%
%%   total 100, quorum 67, fault bound 33.
%%
%% The numbers are chosen so the interesting cases are real ones. The
%% three honest validators reach 85 and can finalise without mallory.
%% mallory alone is 15 and cannot do anything at all -- not even with one
%% accomplice, since her best pair is 55. Two conflicting certificates
%% therefore need a coalition of more than a third of the stake, which is
%% precisely what the safety arithmetic says, and `attack_double_qc'
%% builds exactly that coalition rather than pretending she could do it
%% alone.
