// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract PhlippedLarvaBrats is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Address for address;

    string public baseURI;
    string public baseExtension = ".json";
    uint16 public counter = 0;


    uint8 public giveaway = 10;
    uint8 public constant maxPublicPurchase = 20;
    uint8 public constant maxWalletBalance = 20;

    uint16 public maxSupply = 5000;
    uint256 public constant price = 10000000000000000;

    bool public publicSale = false; 
    bool public giveAwayOn = false;

    mapping(address => uint256) addressBlockBought;

    constructor(string memory tokenBaseUri) ERC721("Phlipped Larva Brats", "BRATS") {
        counter = counter + 1;

        setBaseURI(tokenBaseUri);
    }

    function mintBrats(uint8 numberOfTokens) public payable {
        uint256 supply = totalSupply();
        require(publicSale, "Public mint is not live right now.");
        require(addressBlockBought[msg.sender] < block.timestamp, "Not allowed to Mint on the same Block");
        require(!Address.isContract(msg.sender),"Contracts are not allowed to mint");
        require(numberOfTokens <= maxPublicPurchase, "You can mint a maximum of 10 Larva Brats");
        require(supply + numberOfTokens <= maxSupply, "Exceeds maximum Brats supply" );
        require(balanceOf(msg.sender) + numberOfTokens <= maxWalletBalance, "Each wallet can only mint 10 Larva Brats" );
        require(price.mul(numberOfTokens) <= msg.value, "Ether value sent is incorrect");

        addressBlockBought[msg.sender] = block.timestamp;

        for(uint8 i; i < numberOfTokens; i++){
            _safeMint(msg.sender, counter);
            counter = counter + 1;
        }
    }

    function mintForGiveaway() public {
        require(giveAwayOn, "Give away has not started");
        require(giveaway > 0, "All giveaways have been minted");
        require(balanceOf(msg.sender) + 1 <= maxWalletBalance, "Each wallet can only mint 10 Larva Brats" );
        _safeMint(msg.sender, counter);
        counter = counter + 1;
        giveaway -= giveaway;
    }

    function toggleSale() public onlyOwner{
        publicSale = !publicSale;
    }

    function toggleGiveAway() public onlyOwner {
        giveAwayOn = !giveAwayOn;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
    {
        require( _exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        string memory tokenIdString = uint2str(tokenId);
        string memory currentBaseURI = _baseURI();
        
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI,  tokenIdString, baseExtension))
        : "";
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Failed to withdraw payment");
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}