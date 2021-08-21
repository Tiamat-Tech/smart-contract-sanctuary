// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/LibPart.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";

/**
 * @title XRaver contract
 * @dev Extends ERC721 Enumerable Non-Fungible Token Standard basic implementation
 */
contract XRaver is ERC721Enumerable, Ownable, RoyaltiesV2Impl {
    uint256 public constant MAX_XRAVERS = 15000;
    uint256 public constant MAX_PURCHASE_COUNT = 20;
    uint256 public constant XRAVER_PRICE = 80000000000000000; // 0.08 ETH
    uint96 public constant ROYALTY = 1000;
    bool public saleIsActive;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    string internal _uri;

    constructor(string memory uri) ERC721("X Ravers NFT", "XR") {
        _uri = uri;
        _reserveXRavers();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable)
        returns (bool)
    {
        if (interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        if (interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    /**
     * Withdraw ethers from the mint
     */
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        require(amount >= 0, "XRaver: INSUFFICIENT_BALANCE");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = _msgSender().call{value: amount}("");
        require(success, "XRaver: SEND_REVERT");
    }

    /*
     * Pause sale if active, make active if paused
     */
    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**
     * Mints X Ravers
     */
    function mint(uint256 numberOfTokens) public payable {
        require(saleIsActive, "XRaver: SALE_NOT_ACTIVE");
        require(
            numberOfTokens <= MAX_PURCHASE_COUNT,
            "XRaver: MINT_LIMIT_OVERFLOW"
        );
        require(
            totalSupply() + numberOfTokens <= MAX_XRAVERS,
            "XRaver: TOTAL_SUPPLY_OVERFLOW"
        );
        require(
            XRAVER_PRICE * numberOfTokens <= msg.value,
            "XRaver: NOT_ENOUGH_ETHER"
        );

        uint256 supply = totalSupply();
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 tokenId = supply + i;
            _safeMint(_msgSender(), tokenId);
            _setOwnerRoyalties(tokenId);
        }
    }

    /**
     * Get royalty info
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        LibPart.Part[] memory _royalties = royalties[_tokenId];
        if (_royalties.length > 0) {
            return (
                _royalties[0].account,
                (_salePrice * _royalties[0].value) / 10000
            );
        }
        return (address(0), 0);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    /**
     * Set some XRavers aside (for dev team)
     */
    function _reserveXRavers() internal {
        uint256 supply = totalSupply();
        for (uint256 i = 0; i < 30; i++) {
            uint256 tokenId = supply + i;
            _safeMint(_msgSender(), tokenId);
            _setOwnerRoyalties(tokenId);
        }
    }

    function _setOwnerRoyalties(uint256 _tokenId) internal {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = ROYALTY;
        _royalties[0].account = payable(owner());
        _saveRoyalties(_tokenId, _royalties);
    }
}