// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "./ERC721Lazy.sol";

contract ERC721GlipLive is ERC721Lazy {

    event CreateERC721GlipLive(address owner, string name, string symbol);

    // constructor() public initializer {}

    // address transferProxy, address lazyTransferProxy
    function __ERC721GlipLive_init(string memory _name, string memory _symbol, bool _global, string memory baseURI, string memory contractURI, address exchangeProxy, address defaultMinter) public initializer {
        __ERC721GlipLive_init_unchained(_name, _symbol, _global, baseURI, contractURI, exchangeProxy, defaultMinter); // transferProxy, lazyTransferProxy
        emit CreateERC721GlipLive(_msgSender(), _name, _symbol);
    }

    // address transferProxy, address lazyTransferProxy
    function __ERC721GlipLive_init_unchained(string memory _name, string memory _symbol, bool _global, string memory baseURI, string memory contractURI, address exchangeProxy, address defaultMinter) internal {
        _setBaseURI(baseURI);
        __ERC721Lazy_init_unchained(_global, defaultMinter);
        __RoyaltiesUpgradeable_init_unchained();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __Ownable_init_unchained();
        __ERC721Burnable_init_unchained();
        __Mint721Validator_init_unchained();
        __HasContractURI_init_unchained(contractURI);
        __ERC721_init_unchained(_name, _symbol);

        //setting default approver for transferProxies
        _setDefaultApproval(exchangeProxy, true);
        // _setDefaultApproval(lazyTransferProxy, true);
    }

    uint256[50] private __gap;
}