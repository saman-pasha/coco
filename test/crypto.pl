%% The chains' primitives, held to PUBLISHED VECTORS rather than to
%% themselves.
%%
%% WHY A VECTOR AND NOT A ROUND TRIP. An implementation checked only
%% against itself is checked against nothing: encrypt-then-decrypt agrees
%% with any consistent mistake. Every constant below was computed outside
%% this project -- FIPS 180 and 202, RFC 7693 and 8032, BIP-173, the
%% secp256k1 generator, Bitcoin's genesis coinbase -- and a failure here
%% means the module is wrong, not that the test is.
%%
%% THE FILE IS A TABLE, because that is what it is. The .sh wrote out
%% `check "..." "$(q "...")" "..."' fifty-odd times with the library's
%% `use_module' repeated in every one; here a vector is a fact and one
%% forall runs them. What that buys beyond brevity: a new vector is a
%% line, and nothing about how it is run can drift between two of them.
%%
%% THE ONES THAT ARE NOT HASHES stay written out, because each says
%% something particular: a signature verifying, the SAME signature
%% failing against another hash, recovery answering the signing key and
%% the wrong recovery id not, a checksum catching one wrong character, a
%% bech32 prefix living inside the checksum, and taproot refused under
%% the old constant.
%%
%% AND EVERY PROLOG LIBRARY IS LOADED at the end -- a .pl with a syntax
%% error in a clause nobody calls is invisible until the day something
%% calls it.
%%
%% SKIPs when the modules cannot be built (no sbcl, or no CICILI).
%%
%% Run:  cocolog -s test/crypto.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

gxy('79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8').
d1('1111111111111111111111111111111111111111111111111111111111111111').
pub1('4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa385b6b1b8ead809ca67454d9683fcf2ba03456d6fe2c4abe2b07f0fbdbb2f1c1').
zabc('4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45').
sig('466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f275ae07fee4307d1463bdae06d383eeff912ae0db208dd20d37998bcd19b5f6316').
bad('0000000000000000000000000000000000000000000000000000000000000001').
h160('751e76e8199196d454941c45d1b3a323f1433bd6').

%% RFC 8032's first two test vectors
ed(1, '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
      'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a', '',
      'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b').
ed(2, '4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb',
      '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c', '72',
      '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00').

%% Bitcoin's genesis coinbase, 204 bytes
genesis_tx('01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac00000000').

%% ---- the vectors, as a table ------------------------------------------
%% vector(Library, Label, PartialGoal, Want) -- the goal is called with
%% one more argument, the answer, appended.

vector(keccak, 'keccak: the empty string', keccak256_hex('0x'),
       'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470').
vector(keccak, 'keccak: abc', keccak256(abc),
       '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45').
vector(keccak, 'keccak: the same, as hex bytes in', keccak256_hex('616263'),
       '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45').
vector(sha512, 'sha512: the empty string', sha512_hex('0x'),
       'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e').
vector(sha512, 'sha512: abc', sha512(abc),
       'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f').
vector(blake2b, 'blake2b-256: abc', blake2b256(abc),
       'bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319').
vector(blake2b, 'blake2b-256: the empty string', blake2b256_hex('0x'),
       '0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8').
vector(blake2b, 'blake2b-512: abc, the RFC 7693 vector', blake2b512(abc),
       'ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923').
vector(blake2b, 'blake2b-512: the empty string', blake2b512_hex('0x'),
       '786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce').
vector(ripemd160, 'ripemd160: the empty string', ripemd160_hex('0x'),
       '9c1185a5c5e9fc54612808977ee8f548b2258d31').
vector(ripemd160, 'ripemd160: abc', ripemd160(abc),
       '8eb208f7e05d987a9b044a8e98c6b087f15a0bfc').
vector(ripemd160, 'ripemd160: message digest', ripemd160('message digest'),
       '5d0689ef49d2fae572b881b123a85ffa21595f36').
vector(sha256, 'sha256: the empty string', sha256_hex('0x'),
       'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855').
vector(sha256, 'sha256: abc', sha256(abc),
       'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad').
vector(base58, 'base58: ''hello world''', base58_encode('68656c6c6f20776f726c64'),
       'StV1DL6CwTryKyV').
vector(base58, 'base58: and back again', base58_decode('StV1DL6CwTryKyV'),
       '68656c6c6f20776f726c64').
vector(base58, 'base58: a leading zero byte is a leading 1',
       base58_encode('00751e76e8199196d454941c45d1b3a323f1433bd6'),
       '12ddvLKZUnFosBYkLrzayChzQUNzq').

