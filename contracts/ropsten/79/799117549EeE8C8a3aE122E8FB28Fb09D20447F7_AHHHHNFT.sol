//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract AHHHHNFT is ERC1155, Ownable {
    address proxyRegistryAddress;

    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => string) customUri;
    mapping(uint256 => bool) created;
    // Contract name
    string public constant name = "AHHHH";
    // Contract symbol
    string public constant symbol = "AHHHH";

    constructor(address _proxyRegistryAddress)
        ERC1155(
            "https://gateway.pinata.cloud/ipfs/QmaPtoWA8c5gZZ6syLvY7fekRBwUJD4wEvEenBSsHRrATp/meta/{id}.json"
        )
        Ownable()
    {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    function setURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(_exists(_id), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        // We have to convert string to bytes to check for existence
        bytes memory customUriBytes = bytes(customUri[_id]);
        if (customUriBytes.length > 0) {
            return customUri[_id];
        } else {
            return super.uri(_id);
        }
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public onlyOwner {
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] += _quantity;
        created[_id] = true;
    }

    /**
     * @dev Mint tokens for each id in _ids
     * @param _to          The address to mint tokens to
     * @param _ids         Array of ids to mint
     * @param _quantities  Array of amounts of tokens to mint per id
     * @param _data        Data to pass if receiver is contract
     */
    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public onlyOwner {
        _mintBatch(_to, _ids, _quantities, _data);
        for (uint256 i; i < _ids.length; i++) {
            tokenSupply[_ids[i]] += _quantities[i];
            created[_ids[i]] = true;
        }
    }

    function setCustomURI(uint256 _tokenId, string memory _newURI)
        public
        onlyOwner
    {
        customUri[_tokenId] = _newURI;
        emit URI(_newURI, _tokenId);
    }

    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }

    function isApprovedForAll(address _owner, address _operator)
        public
        view
        override
        returns (bool isOperator)
    {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistryAddress != address(0)) {
            ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
            if (address(proxyRegistry.proxies(_owner)) == _operator) {
                return true;
            }
        }

        return ERC1155.isApprovedForAll(_owner, _operator);
    }

    function totalSupply(uint256 _id) public view returns (uint256) {
        return tokenSupply[_id];
    }

    function _exists(uint256 _id) internal view returns (bool) {
        return created[_id];
    }
}