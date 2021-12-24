pragma solidity 0.7.6;
pragma abicoder v2;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "./erc-721/ERC721Base.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract YourCollectible is ERC721Base {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() public ERC721Lazy() {
    _setBaseURI("https://ipfs.io/ipfs/");
  }

  function mintItem(address to, string memory tokenURI)
      public
      returns (uint256)
  {
      _tokenIds.increment();

      uint256 id = _tokenIds.current();
      _mint(to, id);
      _setTokenURI(id, tokenURI);

      return id;
  }
}




// pragma solidity 0.7.6;
// pragma abicoder v2;

// import "./erc-721/ERC721Base.sol";

// contract YourCollectible is ERC721Base {

//     event CreateERC721Rarible(address owner, string name, string symbol);

//     function __ERC721Rarible_init(string memory _name, string memory _symbol, string memory baseURI, string memory contractURI, address transferProxy, address lazyTransferProxy) external initializer {
//         __ERC721Rarible_init_unchained(_name, _symbol, baseURI, contractURI, transferProxy, lazyTransferProxy);
//         emit CreateERC721Rarible(_msgSender(), _name, _symbol);
//     }

//     function __ERC721Rarible_init_unchained(string memory _name, string memory _symbol, string memory baseURI, string memory contractURI, address transferProxy, address lazyTransferProxy) internal {
//         _setBaseURI(baseURI);
//         __ERC721Lazy_init_unchained();
//         __RoyaltiesV2Upgradeable_init_unchained();
//         __Context_init_unchained();
//         __ERC165_init_unchained();
//         __Ownable_init_unchained();
//         __ERC721Burnable_init_unchained();
//         __Mint721Validator_init_unchained();
//         __HasContractURI_init_unchained(contractURI);
//         __ERC721_init_unchained(_name, _symbol);

//         //setting default approver for transferProxies
//         _setDefaultApproval(transferProxy, true);
//         _setDefaultApproval(lazyTransferProxy, true);
//     }

//     uint256[50] private __gap;
// }