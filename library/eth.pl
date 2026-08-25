%% library(eth) -- Ethereum identity, from the two crypto modules.
%%
%% This file is worth reading for what it IS as much as for what it
%% does: a Prolog library that pulls in two COMPILED Cicili modules and
%% composes them. Three of The Coco's four materials meet in nine lines,
%% and the loader resolves all of it at run time -- `use_module' inside
%% a library loads the libraries that library needs.
%%
%%   eth_address(+PubHex, -AddrHex)   an address is the last twenty
%%                                    bytes of keccak256 over the
%%                                    64-byte public key
%%   eth_signer(+HashHex, +SigHex, +RecId, -AddrHex)
%%                                    who signed this: recover the key,
%%                                    then take its address -- the whole
%%                                    question an EVM chain asks of a
%%                                    transaction, in one predicate
%%
%% Addresses come back as 40 lowercase hex digits, no `0x' and no
%% EIP-55 mixed-case checksum: the checksum is a display convention and
%% belongs wherever the display is.

:- use_module(library(keccak)).
:- use_module(library(secp256k1)).

%% The uncompressed SEC form carries an 04 in front; the recovered form
%% does not. Both name the same key and must hash the same, so the
%% prefix comes off before the hash rather than after.
eth_xy(Pub, XY) :-
    atom_length(Pub, 130),
    sub_atom(Pub, 0, 2, _, '04'),
    !,
    sub_atom(Pub, 2, 128, 0, XY).
eth_xy(Pub, Pub).

eth_address(Pub, Addr) :-
    eth_xy(Pub, XY),
    keccak256_hex(XY, Hash),
    sub_atom(Hash, 24, 40, 0, Addr).

eth_signer(HashHex, SigHex, RecId, Addr) :-
    secp256k1_recover(HashHex, SigHex, RecId, Pub),
    eth_address(Pub, Addr).
