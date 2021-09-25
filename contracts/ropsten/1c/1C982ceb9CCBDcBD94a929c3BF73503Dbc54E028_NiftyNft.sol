//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                                                            //
//                                                                                                                                                                            //
//    TTTTTTTTTTTTTTTTTTTTTTThhhhhhh                                      NNNNNNNN        NNNNNNNN  iiii     ffffffffffffffff           tttt                                  //
//    T:::::::::::::::::::::Th:::::h                                      N:::::::N       N::::::N i::::i   f::::::::::::::::f       ttt:::t                                  // 
//    T:::::::::::::::::::::Th:::::h                                      N::::::::N      N::::::N  iiii   f::::::::::::::::::f      t:::::t                                  // 
//    T:::::TT:::::::TT:::::Th:::::h                                      N:::::::::N     N::::::N         f::::::fffffff:::::f      t:::::t                                  //
//    TTTTTT  T:::::T  TTTTTT h::::h hhhhh           eeeeeeeeeeee         N::::::::::N    N::::::Niiiiiii  f:::::f       ffffffttttttt:::::tttttttyyyyyyy           yyyyyyy   //
//            T:::::T         h::::hh:::::hhh      ee::::::::::::ee       N:::::::::::N   N::::::Ni:::::i  f:::::f             t:::::::::::::::::t y:::::y         y:::::y    //
//            T:::::T         h::::::::::::::hh   e::::::eeeee:::::ee     N:::::::N::::N  N::::::N i::::i f:::::::ffffff       t:::::::::::::::::t  y:::::y       y:::::y     //
//            T:::::T         h:::::::hhh::::::h e::::::e     e:::::e     N::::::N N::::N N::::::N i::::i f::::::::::::f       tttttt:::::::tttttt   y:::::y     y:::::y      //
//            T:::::T         h::::::h   h::::::he:::::::eeeee::::::e     N::::::N  N::::N:::::::N i::::i f::::::::::::f             t:::::t          y:::::y   y:::::y       // 
//            T:::::T         h:::::h     h:::::he:::::::::::::::::e      N::::::N   N:::::::::::N i::::i f:::::::ffffff             t:::::t           y:::::y y:::::y        //
//            T:::::T         h:::::h     h:::::he::::::eeeeeeeeeee       N::::::N    N::::::::::N i::::i  f:::::f                   t:::::t            y:::::y:::::y         //
//            T:::::T         h:::::h     h:::::he:::::::e                N::::::N     N:::::::::N i::::i  f:::::f                   t:::::t    tttttt   y:::::::::y          //
//          TT:::::::TT       h:::::h     h:::::he::::::::e               N::::::N      N::::::::Ni::::::if:::::::f                  t::::::tttt:::::t    y:::::::y           //
//          T:::::::::T       h:::::h     h:::::h e::::::::eeeeeeee       N::::::N       N:::::::Ni::::::if:::::::f                  tt::::::::::::::t     y:::::y            //
//          T:::::::::T       h:::::h     h:::::h  ee:::::::::::::e       N::::::N        N::::::Ni::::::if:::::::f                    tt:::::::::::tt    y:::::y             //
//          TTTTTTTTTTT       hhhhhhh     hhhhhhh    eeeeeeeeeeeeee       NNNNNNNN         NNNNNNNiiiiiiiifffffffff                      ttttttttttt     y:::::y              //
//                                                                                                                                                      y:::::y               //
//                                                                                                                                                     y:::::y                //
//                                                                                                                                                    y:::::y                 //
//                                                                                                                                                   y:::::y                  //
//                                                                                                                                                  yyyyyyy                   //
//                                                                                                                                                                            //
//                                                                                                                                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Need setBaseURI
// 

contract NiftyNft is ERC721, Ownable {
  using Strings for uint256;

  // Optional mapping for token URIs
  mapping (uint256 => string) private _tokenURIs;

  // Base URI
  string private _baseURIextended;

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721("NiftyNft", "NIFTY") {}

  function mint(address recipient)
    public onlyOwner
    returns (uint256)
  {
    _tokenIds.increment();

    uint256 _idx = _tokenIds.current();
    _mint(recipient, _idx);
    _setTokenURI(_idx, uint256(_idx).toString());

    return _idx;
  }

  function setBaseURI(string memory baseURI_) external onlyOwner() {
    _baseURIextended = baseURI_;
  }
    
  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
    require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
  }
    
  function _baseURI() internal view virtual override returns (string memory) {
    return _baseURIextended;
  }
    
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory _tokenURI = _tokenURIs[tokenId];
    string memory base = _baseURI();
    
    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
      return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
      return string(abi.encodePacked(base, _tokenURI));
    }
    // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
    return string(abi.encodePacked(base, tokenId.toString()));
  }
}