// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract RarePepe is ERC721Enumerable, Ownable {
    bool private _initialized;
    string private _ipfsPrefix;
    string private _contractMetadataHash;
    string private _tokenMetadataHash;
    uint256 private _maxSupply;
    uint256 private _currentPrice;
    uint256 private _priceIncrement;
    uint256 private _seed;
    uint16[] private _availablePepeIds;

    constructor()
        ERC721("Rare Pepe", "RAREPEPE")
    {
        _ipfsPrefix = "ipfs://";
        _priceIncrement = 0.005 ether;
        _currentPrice = 0.015 ether;
    }


    /**
     *  _____       _                        _ 
     * |_   _|     | |                      | |
     *   | |  _ __ | |_ ___ _ __ _ __   __ _| |
     *   | | | '_ \| __/ _ \ '__| '_ \ / _` | |
     *  _| |_| | | | ||  __/ |  | | | | (_| | |
     * |_____|_| |_|\__\___|_|  |_| |_|\__,_|_|
     */

    function _baseURI()
        internal
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(_ipfsPrefix, _tokenMetadataHash));
    }

    function _generateRandomInteger(uint256 modulus)
        internal
        returns (uint256)
    {
        _seed = uint256(keccak256(abi.encodePacked(
                _seed, 
                blockhash(block.number - 1),
                block.coinbase, 
                block.timestamp
               )));
        return _seed % modulus;
    }

    // Adopted from Provable Things
    // https://github.com/provable-things/ethereum-api/blob/master/provableAPI_0.6.sol
    // https://stackoverflow.com/a/65707309
    function uint256ToString(uint256 unsignedInteger)
        internal
        pure
        returns (string memory _uint256AsString)
    {
        if (unsignedInteger == 0) {
            return "0";
        }
        uint256 j = unsignedInteger;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (unsignedInteger != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(unsignedInteger - unsignedInteger / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            unsignedInteger /= 10;
        }
        return string(bstr);
    }


    /**
     * _____       _     _ _      
     * |  __ \     | |   | (_)     
     * | |__) |   _| |__ | |_  ___ 
     * |  ___/ | | | '_ \| | |/ __|
     * | |   | |_| | |_) | | | (__ 
     * |_|    \__,_|_.__/|_|_|\___|
     */

    function remainingPepeSupply()
        public
        view
        returns (uint256)
    {
        return _availablePepeIds.length;
    }

    // Token metadata as per https://docs.opensea.io/docs/contract-level-metadata
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");

        return string(abi.encodePacked(_baseURI(), "/", uint256ToString(tokenId), ".json"));
    }


    /**
     *  ______      _                        _ 
     * |  ____|    | |                      | |
     * | |__  __  _| |_ ___ _ __ _ __   __ _| |
     * |  __| \ \/ / __/ _ \ '__| '_ \ / _` | |
     * | |____ >  <| ||  __/ |  | | | | (_| | |
     * |______/_/\_\\__\___|_|  |_| |_|\__,_|_|
     */

    function priceIncrement()
        external
        view
        returns (uint256)
    {
        return _priceIncrement;
    }

    function currentPrice()
        external
        view
        returns (uint256)
    {
        return _currentPrice;
    }

    function maxPrice()
        external
        view
        returns (uint256)
    {
        return _currentPrice + ((remainingPepeSupply() - 1) * _priceIncrement);
    }

    function maxSupply()
        external
        view
        returns (uint256)
    {
        return _maxSupply;
    }

    // Contract metadata as per https://docs.opensea.io/docs/contract-level-metadata
    function contractURI()
        external
        view
        returns (string memory)
    {
        return string(abi.encodePacked(_ipfsPrefix, _contractMetadataHash));
    }

    function claim()
        external
        payable
        returns (uint16)
    {
        require(msg.value >= _currentPrice, "Insufficient payment, try again");
        require(remainingPepeSupply() > 0, "No pepes left");

        // Set its hash
        uint256 randomIndex = _generateRandomInteger(remainingPepeSupply());
        uint16 newTokenId = _availablePepeIds[randomIndex];
        _mint(msg.sender, newTokenId);

        // Prepare for the next TX
        _availablePepeIds[randomIndex] = _availablePepeIds[remainingPepeSupply() - 1];
        _availablePepeIds.pop();
        _currentPrice = _currentPrice + _priceIncrement;

        return newTokenId;
    }


    /**
     *   ____                           
     *  / __ \                          
     * | |  | |_      ___ __   ___ _ __ 
     * | |  | \ \ /\ / / '_ \ / _ \ '__|
     * | |__| |\ V  V /| | | |  __/ |   
     *  \____/  \_/\_/ |_| |_|\___|_|   
     */                             

    function initialize(string memory contractMetadataHash, string memory tokenMetadataHash, uint16[] memory availablePepeIds)
        external
        onlyOwner
    {
        require(!_initialized);
        _initialized = true;

        _contractMetadataHash = contractMetadataHash;
        _tokenMetadataHash = tokenMetadataHash;

        _availablePepeIds = availablePepeIds;
        _maxSupply = availablePepeIds.length;
    }

    function withdraw()
        external
        onlyOwner
    {
        uint256 amount = address(this).balance;
        payable(owner()).transfer(amount);
    }

    function updateContractMetadataHash(string memory contractMetadataHash)
        external
        onlyOwner
    {
        _contractMetadataHash = contractMetadataHash;
    }
}