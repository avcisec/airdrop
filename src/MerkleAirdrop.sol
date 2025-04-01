// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity 0.8.24;

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                         Imports                            */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MerkleAirdrop
 * @author 0xavci
 * @notice This contract is an implementation of merkle proofs to airdrop a ERC20 token in an efficient way.
 *
 */
contract MerkleAirdrop is EIP712 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          Errors                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    // 1. list of addresses
    /**
     * Eğer bir adress array oluşturur ve for döngüsü ile buraya claim edenleri doldurursak,
     * for döngüsü array length büyümesi sebebiyle gas inefficient olacaktır. Hatta bir noktada DoS zaafiyeti
     * olacaktır. Bu çözüm etkili bir çözüm değildir. Bu yüzden Merkle Proofs kullanacağız.
     */
    // allow someone in the list to claim tokens

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Type Declarations                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    using SafeERC20 for IERC20;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    State Variables                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    address[] claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account, uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    /**
     * Aşağıdaki mapping claimed kullanıcıları takip etmek içn en ideal yöntem değildir.
     * Böyle bir mapping oluşturduğumuzda her bir boolean değeri için komple storage slotu alırız.
     * Her bir adresin storage slotu olur. Bu gas tüketimi açısından etkin bir çözüm değildir.
     * Peki ne yapabiliriz?
     * Bool[] yöntemi
     * Yaprakları off-chain hazırladığımız bir senaryo için,
     * her bir yaprak için index değeri atarsak ve boolean değerini verirsek
     * kullanıcı claim fonksiyonunu çağırdığında index değerini bool dizisinde ararız ve kullanıcının
     * airdrop hakkı varsa false olan değeri true yapar kullanıcıya tokeni aktarırız.
     * boolean 8 bittir oyüzden gene de ihtiyacımız olandan fazla bit kullanmış olacağız. Daha da optimize  edebiliriz.
     *
     * uint256[] yöntemi
     * mapping(uint256 => uint256) yöntemi
     *
     */
    mapping(address user => bool claimed) private s_claimed;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          Events                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event Claim(address indexed user, uint256 indexed amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        Functions                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(bytes32 merkleRoot, IERC20 airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_claimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }
        //check the signature

        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // calculate using the account and  the amount, the hash --> leaf node
        // when we are using merkle proofs, we need to hash it twice to prevent collision.
        // If we hash it twice, we are avoiding hash collision problem. This is known as Second pre-image attack
        // Hashing it twice is a standard.

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }

        s_claimed[account] = true;
        emit Claim(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);

        return actualSigner == account;
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    function getClaimStatus(address user) external view returns (bool) {
        return s_claimed[user];
    }
}
