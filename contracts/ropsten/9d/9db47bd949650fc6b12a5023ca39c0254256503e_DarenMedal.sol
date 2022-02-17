// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "./DarenToken.sol";
import "./interfaces/IDarenMedal.sol";

contract DarenMedal is
    IDarenMedal,
    ERC721EnumerableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address darenToken;

    uint256 private primaryKey; // Order index
    mapping(uint256 => Order) public orders;

    uint256 public feeRatio; // default: 2.5%
    uint256 public feeRatioBase; // default: 10000
    address public feeTo;

    function initialize(address _darenToken) public initializer {
        __ERC721_init("Daren Medal", "DM");
        __ERC721Enumerable_init();
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);

        darenToken = _darenToken;

        feeRatio = 250; // ratio base is 10000, 250 => 250 / 10000 => 2.5%
        feeRatioBase = 10000;
        feeTo = msg.sender;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721EnumerableUpgradeable,
            AccessControlEnumerableUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function zeng(address account, uint256 tokenId)
        external
        onlyRole(ADMIN_ROLE)
    {
        _mint(account, tokenId);
    }

    function shao(uint256 tokenId) external onlyRole(ADMIN_ROLE) {
        _burn(tokenId);
    }

    // Token ID: [XXXX][YYYYYY][ZZZZZZZZ]
    // XXXX: 4 digits category ID.
    // YYYYYY: 6 digits subcategory ID.
    // ZZZZZZZZ: 8 digits serial number.

    function _getCategory(uint256 tokenId) internal pure returns (uint256) {
        uint256 category = tokenId.div(10**14);
        return category;
    }

    function _getSubCategory(uint256 tokenId) internal pure returns (uint256) {
        uint256 reminder = tokenId.mod(10**14);
        uint256 subCategory = reminder.div(10**8);
        return subCategory;
    }

    function _getSerialNumber(uint256 tokenId) internal pure returns (uint256) {
        uint256 medalNumber = tokenId.mod(10**8);
        return medalNumber;
    }

    function availableToAuditByPrice(
        address _owner,
        uint256 _category,
        uint256 _priceInUSD
    ) external view returns (bool) {
        require(_priceInUSD > 0, "Price should be greater than 0.");

        for (uint256 i = 0; i < balanceOf(_owner); i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);

            uint256 category = _getCategory(tokenId);
            if (category == _category) {
                uint256 subCategory = _getSubCategory(tokenId);
                if (_priceInUSD <= subCategory) {
                    return true;
                } else if (subCategory == 999999) {
                    return true;
                }
            }
        }
        return false;
    }

    function getTokensInCategory(address _owner, uint256 _category)
        external
        view
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(_owner);
        if (balance <= 0) {
            return new uint256[](0);
        }

        uint256 count = 0;
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            uint256 category = _getCategory(tokenId);
            if (category == _category) {
                count++;
            }
        }

        uint256 index = 0;
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            uint256 category = _getCategory(tokenId);
            if (category == _category) {
                ids[index++] = tokenId;
            }
        }

        return ids;
    }

    function hasTokenIdInCategory(address _owner, uint256 _category)
        external
        view
        returns (bool)
    {
        uint256 balance = balanceOf(_owner);
        if (balance <= 0) {
            return false;
        }

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            uint256 category = _getCategory(tokenId);
            if (category == _category) {
                return true;
            }
        }

        return false;
    }

    function setDarenTokenAddress(address _darenTokenAddress)
        external
        onlyRole(ADMIN_ROLE)
    {
        darenToken = _darenTokenAddress;
    }

    // Market ===================================
    function orderOnSale(uint256 _tokenId) public view returns (bool) {
        Order memory order = orders[_tokenId];

        return order.pk > 0;
    }

    // Override =================================
    function transfer(
        address from,
        address to,
        uint256 tokenId
    ) external {
        require(!orderOnSale(tokenId), "Medal is on sale.");

        _transfer(from, to, tokenId);
    }

    function createOrder(uint256 _tokenId, uint256 _price) public {
        require(_price > 0, "Price should be greater than 0.");
        address sender = _msgSender();
        require(
            ownerOf(_tokenId) == sender,
            "Only the owner can create order."
        );

        Order memory order = orders[_tokenId];
        if (order.price == _price && order.seller == sender) {
            require(false, "Duplicated order.");
        }

        primaryKey += 1;
        orders[_tokenId] = Order({
            pk: primaryKey,
            tokenId: _tokenId,
            price: _price,
            seller: sender,
            createdAt: block.timestamp
        });

        emit OrderCreated({tokenId: _tokenId, price: _price, seller: sender});
    }

    function getOrder(uint256 _tokenId)
        public
        view
        returns (
            bool onSale,
            uint256 tokenId,
            uint256 price,
            address seller,
            uint256 createdAt
        )
    {
        Order memory order = orders[_tokenId];
        bool isOnSale = order.pk > 0 ? true : false;
        return (isOnSale, _tokenId, order.price, order.seller, order.createdAt);
    }

    function cancelOrder(uint256 _tokenId) public {
        address sender = _msgSender();
        Order memory order = orders[_tokenId];
        require(order.pk > 0, "Order was not published.");
        require(
            order.seller == sender || hasRole(ADMIN_ROLE, msg.sender),
            "Unauthorized user."
        );

        delete orders[_tokenId];

        emit OrderCanceled(_tokenId);
    }

    function executeOrder(uint256 _tokenId) public {
        address sender = _msgSender();
        Order memory goods = orders[_tokenId];

        require(darenToken != address(0), "Daren Token address wasn't set.");
        DarenToken dt = DarenToken(darenToken);

        require(
            dt.allowance(sender, address(this)) > goods.price,
            "Allowance is not enough."
        );

        uint256 value = goods.price;
        if (feeTo != address(0)) {
            uint256 fee = goods.price.mul(feeRatio).div(feeRatioBase);
            value = goods.price.sub(fee);
            dt.transferFrom(sender, feeTo, fee);
        }
        dt.transferFrom(sender, goods.seller, value);
        _transfer(goods.seller, sender, _tokenId);

        delete orders[_tokenId];

        emit OrderExecuted({
            tokenId: _tokenId,
            price: goods.price,
            buyer: sender,
            seller: goods.seller
        });
    }

    function setFeeRatio(uint256 _fee) external onlyRole(ADMIN_ROLE) {
        feeRatio = _fee;
    }

    function setFeeTo(address payable _feeTo) external onlyRole(ADMIN_ROLE) {
        feeTo = _feeTo;
    }

    function getPrimaryKey()
        public
        view
        onlyRole(ADMIN_ROLE)
        returns (uint256)
    {
        return primaryKey;
    }
}