// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// TODO: delete before deploying
// import "hardhat/console.sol";

contract MerchPassNFT is ERC721, Ownable, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    using Strings for uint256;

    enum MintStatus {
        NORMAL,
        GENESIS_SOLD_OUT
    }

    // Keep in sync with number in GenesisNft
    uint256 public constant PRICE = 0.001 ether;
    uint256 public constant GIVEAWAY = 250;
    uint256 public constant SUPPLY = 5500;
    uint256 public constant LIMIT = 2;
    uint256 public constant MINTABLE_SUPPLY = SUPPLY - GIVEAWAY;

    MintStatus public mintStatus = MintStatus.NORMAL;
    string public baseTokenURI;
    address public genesisAddress;
    uint256 public giveawaySupply = GIVEAWAY;
    uint256 public tokenCount = 0;

    // Only start counting when genesis NFT is sold out
    mapping(address => uint256) private _tokensMintedByAddress;
    // TODO: change
    address public withdrawDest1 = 0xb0B035d2E95d2c7820D58A56575b0c24bA8a9641;
    // TODO: change
    address public withdrawDest2 = 0x27a05D42046eace2ed21282643B1530867Ffb2Bb;

    constructor(address _genesisAddress)
        ERC721("Psychedelics NFT Merch", "MERCH")
    {
        genesisAddress = _genesisAddress;
    }

    // Override so the openzeppelin tokenURI() method will use this method to
    // create the full tokenURI instead
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    ///
    /// Mint
    //

    // Private mint function, does not check for payment
    function _mintPrivate(address _to, uint256 _amount) private {
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, tokenCount++);
        }
    }

    function mintGenesisSoldOut(uint256 _amount) public payable {
        require(mintStatus == MintStatus.GENESIS_SOLD_OUT, "Invalid status");
        // Assumes giveaways will be done after minting
        require(tokenCount + _amount <= MINTABLE_SUPPLY, "Sold out");
        require(msg.value == PRICE * _amount, "Ether sent is not correct");
        require(
            _tokensMintedByAddress[msg.sender] + _amount <= LIMIT,
            "Trying to mint too many NFTs"
        );

        _mintPrivate(msg.sender, _amount);
        _tokensMintedByAddress[msg.sender] += _amount;
    }

    function mint(address _to) public returns (bool) {
        require(mintStatus == MintStatus.NORMAL, "Invalid status");
        require(
            msg.sender == genesisAddress,
            "Only genesis NFT contract can mint"
        );

        // Assumes giveaways will be done after minting
        if (tokenCount >= MINTABLE_SUPPLY) {
            // Don't throw, just return so genesis minting will succeed
            return false;
        }

        _safeMint(_to, tokenCount++);
        return true;
    }

    ///
    /// Setters
    ///
    function setBaseURI(string memory _uri) public onlyOwner {
        baseTokenURI = _uri;
    }

    function setGenesisAddress(address _genesisAddress) public onlyOwner {
        genesisAddress = _genesisAddress;
    }

    function setStatus(uint8 _status) external onlyOwner {
        mintStatus = MintStatus(_status);
    }

    function setWithdrawDests(address _dest1, address _dest2) public onlyOwner {
        withdrawDest1 = _dest1;
        withdrawDest2 = _dest2;
    }

    ///
    /// Giveaway
    ///
    function giveaway(address _to, uint256 _amount) external onlyOwner {
        require(_amount <= giveawaySupply, "Not enough supply");
        require(_amount > 0, "Amount must be greater than zero");

        _mintPrivate(_to, _amount);
        giveawaySupply -= _amount;
    }

    ///
    /// Withdrawal
    ///
    function withdraw() public onlyOwner {
        require(address(this).balance != 0, "Balance is zero");

        uint256 _onePercent = address(this).balance.div(100);
        uint256 _amt1 = _onePercent.mul(5);
        uint256 _amt2 = address(this).balance.sub(_amt1);

        payable(withdrawDest1).sendValue(_amt1);
        payable(withdrawDest2).sendValue(_amt2);
    }
}