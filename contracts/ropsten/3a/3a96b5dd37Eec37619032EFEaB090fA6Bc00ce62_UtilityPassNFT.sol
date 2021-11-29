// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// TODO: delete before deploying
// import "hardhat/console.sol";

contract UtilityPassNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Address for address payable;
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    uint256 public constant GIVEAWAY = 100;
    uint256 public constant PRICE = 0.03 ether;
    uint256 public constant SUPPLY = 6000;

    address public genesisAddress;
    uint256 public giveawaySupply = GIVEAWAY;
    Counters.Counter private _tokenIds;

    constructor(address _genesisAddress)
        ERC721("Psychedelics NFT Utility", "UTIL")
    {
        genesisAddress = _genesisAddress;
    }

    ///
    /// Mint
    //

    // Private mint function, does not check for payment
    function _mintPrivate(address _to, uint256 _amount) private {
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, _tokenIds.current());
            _tokenIds.increment();
        }
    }

    function mint(address _to) public nonReentrant {
        require(
            msg.sender == genesisAddress,
            "Only genesis NFT contract can mint"
        );

        _mintPrivate(_to, 1);
    }

    ///
    /// Setters
    ///
    function setGenesisAddress(address _genesisAddress) public onlyOwner {
        genesisAddress = _genesisAddress;
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
}