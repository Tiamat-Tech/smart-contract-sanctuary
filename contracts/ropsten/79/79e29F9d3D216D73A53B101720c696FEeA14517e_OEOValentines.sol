// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract OwnableDelegateProxy {}

contract OpenSeaProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract OEOValentines is ERC721URIStorage {

    address public owner;
    address public immutable proxyRegistryAddress;
    bool futureAirdropsDisabled = false;

    constructor(address _proxyRegistryAddress) ERC721("OEO Valentines", "OEOV") {
        owner = msg.sender;
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function airdrop(address[] memory recipients, string[] memory tokenURIs) public {
        require(msg.sender == owner, "OEOV: Only Owner");
        require(!futureAirdropsDisabled, "OEOV: All future airdrops are disabled");

        for (uint i = 0; i < recipients.length; ++i) {
            _safeMint(recipients[i], i);
            _setTokenURI(i, tokenURIs[i]);
        }
    }

    function disableFutureAirdrops() public {
        require(msg.sender == owner, "OEOV: Only Owner");

        // This cannot be undone
        futureAirdropsDisabled = true;
    }

    function isApprovedForAll(address _owner, address operator) public view override returns (bool) {
        OpenSeaProxyRegistry proxyRegistry = OpenSeaProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(_owner)) == operator) return true;
        return super.isApprovedForAll(_owner, operator);
    }
}