//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721Uriable.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

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

// ERC721, Ownable {
contract NiftyNft is ERC721Uriable {
  // using Strings for uint256;
  using SafeMath for uint256;

  uint256 public constant apePrice = 0.08 ether; //0.08 ETH
  uint public constant maxPurchase = 20;
  uint256 public TOTAL_SUPPLY = 100;

  // Optional mapping for token URIs
  mapping (uint256 => string) private _tokenURIs;

  // Base URI
  string private _baseURIextended;

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721("NiftyNft", "NIFTY") {}

  function mint(uint numberOfTokens) public payable
  {
    require(numberOfTokens <= maxPurchase, "Purchase is over maximum mint quantity");
    require(_tokenIds.current().add(numberOfTokens) <= TOTAL_SUPPLY, "Purchase would exceed total supply");
    require(apePrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");

    for(uint i=0; i < numberOfTokens; i++) {
      _tokenIds.increment();
      uint256 _idx = _tokenIds.current();
      _mint(msg.sender, _idx);
      _setTokenURI(_idx, Strings.toString(_idx));
    }
  }
}