// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Yokai Masks NFT Contract for https://yokai.money
 * @dev Extends ERC721 Non-Fungible Token Standard
 */
contract NFTTest is ERC721, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    // This is the provenance record of all Yokai masks in existence
    string public constant YOKAI_MASKS_PROVENANCE = "xxxxxxxxxxxxxxxx";

    // Max supply of masks
    uint256 public constant MAX_MASK_SUPPLY = 3001;

    // Current max supply of masks that can be bought with BNB
    uint256 public currentBnbMaskSupply = 500;

    // Current count of masks bought with BNB
    uint256 public currentBnbMaskCount = 0;

    // Current BNB price per mask
    uint256 public currentBnbMaskPrice = 400000000000000000;

    // Current max supply of masks that can be bought with RYO
    uint256 public currentRyoMaskSupply = 100;

    // Current count of masks bought with RYO
    uint256 public currentRyoMaskCount = 0;

    // Current RYO price per mask
    uint256 public currentRyoMaskPrice = 9000000000000000000000;

    // RYO token address
    // address public constant RYO_ADDRESS = 0xE55DBD26165924a1855BD754a207e603e7100D3A;
    address public constant RYO_ADDRESS = 0xFF4245b8Fd43f75476608a94768EbB29bb678c2C;

    // Dev address
    address payable public devAddr;

    // Address of the mask marketplace contract
    address public marketplaceAddress;

    /**
     * @dev Contract constructor
     */
    constructor() public ERC721("Yokai Masks", "¥") {
        devAddr = msg.sender;
    }

    /**
    * @dev Mints masks with BNB payment
    */
    function mintMaskBnb(uint256 numberOfMasks) public payable nonReentrant {
        require(totalSupply() < MAX_MASK_SUPPLY, "Sale over");
        require(totalSupply().add(1) <= MAX_MASK_SUPPLY, "Over supply");
        require(currentBnbMaskCount < currentBnbMaskSupply, "Current phase over");
        require(numberOfMasks <= 10, "Max 10 masks per txn allowed");
        require(currentBnbMaskPrice.mul(numberOfMasks) == msg.value, "Incorrect BNB value");

        devAddr.transfer(msg.value);

        for (uint i = 0; i < numberOfMasks; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }

    /**
     * @dev Update the max supply of masks that can be bought with BNB
     */
    function setBnbMaskSupply(uint256 _newMaskSupply) external onlyOwner {
        currentBnbMaskSupply = _newMaskSupply;
    }

    /**
     * @dev View the max supply of masks that can be bought with BNB
     */
    function bnbMaskSupply() public view returns (uint256) {
        return currentBnbMaskSupply;
    }

    /**
     * @dev View the current BNB price per mask
     */
    function getMaskBnbPrice() public view returns (uint256) {
        return currentBnbMaskPrice;
    }

    /**
    * @dev Mints masks with RYO payment
    */
    function mintMaskRyo(uint256 numberOfMasks) public payable nonReentrant {
        require(totalSupply() < MAX_MASK_SUPPLY, "Sale over");
        require(totalSupply().add(1) <= MAX_MASK_SUPPLY, "Over supply");
        require(currentRyoMaskCount < currentRyoMaskSupply, "Current phase over");
        require(numberOfMasks <= 10, "Max 10 masks per txn allowed");

        uint256 price = currentRyoMaskPrice.mul(numberOfMasks);
        IERC20(RYO_ADDRESS).safeTransferFrom(
            address(msg.sender),
            devAddr,
            price
        );

        for (uint i = 0; i < numberOfMasks; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }

    /**
     * @dev Update the max supply of masks that can be bought with RYO
     */
    function setRyoMaskSupply(uint256 _newMaskSupply) external onlyOwner {
        currentRyoMaskSupply = _newMaskSupply;
    }

    /**
     * @dev View the max supply of masks that can be bought with RYO
     */
    function ryoMaskSupply() public view returns (uint256) {
        return currentRyoMaskSupply;
    }

    /**
     * @dev View the current RYO price per mask
     */
    function getMaskRyoPrice() public view returns (uint256) {
        return currentRyoMaskPrice;
    }

    /**
     * @dev Premint 100 masks
     */
    function premintMasks(uint256 _indexStart, uint256 _amount) external onlyOwner {
        require(totalSupply() < MAX_MASK_SUPPLY, "Sale over");

        for (uint i = _indexStart; i < _indexStart + _amount; i++) {
            _safeMint(msg.sender, i);
        }
    }

    /**
     * @dev Withdraw BNB from this contract (callable by owner only)
    */
    function withdrawDevFunds() public onlyOwner nonReentrant {
        msg.sender.transfer(address(this).balance);
    }

    /**
     * @dev Update dev address by the previous dev
     */
    function setDev(address payable _devAddr) external onlyOwner {
        devAddr = _devAddr;
    }

    /**
     * @dev View the dev address
     */
    function devAddress() external view returns (address) {
        return devAddr;
    }

    /**
     * @dev Sets the baseURI
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        _setBaseURI(_baseURI);
    }

    /**
     * @dev Sets the URI of a token ID
     */
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external onlyOwner {
        _setTokenURI(_tokenId, _tokenURI);
    }

    /**
     * @dev Sets the marketplace contract address
     */
    function setMarketplaceAddress(address _marketplaceAddress) external onlyOwner {
        marketplaceAddress = _marketplaceAddress;
    }

    /**
     * @dev Performs an NFT transfer for the mask marketplace
     */
    function safeMaskTransferFrom(address _from, address _to, uint256 _tokenId) external {
        require(msg.sender == marketplaceAddress, "Caller not marketplace");
        safeTransferFrom(_from, _to, _tokenId);
    }
}