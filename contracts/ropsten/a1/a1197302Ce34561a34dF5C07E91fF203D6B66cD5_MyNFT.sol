pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract MyNFT is ERC721PresetMinterPauserAutoId {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker2;
    
    
    constructor() ERC721PresetMinterPauserAutoId("MyNFT_meta", "mynft_meta", "https://bafkreifni4osvpe42bqknb52heiofbxwty5urtuqzolduj3efdtqzerliy.ipfs.dweb.link") {
    }
     /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "")) : "";
    }
    function mint(address to) public override virtual {
        _mint(to, _tokenIdTracker2.current());
        _tokenIdTracker2.increment();
    }
}