// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "./ERC721B.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// TODO: delete before deploying
// import "hardhat/console.sol";

contract UtilityPassNFT is ERC721B, Ownable, ReentrancyGuard {
    using Address for address payable;
    using SafeMath for uint256;
    using Strings for uint256;

    enum MintStatus {
        NORMAL,
        GENESIS_SOLD_OUT
    }

    // Keep in sync with number in GenesisNft
    uint256 public constant PRICE = 0.03 ether;
    uint256 public constant GIVEAWAY = 100;
    uint256 public constant SUPPLY = 6000;
    uint256 public constant LIMIT = 2;
    uint256 public constant MINTABLE_SUPPLY = SUPPLY - GIVEAWAY;

    MintStatus public mintStatus = MintStatus.NORMAL;
    string public baseTokenURI;
    address public genesisAddress;
    uint256 public giveawaySupply = GIVEAWAY;

    // Only start counting when genesis NFT is sold out
    mapping(address => uint256) private _tokensMintedByAddress;
    // TODO: change
    address public withdrawDest1 = 0xb0B035d2E95d2c7820D58A56575b0c24bA8a9641;
    // TODO: change
    address public withdrawDest2 = 0x27a05D42046eace2ed21282643B1530867Ffb2Bb;

    constructor(address _genesisAddress)
        ERC721B("Psychedelics NFT Utility", "UTIL")
    {
        genesisAddress = _genesisAddress;
    }

    ///
    /// Mint
    //

    // Private mint function, does not check for payment
    function _mintPrivate(address _to, uint256 _amount) private {
        uint256 supply = _owners.length;
        for (uint256 i; i < _amount; i++) {
            _safeMint(_to, supply++);
        }
    }

    function mintGenesisSoldOut(uint256 _amount) public payable {
        require(mintStatus == MintStatus.GENESIS_SOLD_OUT, "Invalid status");
        // Assumes giveaways will be done after minting
        require(_owners.length + _amount <= MINTABLE_SUPPLY, "Sold out");
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
        if (_owners.length >= MINTABLE_SUPPLY) {
            // Don't throw, just return so genesis minting will succeed
            return false;
        }

        _safeMint(_to, _owners.length);
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

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "caller is not owner nor approved"
        );
        _burn(tokenId);
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

    ///
    /// MISC
    ///
    function tokenURI(uint256 tokenId)
        external
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return string(abi.encodePacked(baseTokenURI, tokenId.toString()));
    }
}