%% The federation: who may seal a block on this chain.
%%
%% PUBLIC KEYS ONLY. A node loads this to know whom to believe; it never
%% needs anyone's private key but its own, and its own is not here --
%% `node.pl' takes it from the environment, so a federation file can be
%% published, gossiped, or committed to a repository without care.
%%
%% This is the demonstration federation and its keys are the obvious
%% ones (0x1111…, 0x2222…, 0x3333…), so that anyone reading can rederive
%% every public key below with `secp256k1_pubkey' and check that this
%% file is honest. A real federation's keys come from the CA that issued
%% its certificates, and this file is what the CA's roster compiles to.
%%
%% THE ORDER OF THE NAMES IS THE SCHEDULE. `in_turn/2' sorts them, so
%% the round robin is alphabetical: alice at height 0, bob at 1, carol
%% at 2, alice at 3. Nobody is told whose turn it is -- every node
%% computes it from this list and the height, which is what makes the
%% schedule checkable rather than announced.

authority(alice,
  '4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa385b6b1b8ead809ca67454d9683fcf2ba03456d6fe2c4abe2b07f0fbdbb2f1c1').
authority(bob,
  '466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f276728176c3c6431f8eeda4538dc37c865e2784f3a9e77d044f33e407797e1278a').
authority(carol,
  '3c72addb4fdf09af94f0c94d7fe92a386a7e70cf8a1d85916386bb2535c7b1b13b306b0fe085665d8fc1b28ae1676cd3ad6e08eaeda225fe38d0da4de55703e0').

%% Not an authority, and present on purpose: the suite seals a block
%% with mallory's key and every node must refuse it. A federation that
%% is never tested against a non-member is a federation that has never
%% been tested.
%% mallory's private key is 4444...4444; her public key is deliberately
%% NOT declared above.
