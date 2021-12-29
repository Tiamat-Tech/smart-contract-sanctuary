// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@imtbl/imx-contracts/contracts/IMintable.sol';
import '@imtbl/imx-contracts/contracts/Mintable.sol';

contract FunkyMonkeyFratHouseImmutable is ERC721, Ownable, IMintable{

    // Events
    event AssetMinted(address to, uint256 id, bytes blueprint);
    event PriceChanged(uint256 _priceInWei);
    event TreasuryChanged(address oldTreasuryAddress, address newTreasuryAddress);
    event MaxMintPerTranctionChanged(uint256 _maxMintPerTransaction);

    // Addresses
    address public imx;
    address public treasury;

    // uin256
    uint256 public price = 0.08 ether;
    uint256 public maxMintPerTransaction = 5;
    uint256 public maxSupply = 1000;
    uint256 public minted;

    // Mappings
    mapping(uint256 => string) private _tokenURI;
    mapping(uint256 => bytes) public blueprints;

    modifier onlyIMX() {
        require(msg.sender == imx, "FunkyMonkeyFratHouseImmutable: Function can only be called by IMX");
        _;
    }

    modifier onlyTreasury() {
        require(treasury == _msgSender(), "FunkyMonkeyFratHouseImmutable: Function can only be called by the treasury address");
        _;
    }

    constructor(address _imx) ERC721("FunkyMonkeyFratHouseImmutable", "FMFHI") {
        require(_imx != address(0x0), 'FunkyMonkeyFratHouseImmutable: Treasury address cannot be the 0x0 address');
        imx = _imx;
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external override onlyIMX {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, bytes memory blueprint) = Minting.split(mintingBlob);
        _mintFor(user, id, blueprint);
        blueprints[id] = blueprint;
        emit AssetMinted(user, id, blueprint);
    }

    function _mintFor(
        address to,
        uint256 id,
        bytes memory blueprint
    ) internal virtual {
        require(!_exists(id), "Token ID Has Been Used");
        _mint(to, id);
    }

    function setTreasuryWallet(address _treasury) external onlyOwner {
        require(treasury != address(0x0), 'FunkyMonkeyFratHouseImmutable: Treasury address cannot be the 0x0 address');
        treasury = _treasury;

        emit TreasuryChanged(treasury, _treasury);
    }

    function setPrice(uint256 _priceInWei) external onlyOwner {
        price = _priceInWei;

        emit PriceChanged(_priceInWei);
    }

    function setMaxMintPerTransaction(uint256 _maxMintPerTransaction) external onlyOwner {
        maxMintPerTransaction = _maxMintPerTransaction;

        emit MaxMintPerTranctionChanged(_maxMintPerTransaction);
    }

    function pay(uint256 amount) payable external {
        require(amount <= maxMintPerTransaction, 'FunkyMonkeyFratHouseImmutable: The amount is higher than the max mint per transaction');
        require((price * amount) <= msg.value, "FunkyMonkeyFratHouseImmutable: ETH sent is incorrect");
        require(minted <= maxSupply, "FunkyMonkeyFratHouseImmutable: Exceeds max supply");

        minted += amount;
    }

    /**
    * @dev Claim eth only available for the treasury address
    */
    function claimETH() public onlyTreasury() {
        payable(address(treasury)).transfer(address(this).balance);
    }
}