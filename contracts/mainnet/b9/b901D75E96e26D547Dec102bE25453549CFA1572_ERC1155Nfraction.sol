// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;
pragma abicoder v2;

import "./ERC1155Base.sol";

contract ERC1155Nfraction is ERC1155Base {
    event CreateERC1155Nfraction(address owner, string name, string symbol);

    function __ERC1155Nfraction_init(string memory _name, string memory _symbol, string memory baseURI, string memory contractURI) external initializer {
        __Ownable_init_unchained();
        __ERC1155Lazy_init_unchained();
        __ERC165_init_unchained();
        __Context_init_unchained();
        __Mint1155Validator_init_unchained();
        __ERC1155_init_unchained("");
        __HasContractURI_init_unchained(contractURI);
        __ERC1155Burnable_init_unchained();
        __RoyaltiesV2Upgradeable_init_unchained();
        __ERC1155Base_init_unchained(_name, _symbol);
        _setBaseURI(baseURI);
        emit CreateERC1155Nfraction(_msgSender(), _name, _symbol);
    }
    uint256[50] private __gap;
}