// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LimitedRepublic is Ownable, ERC721URIStorage {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string public baseTokenURI;
    string internal baseExtension = ".json";
    string public hiddenMetadataUri;
    bool public isPreSale = true;
    bool public revealed = false;
    uint256 public saleCost = 0.02 ether;
    uint8 public maxSupply = 25;
    uint8 public maxTokenPerMint = 3;
    uint8 public firstDiscount = 50;
    uint8 public secondDiscount = 20;

    constructor() ERC721("LimitedRepublicDecades", "LPD") {
        setHiddenMetadataUri(
            "ipfs://QmdNw2KZNrdWLYFhjqu9v4d2cRqRRy5wsD6cF7TPVSvz4q/_metadata.json"
        );
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function validateMint(uint16 _discount, uint256 _tokenAmount) internal {
        uint256 supply = totalSupply();

        if (isPreSale) {
            require(
                _discount == firstDiscount || _discount == secondDiscount,
                "Discount is not in range"
            );
        }

        require(
            _tokenAmount + supply <= maxSupply,
            "Token amount exceeds max supply"
        );

        require(
            _tokenAmount > 0 && _tokenAmount <= maxTokenPerMint,
            "Cannot mint, amount 0 or max amount per mint exceeded"
        );

        uint256 totalCost = saleCost * _tokenAmount;
        uint256 discountCalc = (totalCost * _discount) / 100;
        uint256 saleCosttWithDiscount = totalCost - discountCalc;

        if (isPreSale) {
            require(
                msg.value == saleCosttWithDiscount,
                "Not enough ether provided"
            );
        } else {
            require(
                msg.value >= saleCost * _tokenAmount,
                "Not enough ether provided"
            );
        }
    }

    function mint(
        address _to,
        uint256 _tokenAmount,
        uint8 _discount
    ) public payable {
        validateMint(_discount, _tokenAmount);

        for (uint256 i = 1; i <= _tokenAmount; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current() + 1;

            _safeMint(_to, newItemId);

            _setTokenURI(
                newItemId,
                string(
                    abi.encodePacked(
                        baseTokenURI,
                        newItemId.toString(),
                        baseExtension
                    )
                )
            );
        }
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setRevealed(bool _revealed) public onlyOwner {
        revealed = _revealed;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!revealed) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();

        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        baseTokenURI = _uri;
    }

    function setIsPreSale(bool _isPreSale) public onlyOwner {
        isPreSale = _isPreSale;
    }

    function setMaxTokenPerMint(uint8 _maxTokenPerMint) public onlyOwner {
        maxTokenPerMint = _maxTokenPerMint;
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}