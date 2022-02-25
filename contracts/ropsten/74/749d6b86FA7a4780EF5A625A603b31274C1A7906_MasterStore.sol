// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC20.sol";
import "./NFT.sol";

contract MasterStore is AccessControl, ReentrancyGuard {
    bytes32 public constant EMP_ROLE = keccak256("EMP_ROLE");
    BaseToken public token;
    NFT public nft;
    bool public setup = false;
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );
    bytes32 public constant DELEGATION_TYPEHASH =
        keccak256("ApproveClaim(address owner,uint256 tokenID,uint256 nonce)");

    mapping(address => mapping(uint256 => bool)) public approveClaim;
    mapping(address => uint256) public nonces;

    event Claim(uint256 indexed _pid, uint256 tokenId, address customer);
    event GivePoint(address indexed emp, address customer, uint256 amount);
    modifier staffOnly() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) ||
                hasRole(EMP_ROLE, _msgSender()),
            "ERROR: staff only"
        );
        _;
    }

    modifier canClaim(uint256 tokenId) {
        (uint256 pid, uint256 expMinutes, , , bool isRedeemed) = nft
            .nftCouponInfo(tokenId);
        require(block.timestamp <= expMinutes, "ERROR: NFT Coupon expired.");
        require(isRedeemed == false, "ERROR: coupon has been redeemed.");
        _;
    }

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setupContract(address _token, address _nft)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(setup == false, "ERROR: contract has been set up");
        token = BaseToken(_token);
        nft = NFT(_nft);
        setup = true;
    }

    function givePoint(address to, uint256 amount)
        public
        staffOnly
        nonReentrant
    {
        token.mint(to, amount);
        emit GivePoint(_msgSender(), to, amount);
    }

    function redeem(uint256 _pid) public nonReentrant {
        // check token amount for redeem
        (, , uint256 requiredPoints, , uint256 limit, uint256 redeemed, ) = nft
            .rewardInfo(_pid);
        require(
            token.balanceOf(_msgSender()) >= requiredPoints,
            "ERC20: amount exceeds balance"
        );
        require(redeemed + 1 <= limit, "ERC20: Rewards are sold out");
        token.burn(_msgSender(), requiredPoints);
        nft.mint(_msgSender(), _pid);
    }

    function revokeForClaim(uint256 tokenId)
        public
        canClaim(tokenId)
        nonReentrant
    {
        address owner = nft.ownerOf(tokenId);
        require(
            owner == _msgSender(),
            "ERROR: You are not owner"
        );
        approveClaim[_msgSender()][tokenId] = false;
    }

    function approveForClaim(uint256 tokenId)
        public
        canClaim(tokenId)
        nonReentrant
    {
        address owner = nft.ownerOf(tokenId);
        require(
            owner == _msgSender(),
            "ERROR: You are not owner"
        );
        approveClaim[_msgSender()][tokenId] = true;
    }

    function _claim(uint256 tokenId, address signatory)
        private
        canClaim(tokenId)
        nonReentrant
    {
        (uint256 pid, , , , ) = nft.nftCouponInfo(tokenId);
        nft.burn(tokenId);
        approveClaim[signatory][tokenId] = false;
        emit Claim(pid, tokenId, _msgSender());
    }

    function applyBySig(
        address owner,
        uint256 tokenId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public staffOnly nonReentrant {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("MasterStore"),
                block.chainid,
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                _msgSender(),
                tokenId,
                nonces[owner]++
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0) && signatory == owner,
            "ERROR: invalid signature"
        );
        require(
            approveClaim[signatory][tokenId],
            "ERROR: tokenID is not approved."
        );
        require(
            signatory == nft.ownerOf(tokenId),
            "ERROR: signatory not owner"
        );
        _claim(tokenId, signatory);
    }
}