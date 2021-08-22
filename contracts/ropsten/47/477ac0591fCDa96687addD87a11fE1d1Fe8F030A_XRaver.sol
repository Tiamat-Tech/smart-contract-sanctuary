// SPDX-License-Identifier: MIT

//  __    __  _______
// /  |  /  |/       \
// $$ |  $$ |$$$$$$$  |  ______   __     __  ______    ______    _______
// $$  \/$$/ $$ |__$$ | /      \ /  \   /  |/      \  /      \  /       |
//  $$  $$<  $$    $$<  $$$$$$  |$$  \ /$$//$$$$$$  |/$$$$$$  |/$$$$$$$/
//   $$$$  \ $$$$$$$  | /    $$ | $$  /$$/ $$    $$ |$$ |  $$/ $$      \
//  $$ /$$  |$$ |  $$ |/$$$$$$$ |  $$ $$/  $$$$$$$$/ $$ |       $$$$$$  |
// $$ |  $$ |$$ |  $$ |$$    $$ |   $$$/   $$       |$$ |      /     $$/
// $$/   $$/ $$/   $$/  $$$$$$$/     $/     $$$$$$$/ $$/       $$$$$$$/
//

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./@rarible/royalties/contracts/impl/SingleRoyaltiesV2Impl.sol";
import "./@rarible/royalties/contracts/LibPart.sol";
import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";

/**
 * @title XRaver contract
 * @dev Extends ERC721 Enumerable Non-Fungible Token Standard basic implementation
 */
contract XRaver is
    ERC721Enumerable,
    ReentrancyGuard,
    Ownable,
    SingleRoyaltiesV2Impl
{
    uint256 public immutable MAX_XRAVERS;
    uint256 public constant MAX_RESERVED_TOKEN_ID = 150;
    uint256 public constant MAX_PURCHASE_COUNT = 20;
    uint256 public constant XRAVER_PRICE = 80000000000000000; // 0.08 ETH
    uint96 public constant ROYALTY = 1000; // 10%
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    bool public saleIsActive;
    address public royaltyOwner;
    string private _uri;
    uint256 private _reserveCursor;

    constructor(
        string memory uri,
        address _royaltyOwner,
        uint256 _maxXravers
    ) ERC721("X Ravers NFT", "XR") {
        require(
            _maxXravers > MAX_RESERVED_TOKEN_ID,
            "XRaver: INSUFFICIENT_COUNT"
        );
        _uri = uri;
        royaltyOwner = _royaltyOwner;
        MAX_XRAVERS = _maxXravers;
        _setOwnerRoyalties(royaltyOwner);
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
        _unsafeTransfer(royaltyOwner, amount);
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
    function mint(uint256 numberOfTokens) public payable nonReentrant {
        require(saleIsActive, "XRaver: SALE_NOT_ACTIVE");
        require(numberOfTokens != 0, "XRaver: MINT_MIN_AT_LEAST_ONE");
        require(
            numberOfTokens <= MAX_PURCHASE_COUNT,
            "XRaver: MINT_LIMIT_OVERFLOW"
        );
        require(
            totalSupply() > MAX_RESERVED_TOKEN_ID,
            "XRaver: RESERVE_NOT_MINTED"
        );
        require(
            totalSupply() + numberOfTokens <= MAX_XRAVERS,
            "XRaver: TOTAL_SUPPLY_OVERFLOW"
        );
        uint256 price = XRAVER_PRICE * numberOfTokens;
        require(price <= msg.value, "XRaver: NOT_ENOUGH_ETHER");

        uint256 supply = totalSupply();
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _mintWithRoyalty(_msgSender(), supply + i);
        }

        // return rest amount
        if (price < msg.value) {
            _unsafeTransfer(_msgSender(), msg.value - price);
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
        LibPart.Part[] memory _royalties = _getRoyalties();
        if (_royalties.length > 0) {
            return (
                _royalties[0].account,
                (_salePrice * _royalties[0].value) / 10000
            );
        }
        return (address(0), 0);
    }

    /**
     * Change owner for royalty, expensive transaction
     */
    function changeRoyaltyOwner(address _royaltyOwner) public onlyOwner {
        require(_royaltyOwner != address(0), "XRaver: ZERO_OWNER");
        _updateAccountRoyalties(royaltyOwner, _royaltyOwner);
        royaltyOwner = _royaltyOwner;
    }

    /**
     * Set some XRavers aside for fantom, dev team and promo
     */
    function reserve() external onlyOwner {
        require(_reserveCursor < MAX_RESERVED_TOKEN_ID, "XRaver: FULL_RESERVE");
        uint256 mintLimit = 50; // gas limitator
        uint256 i;
        if (_reserveCursor > 0) {
            i = _reserveCursor + 1;
        } else {
            i = _reserveCursor;
        }
        for (; i <= _reserveCursor + mintLimit; i++) {
            _mintWithRoyalty(_msgSender(), i);
        }
        _reserveCursor = totalSupply() - 1;
    }

    function _unsafeTransfer(address to, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "XRaver: INSUFFICIENT_BALANCE"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = to.call{value: amount}("");
        require(success, "XRaver: SEND_REVERT");
    }

    function _mintWithRoyalty(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId);
        _onRoyaltiesSet(tokenId);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function _setOwnerRoyalties(address royaltyAddress) internal {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = ROYALTY;
        _royalties[0].account = payable(royaltyAddress);
        _saveRoyalties(_royalties);
    }
}