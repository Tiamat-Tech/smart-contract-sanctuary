// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

/**
 * @title BrkfstWorld contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract BrkfstWorld is ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    string public BRKFSTWORLD_PROVENANCE = "";
    uint256 public constant SndwchPrice = 50000000000000000; //0.05 ETH
    uint public constant maxSndwchPurchase = 4; //Max Mint 4
    uint256 public MAX_SNDWCH = 5270;
    uint public sndwchReserve = 270;
    bool public saleIsActive = false;
    string _baseTokenURI;

    // withdraw addresses
    address t1 = 0xDb94Daa8bF1b6F45B122F442F922a2C4DD2F7aDe; //BrkfstSndwch
    address t2 = 0x7F9B1c94DBAb6F3F5299e30eb9f9B8845d45614B; //Kev
    address t3 = 0x6a38D9c83bF780aCF34E90047D44e692221C6Aa7; //Sifu

    constructor(string memory baseURI) ERC721("Brkfst World", "BRKFST") {
        _baseTokenURI = baseURI;
    }
    function withdraw() public onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    /*
    * Set provenance once it's calculated
    */
    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        BRKFSTWORLD_PROVENANCE = provenanceHash;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /*
    * Pause sale if active, make active if paused
    */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    /**
    * Mints  Sndwchs
    */
    function mintSndwch(uint numberOfTokens) public payable {
        require(saleIsActive, "Sale must be active to mint Brkfst Sndwch");
        require(numberOfTokens <= maxSndwchPurchase, "Can only mint 4 tokens at a time");
        require(totalSupply().add(numberOfTokens) <= MAX_SNDWCH, "Purchase would exceed max supply of Sndwchs");
        require(SndwchPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");

        for(uint i = 0; i < numberOfTokens; i++) {
            uint mintIndex = totalSupply();
            if (totalSupply() < MAX_SNDWCH) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function reserveSndwchs(address _to, uint256 _reserveAmount) public onlyOwner {        
        uint supply = totalSupply();
        require(_reserveAmount > 0 && _reserveAmount <= sndwchReserve, "Not enough reserve left for team");
        for (uint i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
        sndwchReserve = sndwchReserve.sub(_reserveAmount);
    }


    function withdrawAll() public payable onlyOwner {
        uint256 _brkfst = address(this).balance * 50/100;
        uint256 _kevy = address(this).balance * 30/100;
        uint256 _sifu = address(this).balance * 20/100;
        require(payable(t1).send(_brkfst));
        require(payable(t2).send(_kevy));
        require(payable(t3).send(_sifu));
    }
}