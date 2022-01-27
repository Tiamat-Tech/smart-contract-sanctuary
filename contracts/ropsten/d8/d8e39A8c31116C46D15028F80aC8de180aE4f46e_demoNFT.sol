// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
 
import "https://github.com/0xcert/ethereum-erc721/src/contracts/tokens/nf-token-metadata.sol";
import "https://github.com/0xcert/ethereum-erc721/src/contracts/ownership/ownable.sol";
 
contract demoNFT is NFTokenMetadata, Ownable {

  uint256 _tokenId = 1;  
 
  constructor() {
    nftName = "Synth NFT";
    nftSymbol = "SYN";
  }
 
  function mint() public {
    address _to = msg.sender;
    string memory _uri = "https://ipfs.io/ipfs/QmcJvYpJpweWhagS3wfT4KjMJxb95GSdAVwQGJxzt5T2Ch?filename=Duke-Fuqua-School-of-Business.jpeg";

    super._mint(_to, _tokenId);
    super._setTokenUri(_tokenId, _uri);

    _tokenId += 1;
  }
 
}