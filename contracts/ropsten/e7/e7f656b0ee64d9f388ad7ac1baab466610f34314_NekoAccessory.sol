// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NekoAccessory is ERC1155SupplyUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;

    uint256 public constant Reindeer_Hat = 0;
    uint256 public constant Santa_Combo = 1;
    uint256 public constant Santa_Clothe = 2;
    uint256 public constant Christmas_Hat = 3;
    uint256 public constant Small_Christmas_Hat = 4;
    uint256 public constant Hanging_Star = 5;

    string internal baseURI;

    uint256 public price;

    uint256 public maxId;
    
    mapping(uint256 => bool) public mintAble;

    mapping(address => uint256) public whitelistees;

    mapping(address => bool) public whitelistTracker;

    uint256 public freePerWhitelist;

    function initialize() external initializer {
        __Ownable_init();
    }

    /**
     * @dev Mints some amount of token to an address
     * @param _ids    id of token to mint
     * @param _numItems quantity of token to mint
     */
    function mintPublic(uint8[] calldata _ids, uint256[] calldata _numItems)
        public
        payable
    {
        require(_ids.length == _numItems.length);
        uint256 total = 0;
        for (uint256 i = 0; i < _ids.length; i++) {
            total += _numItems[i] * price;
        }
        require(msg.value >= total);
        for (uint256 i = 0; i < _ids.length; i++) {
            _mint(msg.sender, _ids[i], _numItems[i], "");
        }
        for (uint256 i = 0; i < _ids.length; i++) {
            require(mintAble[i] == true, "notMintAble");
        }
    }

    function mintFree(uint8[] calldata _ids, uint256[] calldata _numItems)
        public
    {
        for (uint256 i = 0; i < _ids.length; i++) {
            require(mintAble[i] == true, "notMintAble");
        }
        require(_ids.length == _numItems.length);
        uint256 total = 0;
        for (uint256 i = 0; i < _ids.length; i++) {
            total += _numItems[i];
        }
        require(total <= whitelistees[msg.sender], "exceed free claim");
        for (uint256 i = 0; i < _ids.length; i++) {
            _mint(msg.sender, _ids[i], _numItems[i], "");
            whitelistees[msg.sender] = whitelistees[msg.sender] - 1;
        }
    }

    function mintAdmin(uint8 _id, uint256 _numItem) public onlyOwner {
        _mint(msg.sender, _id, _numItem, "");
    }

    function uri(uint256 _id) public view override returns (string memory) {
        require(bytes(baseURI).length > 0, "ERC1155#uri: BLANK_URI");
        return string(abi.encodePacked(baseURI, Strings.toString(_id)));
    }

    function setURI(string memory newURI) public onlyOwner {
        _setURI(newURI);
        baseURI = newURI;
    }

    function setPrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    function setMaxItem(uint256 _maxId) external onlyOwner {
        maxId = _maxId;
    }

    function withdrawAll() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    function setFreeItemPerWhitelist(uint256 _nr) external onlyOwner {
        freePerWhitelist = _nr;
    }

    function whitelist(address[] calldata _whitelistees) external onlyOwner {
        for (uint256 i = 0; i < _whitelistees.length; i++) {
            require(
                whitelistTracker[_whitelistees[i]] == false,
                "already whitelist"
            );
            whitelistTracker[_whitelistees[i]] = true;
            whitelistees[_whitelistees[i]] = freePerWhitelist;
        }
    }

    function enableMintAble(uint256[] calldata _numItems) external onlyOwner {
        for (uint256 i = 0; i < _numItems.length; i++) {
            mintAble[_numItems[i]] == true;
        }
    }

    function disableMintAble(uint256[] calldata _numItems) external onlyOwner {
        for (uint256 i = 0; i < _numItems.length; i++) {
            mintAble[_numItems[i]] == false;
        }
    }

    /**
     * @dev
     * Requirements:
     * - `_user` cannot be the zero address.
     * - `tokenIds` and `amounts` must have the same length.
     */
    function burnBatch(
        address _user,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) external {
        require(_user != address(0), "burn from the zero address");
        require(_user != address(this), "burn from this contract address");
        require(
            _tokenIds.length == _amounts.length,
            "ids and amounts length mismatch"
        );

        _burnBatch(_user, _tokenIds, _amounts);
    }
}