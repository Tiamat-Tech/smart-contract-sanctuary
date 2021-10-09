// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract TestNFT is ERC721PresetMinterPauserAutoId {
    
    constructor() 
    ERC721PresetMinterPauserAutoId("Benson Test NFT", "Test NFT", "https://ipfs.io/ipfs/QmSGiYVgj24pkj58TWAMkvUgXj7MvLQXU7LmcBBagEzwrG/")  
    {}
    
    // This allows the minter to update the tokenURI after it's been minted.
    // To disable this, delete this function.
    function setTokenURI(uint256 tokenId, string memory tokenURI) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "web3 CLI: must have minter role to update tokenURI");
        
        setTokenURI(tokenId, tokenURI);
    }
}