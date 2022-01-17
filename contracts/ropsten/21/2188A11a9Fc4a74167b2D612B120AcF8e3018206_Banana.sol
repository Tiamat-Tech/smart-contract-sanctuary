// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @dev Interface of the CallerAuthenticator using Schnorr protocol
 */
interface CallerAuthenticatorInterface {
    /**
     * @dev Returns the token ID if authenticated. Otherwise, it reverts.
     */
    function processAuthentication(uint256 preprocessed_id, uint256 p1, uint256 p2, uint256 s, uint256 e) external returns (uint256);
}


contract Banana is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // This means circulation supply aka sold count
    uint256 public currentSupply;
    uint256 public totalNFTSupply = 8888;
    uint256 public maxBatch = 10;
    uint256 public price = 50000000000000000;
    string public baseURI;
    bool private saleIsActive;

    CallerAuthenticatorInterface private authenticator;

    event MintFuryBandits(address indexed sender, uint256 purchaseCount);
    event TokenIDReveal(uint256 id);

    //constructor args 
    constructor(string memory name_, string memory symbol_, string memory baseURI_, address authenticatorAddress_) ERC721(name_, symbol_) {
        baseURI = baseURI_;
        authenticator = CallerAuthenticatorInterface(authenticatorAddress_);
    }

    modifier saleIsOpen {
        require(saleIsActive, "Market closed.");
        require(currentSupply <= totalNFTSupply, "Soldout!");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory){
        return baseURI;
    }
    function setBaseURI(string memory newURI) public onlyOwner {
        baseURI = newURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token.");
        
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : '.json';
    }
    function setSalesStatus(bool is_active) public onlyOwner {
        saleIsActive = is_active;
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 count = balanceOf(owner);
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = tokenOfOwnerByIndex(owner, i);
        }
        return ids;
    }

    function process_mint(uint256[] memory requestIds, uint256[] memory pubkeys1, uint256[] memory pubkeys2, uint256[] memory s, uint256[] memory e) payable public saleIsOpen {
        uint256 purchaseCount = requestIds.length;
        require(purchaseCount > 0 && purchaseCount <= maxBatch, "must mint fewer in each batch");
        require(currentSupply + purchaseCount <= totalNFTSupply, "max supply reached!");
        require(msg.value == purchaseCount * price, "value error, please check price.");
        require(purchaseCount == pubkeys1.length && purchaseCount == pubkeys2.length && purchaseCount == s.length && purchaseCount == e.length, "Reuest data corrupted");

        // transfer
        payable(owner()).transfer(msg.value);
        emit MintFuryBandits(_msgSender(), requestIds.length);

        for(uint256 i=0; i<requestIds.length; i++){
            uint256 tokenId = authenticator.processAuthentication(requestIds[i], pubkeys1[i], pubkeys2[i], s[i], e[i]);
            currentSupply = currentSupply + 1;
            _mint(_msgSender(), tokenId);
        }
    }

    function test(uint256 preprocessed_id, uint256 p1, uint256 p2, uint256 s, uint256 e) public returns (uint256) {
        uint256 tokenID = authenticator.processAuthentication(preprocessed_id, p1, p2, s, e);
        emit TokenIDReveal(tokenID);
        return tokenID;
    } 
}