%% THE LONG ONES, which cross a block boundary: 200 bytes of `a'. The
%% padding is where a hash gets written wrong, so each family gets one.
long_vector(keccak, 'keccak: 200 bytes, across the rate', keccak256,
            '96ea54061def936c4be90b518992fdc6f12f535068a256229aca54267b4d084d').
long_vector(sha512, 'sha512: 200 bytes, a second block', sha512,
            '4b11459c33f52a22ee8236782714c150a3b2c60994e9acee17fe68947a3e6789f31e7668394592da7bef827cddca88c4e6f86e4df7ed1ae6cba71f3e98faee9f').
long_vector(blake2b, 'blake2b-256: 200 bytes, a second block', blake2b256,
            '6b6e59aaf00eb730cf93de53560846722184bbd92f8368c21ffa95380c2f9fe6').
long_vector(sha256, 'sha256: 200 bytes, a second block', sha256,
            'c2a908d98f5df987ade41b5fce213067efbcc21ef2240212a41e54b5e7c28ae5').

main :-
    (   modules_ready(crypto, [keccak, secp256k1, sha512, ed25519,
                               sha256, ripemd160, blake2b])
    ->  checks
    ;   skip('(the crypto modules would not build -- no sbcl or CICILI checkout)')
    ).

checks :-
    gxy(GXY), d1(D), pub1(PUB), zabc(Z), sig(SIG), bad(BAD), h160(H160),

    section('hashes, against published vectors'),
    forall(vector(Lib, L, P, W), vector_check(Lib, L, P, W)),
    forall(long_vector(Lib, L, F, W), long_check(Lib, L, F, W)),

    section('secp256k1: the curve, and what a signature is worth'),
    iso('secp256k1: private key 1 is the generator',
        ( use_module(library(secp256k1)), secp256k1_pubkey('01', P), want(P, GXY) )),
    iso('secp256k1: private key 2 is 2G',
        ( use_module(library(secp256k1)), secp256k1_pubkey('02', P),
          want(P, 'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a') )),
    iso('secp256k1: a key derives from its secret',
        ( use_module(library(secp256k1)), secp256k1_pubkey(D, P), want(P, PUB) )),
    iso('secp256k1: a good signature verifies',
        ( use_module(library(secp256k1)), secp256k1_verify(Z, SIG, PUB) )),
    %% THE SAME SIGNATURE, ANOTHER HASH: a verifier that ignored the
    %% message would pass the check above and fail this one.
    iso('secp256k1: the same signature, another hash',
        ( use_module(library(secp256k1)), refuses(secp256k1_verify(BAD, SIG, PUB)) )),
    iso('secp256k1: the uncompressed 04 spelling',
        ( use_module(library(secp256k1)), sh_join(['04', PUB], P4),
          secp256k1_verify(Z, SIG, P4) )),
    iso('secp256k1: recovery answers the signing key',
        ( use_module(library(secp256k1)), secp256k1_recover(Z, SIG, 0, P),
          want(P, PUB) )),
    iso('secp256k1: the wrong recovery id does not',
        ( use_module(library(secp256k1)), secp256k1_recover(Z, SIG, 1, P),
          ( P \== PUB -> true ; format("     the wrong id gave the right key~n"), fail ) )),

    section('ed25519: RFC 8032, byte for byte'),
    forall(ed(N, S, P, M, G), ed_check(N, S, P, M, G)),
    iso('ed25519: and both verify',
        ( use_module(library(ed25519)),
          ed(1, _, P1, M1, G1), ed(2, _, P2, M2, G2),
          ed25519_verify(M1, G1, P1), ed25519_verify(M2, G2, P2) )),
    iso('ed25519: another message does not',
        ( use_module(library(ed25519)), ed(2, _, P2, _, G2),
          refuses(ed25519_verify('73', G2, P2)) )),
    iso('ed25519: another key does not',
        ( use_module(library(ed25519)), ed(1, _, P1, _, _), ed(2, _, _, M2, G2),
          refuses(ed25519_verify(M2, G2, P1)) )),

    section('eth: an address, and who signed this'),
    iso('eth: the address of private key 1',
        ( use_module(library(eth)), eth_address(GXY, A),
          want(A, '7e5f4552091a69125d5dfcb7b8c2659029395bdf') )),
    iso('eth: an address from the 04 spelling too',
        ( use_module(library(eth)), sh_join(['04', GXY], G4), eth_address(G4, A),
          want(A, '7e5f4552091a69125d5dfcb7b8c2659029395bdf') )),
    iso('eth: who signed this -- recover to an address',
        ( use_module(library(eth)), eth_signer(Z, SIG, 0, A),
          want(A, '19e7e376e7c213b7e7e7e46cc70a5dd086daff2a') )),

    section('btc: the same key, two addresses, and a real transaction'),
    iso('btc: hash160 of the compressed key for secret 1',
        ( use_module(library(btc)), btc_hash160(GXY, H), want(H, H160) )),
    iso('btc: the compressed form picks its prefix from y',
        ( use_module(library(btc)), btc_compress(GXY, C),
          want(C, '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798') )),
    iso('btc: the genesis coinbase transaction, 204 bytes',
        ( use_module(library(btc)), genesis_tx(TX), btc_txid(TX, T),
          want(T, '4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b') )),
    iso('btc: the 1... address of private key 1',
        ( use_module(library(btc)), btc_address(GXY, A),
          want(A, '1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH') )),
    iso('btc: and the bc1... address of the same key',
        ( use_module(library(btc)), btc_segwit(GXY, A),
          want(A, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4') )),

    section('base58check and bech32: the checksums earn their keep'),
    iso('base58check: the address of private key 1',
        ( use_module(library(base58)), base58check_encode('00', H160, A),
          want(A, '1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH') )),
    iso('base58check: read back, version and payload',
        ( use_module(library(base58)),
          base58check_decode('1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH', V, P),
          want(V-P, '00'-H160) )),
    iso('base58check: one character wrong is refused',
        ( use_module(library(base58)),
          refuses(base58check_decode('1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMj', _, _)) )),
    iso('bech32: P2WPKH, the BIP-173 vector',
        ( use_module(library(bech32)), segwit_encode(bc, 0, H160, A),
          want(A, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4') )),
    %% THE PREFIX IS IN THE CHECKSUM: the same program under `tb' is not
    %% the same string with a different first two letters.
    iso('bech32: the prefix is in the checksum',
        ( use_module(library(bech32)), segwit_encode(tb, 0, H160, A),
          want(A, 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx') )),
    iso('bech32: P2WSH, a 32-byte program',
        ( use_module(library(bech32)),
          segwit_encode(bc, 0,
              '1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262', A),
          want(A, 'bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3') )),
    %% BECH32M IS A DIFFERENT CHECKSUM CONSTANT, used from version 1 up.
    %% These two are its vectors, and the refusal further down is the
    %% other half: version 1 must not read under version 0's constant.
    iso('bech32m: taproot, version 1',
        ( use_module(library(bech32)),
          segwit_encode(bc, 1,
              '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798', A),
          want(A, 'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0') )),
    iso('bech32m: version 16, a 2-byte program',
        ( use_module(library(bech32)), segwit_encode(bc, 16, '751e', A),
          want(A, 'bc1sw50qgdz25j') )),
    iso('bech32: decode answers version and program',
        ( use_module(library(bech32)),
          segwit_decode(bc, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', V, P),
          want(V-P, 0-H160) )),
    iso('bech32: all upper case is legal too',
        ( use_module(library(bech32)),
          segwit_decode(bc, 'BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4', V, _),
          want(V, 0) )),
    iso('bech32: mixed case is not',
        ( use_module(library(bech32)),
          refuses(segwit_decode(bc, 'Bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4', _, _)) )),
    iso('bech32: one character wrong is refused',
        ( use_module(library(bech32)),
          refuses(segwit_decode(bc, 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5', _, _)) )),
    %% BECH32M IS A DIFFERENT CONSTANT, and taproot uses it: reading a
    %% version-1 address with version-0's constant must fail, or the two
    %% encodings are one encoding with a bug.
    iso('bech32m: taproot under the OLD constant is refused',
        ( use_module(library(bech32)),
          refuses(segwit_decode(bc,
              'bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqxsg440', _, _)) )),

    section('every Prolog library loads'),
    forall(member(Lib, [bytes, base58, bech32, eth, btc, poa, contract, settle,
                        poh, pos, bft, hub, tickmath, coco]),
           loads_check(Lib)),

    nl, checks_done.

%% ONE VECTOR: the partial goal gets the answer appended, so the table
%% carries the CALL and the constant and nothing else.
vector_check(Lib, L, Partial, Want) :-
    iso(L, ( use_lib(Lib), Partial =.. Xs, append(Xs, [H], Ys), G =.. Ys,
             call(G), want(H, Want) )).

%% 200 bytes of `a' -- the length that crosses a block boundary in every
%% one of these constructions
long_check(Lib, L, F, Want) :-
    iso(L, ( use_lib(Lib), findall(97, between(1, 200, _), Cs),
             G =.. [F, Cs, H], call(G), want(H, Want) )).

ed_check(N, S, P, M, G) :-
    sh_join(['ed25519: RFC 8032 test ', N, ', the public key'], L1),
    iso(L1, ( use_module(library(ed25519)), ed25519_pubkey(S, Pk), want(Pk, P) )),
    sh_join(['ed25519: RFC 8032 test ', N, ', the signature'], L2),
    iso(L2, ( use_module(library(ed25519)), ed25519_sign(S, M, Sg), want(Sg, G) )).

loads_check(Lib) :-
    sh_join(['library(', Lib, ') loads'], L),
    iso(L, ( use_lib(Lib) )).

%% `use_module(library(X))' with X a variable: the directive form needs
%% the name at read time, so this is the goal form.
use_lib(Lib) :- G =.. [library, Lib], use_module(G).
