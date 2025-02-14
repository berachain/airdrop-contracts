// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@solady/utils/MerkleProofLib.sol";
import "@solady/utils/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./Transferable.sol";

//   ____ _ _
//  / ___| (_) __ _ _   _  ___
// | |   | | |/ _` | | | |/ _ \
// | |___| | | (_| | |_| |  __/
//  \____|_|_|\__, |\__,_|\___|        _               _
// |  _ \(_)___| |_|_ __(_) |__  _   _| |_ ___  _ __  / |
// | | | | / __| __| '__| | '_ \| | | | __/ _ \| '__| | |
// | |_| | \__ \ |_| |  | | |_) | |_| | || (_) | |    | |
// |____/|_|___/\__|_|  |_|_.__/ \__,_|\__\___/|_|    |_|

/// @title Distributor1
/// @notice Clique Airdrop contract (Mekle + ECDSA + Paymaster)
/// @author Clique (@Clique2046)
/// @author Eillo (@0xEillo)
contract Distributor1 is Ownable2Step, Transferable {
    // address signing the claims
    address public signer;
    // root of the merkle tree
    bytes32 public claimRoot;
    // whether the airdrop is active
    bool public active = false;
    // fee to be paid to the paymaster
    uint256 public fee;

    // mapping of addresses to whether they have claimed
    mapping(address => bool) public claimed;

    // errors
    error InsufficientBalance();
    error AlreadyClaimed();
    error InvalidSignature();
    error InvalidMerkleProof();
    error NotActive();
    error InsufficientFee();
    error MerkleRootNotSet();

    event ClaimRootUpdated(bytes32 indexed claimRoot);
    event FeeUpdated(uint256 indexed fee);
    event ContractActivated(bool indexed active);
    event SignerUpdated(address indexed signer);

    event AirdropClaimed(address indexed paymaster, uint256 amount, address indexed onBehalfOf);

    /// @notice Construct a new Claim contract
    /// @param _signer address that can sign messages
    /// @param _token address of the token that will be claimed
    constructor(address _signer, address _token) Ownable(msg.sender) Transferable(_token) {
        signer = _signer;
    }

    /// @notice Set the signer
    /// @param _signer address that can sign messages
    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
        emit SignerUpdated(_signer);
    }

    /// @notice Set the fee
    /// @param _fee fee to be paid to the paymaster
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    /// @notice Set the claim root
    /// @param _claimRoot root of the merkle tree
    function setClaimRoot(bytes32 _claimRoot) external onlyOwner {
        claimRoot = _claimRoot;
        emit ClaimRootUpdated(_claimRoot);
    }

    /// @notice Toggle the active state

    function toggleActive() external onlyOwner {
        if (claimRoot == bytes32(0)) revert MerkleRootNotSet();
        active = !active;
        emit ContractActivated(active);
    }

    /// @notice Claim airdrop tokens. Checks for both merkle proof
    //          and signature validation
    /// @param _proof merkle proof of the claim
    /// @param _signature signature of the claim
    /// @param _amount amount of tokens to claim
    /// @param _onBehalfOf address to claim on behalf of
    function claim(bytes32[] calldata _proof, bytes calldata _signature, uint256 _amount, address _onBehalfOf)
        external
    {
        if (balance() < _amount) {
            revert InsufficientBalance();
        }
        if (claimed[_onBehalfOf]) revert AlreadyClaimed();
        if (!active) revert NotActive();

        claimed[_onBehalfOf] = true;

        _rootCheck(_proof, _amount, _onBehalfOf);
        _signatureCheck(_amount, _signature, _onBehalfOf);

        uint256 amount = _amount;

        if (tx.origin != _onBehalfOf) {
            uint256 _fee = fee;
            require(_fee != 0, "Gas fee not set");
            amount -= _fee;
            transfer(tx.origin, _fee);
        }

        transfer(_onBehalfOf, amount);

        emit AirdropClaimed(tx.origin, amount, _onBehalfOf);
    }

    /// @notice Internal function to check the merkle proof
    /// @param _proof merkle proof of the claim
    /// @param _amount amount of tokens to claim
    /// @param _account address to check
    function _rootCheck(bytes32[] calldata _proof, uint256 _amount, address _account) internal view {
        bytes32 leaf = keccak256(abi.encodePacked(_account, _amount));
        if (!MerkleProofLib.verify(_proof, claimRoot, leaf)) {
            revert InvalidMerkleProof();
        }
    }

    /// @notice Internal function to check the signature
    /// @param _amount amount of tokens to claim
    /// @param _signature signature of the claim
    /// @param _account address to check
    function _signatureCheck(uint256 _amount, bytes calldata _signature, address _account) internal view {
        if (_signature.length == 0) revert InvalidSignature();

        bytes32 messageHash = keccak256(abi.encodePacked(_account, _amount, address(this), block.chainid));
        bytes32 prefixedHash = ECDSA.toEthSignedMessageHash(messageHash);
        address recoveredSigner = ECDSA.recoverCalldata(prefixedHash, _signature);

        if (recoveredSigner != signer) revert InvalidSignature();
    }

    function withdraw(uint256 amount) external override onlyOwner {
        transfer(msg.sender, amount);
    }
}
