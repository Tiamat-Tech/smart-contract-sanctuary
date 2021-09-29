// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

// import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/[email protected]/security/Pausable.sol";
import "openzeppelin-solidity/contracts/security/Pausable.sol";
// import "@openzeppelin/[email protected]/access/Ownable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
// import "@openzeppelin/[email protected]/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
// import "@openzeppelin/[email protected]/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

contract JakuTestCoin is ERC721, ERC721Enumerable,Pausable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    
    uint256 public constant maxTokens        = 10;
    //                                         100000000000000000; // 0.1 Eth
    //                                          85000000000000000; // 0.085 ETH
    uint256 public constant SINGLE_PRICE     =  60000000000000000; // 0.06 ETh
    uint    public constant maxPurchase      = 2;
    string  public          _internalBaseURI = "";
    bool    public          earlyAccess      = false;
    bool    public          sale        = false;
    

    constructor() ERC721("JakuTestCoin", "JTC") {}

    function _baseURI() internal pure override returns (string memory) {
        //return "";
        return "https://gateway.pinata.cloud/ipfs/Qme2VPswaUGwG1aH7TpBqe1zpU14d2k84fqdKnE3YTpnS5/";
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    function startEarlyAccess() public onlyOwner {
        earlyAccess = true;
    }
    
    function stopEarlyAccess() public onlyOwner {
        earlyAccess = false;
    }
    
    function startSale() public onlyOwner {
        sale = true;
    }
    
    function stopSale() public onlyOwner {
        sale = false;
    }
    
    function earlyMint(uint256 numTokens) public payable {
        require(earlyAccess, "No es acceso anticipado");
        require(numTokens > 0 && numTokens <= maxPurchase, "Minimo y Maximo de tokens");
        require(SafeMath.add(totalSupply(), numTokens) <= maxTokens, "No hay suficientes tokens para dar");
        require(msg.value >= SafeMath.mul(SINGLE_PRICE, numTokens), "Monto incorrecto");
        
        for (uint i = 0; i < numTokens; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
    
    function mint(uint256 numTokens) public whenNotPaused payable {
        require(numTokens > 0 && numTokens <= maxPurchase, "Minimo y Maximo de tokens");
        require(SafeMath.add(totalSupply(), numTokens) <= maxTokens, "No hay suficientes tokens para dar");
        require(msg.value >= SafeMath.mul(SINGLE_PRICE, numTokens), "Monto incorrecto");
        
        for (uint i = 0; i < numTokens; i++) {
            uint mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
 
    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}