//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "hardhat/console.sol";

contract ArtistStaking is AccessControl {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

    IERC20 public onft;

    // staker => artist => onftAmountMantissa
    mapping(address => mapping(address => uint256)) public stakerInfo;

    mapping(address => bool) public isAccountUpgraded;

    event AccountUpgraded(address user);
    event Staked(address artist, address staker, uint256 onftAmountMantissa);
    event Unstaked(address artist, address staker, uint256 onftAmountMantissa);

    constructor(address _admin, address _onft) {
        _setupRole(ROLE_ADMIN, _admin);
        _setRoleAdmin(ROLE_ADMIN, ROLE_ADMIN);

        onft = IERC20(_onft);
    }

    function upgradeAccount() public {
        require(
            isAccountUpgraded[msg.sender] == false,
            "User account is already upgraded"
        );

        onft.transferFrom(msg.sender, address(this), 1 ether);
        isAccountUpgraded[msg.sender] = true;

        emit AccountUpgraded(msg.sender);
    }

    function stakeIntoArtist(address artist, uint256 _onftAmountMantissa)
        public
    {
        onft.transferFrom(msg.sender, address(this), _onftAmountMantissa);

        stakerInfo[msg.sender][artist] += _onftAmountMantissa;

        emit Staked(artist, msg.sender, _onftAmountMantissa);
    }

    function unstakeFromArtist(address artist, uint256 _onftAmountMantissa)
        public
    {
        require(
            _onftAmountMantissa <= stakerInfo[msg.sender][artist],
            "Insufficient ONFT staked"
        );

        onft.transfer(msg.sender, _onftAmountMantissa);

        stakerInfo[msg.sender][artist] -= _onftAmountMantissa;

        emit Unstaked(artist, msg.sender, _onftAmountMantissa);
    }

    function recoverByHash(bytes32 hash, bytes memory signature)
        external
        pure
        returns (address)
    {
        return ECDSA.recover(hash, signature);
    }

    function recoverBySig(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external pure returns (address) {
        return ECDSA.recover(hash, v, r, s);
    }

    function toEthSignedMessageHash(bytes32 hash)
        external
        pure
        returns (bytes32)
    {
        return ECDSA.toEthSignedMessageHash(hash);
    }
}