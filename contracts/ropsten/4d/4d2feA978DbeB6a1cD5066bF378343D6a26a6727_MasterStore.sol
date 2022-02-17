// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC20.sol";
import "./NFT.sol";

contract MasterStore is AccessControl {
    bytes32 public constant EMP_ROLE = keccak256("EMP_ROLE");
    BaseToken public token;
    NFT public nft;
    bool public setup = false;
    event Claim(uint256 indexed _pid, uint256 tokenId, address customer);
    event GivePoint(address indexed emp, address customer, uint256 amount);
    modifier staffOnly() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) ||
                hasRole(EMP_ROLE, _msgSender()),
            "ERROR: Restricted to staff or Admin."
        );
        _;
    }

    constructor(address admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function setupContract(address _token, address _nft)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(setup == false, "ERROR: The contract has been set up");
        token = BaseToken(_token);
        nft = NFT(_nft);
        setup = true;
        // renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function givePoint(address to, uint256 amount) public staffOnly {
        token.mint(to, amount);
        emit GivePoint(_msgSender(), to, amount);
    }

    function redeem(uint256 _pid) public {
        // check token amount for redeem
        (, , uint256 requiredPoints, , uint256 limit, uint256 redeemed, ) = nft
            .rewardInfo(_pid);
        require(
            token.balanceOf(_msgSender()) >= requiredPoints,
            "ERC20: redeem amount exceeds balance"
        );
        require(redeemed + 1 <= limit, "ERC20: Rewards are sold out");
        // burn token from caller
        token.burn(_msgSender(), requiredPoints);
        // mint NFT
        nft.mint(_msgSender(), _pid);
    }

    function claim(uint256 tokenId) public {
        // check NFT
        (uint256 pid, uint256 expMinutes, , ,bool isRedeemed ) = nft.nftCouponInfo(tokenId);
        address owner = nft.ownerOf(tokenId);
        require(
            owner == _msgSender(),
            "ERROR: You are not the owner of this nft"
        );
        require(block.timestamp <= expMinutes, "ERROR: NFT Coupon expired.");
        require(isRedeemed == false, "ERROR: This coupon has been redeemed.");
        // burn NFT from caller
        nft.burn(tokenId);
        emit Claim(pid, tokenId, _msgSender());
    }
}