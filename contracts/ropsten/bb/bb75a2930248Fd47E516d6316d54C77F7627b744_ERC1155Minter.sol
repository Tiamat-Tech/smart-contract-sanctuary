// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "base64-sol/base64.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./RewardToken.sol";

contract ERC1155Minter is Context, Ownable, ERC1155Burnable, ERC1155Pausable {
    using Address for address payable;

    uint256 TYPE_OF_NFT;

    RewardToken immutable rewardToken;

    struct NFTDetail {
        uint256 maxSupply;
        uint256 price;
        uint256 tokenPerUnit;
    }

    uint256 devFee;
    uint256 MAX_DEV_FEE = 5000; //dev fee must not exceed 50%;
    uint256 treasuryAmount;
    uint256 devAmount;

    address payable treasuryAddress;
    address payable devAddress;

    mapping(uint256 => NFTDetail) public details;

    mapping(uint256 => uint256) private _totalSupply;

    // Event
    event MintNfts(address receiver, uint256 tokenId, uint256 amount);

    event WithdrawDevFee(address devAddr, uint256 amount);
    event WithdrawTreasuryFee(address treasuryAddr, uint256 amount);

    event RegisterNewNft(
        uint256 tokenId,
        uint256 maxsupply,
        uint256 price,
        uint256 tokenPerUnit
    );

    event EditNft(
        uint256 tokenId,
        uint256 maxsupply,
        uint256 price,
        uint256 tokenPerUnit
    );

    event SetNewDevFee(uint256 amount);

    /***********************************|
  |          Initialization           |
  |__________________________________*/

    constructor(string memory _uri, RewardToken _rewardToken) ERC1155(_uri) {
        rewardToken = _rewardToken;
    }

    /***********************************|
  |             Modifiers             |
  |__________________________________*/

    /***********************************|
  |              Public               |
  |__________________________________*/

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view returns (bool) {
        return totalSupply(id) > 0;
    }

    function mint(uint256 _tokenId, uint256 _numberOfTokens) public payable {
        require(
            totalSupply(_tokenId) + _numberOfTokens <=
                details[_tokenId].maxSupply,
            "Purchase would exceed max supply"
        );
        require(
            details[_tokenId].price * _numberOfTokens <= msg.value,
            "Ether value sent is not correct"
        );

        // Seperate Fund to treasury, dev, mint token
        uint256 amount = msg.value;
        uint256 amountToDev = (amount * devFee) / 10000;
        devAmount = devAmount + amountToDev;
        treasuryAmount = treasuryAmount + (amount - amountToDev);

        // transfer reward token to user
        uint256 rewardAmount = _numberOfTokens * details[_tokenId].tokenPerUnit;
        rewardToken.mint(msg.sender, rewardAmount);

        _mint(msg.sender, _tokenId, _numberOfTokens, "");

        emit MintNfts(msg.sender, _tokenId, _numberOfTokens);
    }

    function withdrawDevFee() public {
        devAddress.transfer(devAmount);
        emit WithdrawDevFee(devAddress, devAmount);
        devAmount = 0;
    }

    function withdrawTreasuryFee() public {
        treasuryAddress.transfer(treasuryAmount);
        emit WithdrawTreasuryFee(treasuryAddress, treasuryAmount);
        treasuryAmount = 0;
    }

    /***********************************|
  |     Only Token ID Owner             |
  |__________________________________*/

    /***********************************|
  |          Only Admin/DAO           |
  |__________________________________*/

    function registerNft(
        uint256 _maxSupply,
        uint256 _price,
        uint256 _tokenPerUnit
    ) public onlyOwner {
        details[TYPE_OF_NFT].maxSupply = _maxSupply;
        details[TYPE_OF_NFT].price = _price;
        details[TYPE_OF_NFT].tokenPerUnit = _tokenPerUnit;
        emit RegisterNewNft(TYPE_OF_NFT, _maxSupply, _price, _tokenPerUnit);
        TYPE_OF_NFT = TYPE_OF_NFT + 1;
    }

    function editNft(
        uint256 _tokenId,
        uint256 _maxSupply,
        uint256 _price,
        uint256 _tokenPerUnit
    ) public onlyOwner {
        require(TYPE_OF_NFT > _tokenId, "Token Id does not registered");
        details[_tokenId].maxSupply = _maxSupply;
        details[_tokenId].price = _price;
        details[_tokenId].tokenPerUnit = _tokenPerUnit;
        emit EditNft(_tokenId, _maxSupply, _price, _tokenPerUnit);
    }

    function setDevFee(uint256 _devFee) public onlyOwner {
        require(_devFee <= MAX_DEV_FEE, "Cannot set fee exceed max fee");
        devFee = _devFee;
        emit SetNewDevFee(_devFee);
    }

    /***********************************|
  |         Private Functions         |
  |__________________________________*/

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Pausable) {
        require(
            msg.sender == address(this) || msg.sender == address(0),
            "Can't transfer this NFT"
        );
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] -= amounts[i];
            }
        }
    }
}