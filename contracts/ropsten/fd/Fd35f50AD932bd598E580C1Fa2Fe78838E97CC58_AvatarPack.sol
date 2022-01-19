//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
TODO:
✅ Create default handler to receive tokens and increase tips
* AirDrop for Jok Users
*/

contract AvatarPack is ERC1155 {
    using ECDSA for bytes32;

    mapping(address => uint256) public userTips;
    mapping(address => bool) public claimedAddresses;

    uint256 public boxPrice;
    uint256 public packPrice;
    uint8 public boxCountInPack;
    uint32 public itemsCount;
    string public cid;
    uint32 public remainingAirdropUsersCount;
    address admin;

    event BoxOpened(address to, uint256[] itemIds);
    event ItemsClaimed(address to, uint256[] itemIds);

    constructor(
        uint256 _boxPrice,
        uint256 _packPrice,
        uint8 _boxCountInPack,
        uint32 _airdropUsersCount,
        string memory _cid,
        uint32[] memory _itemBalances
    ) ERC1155("") {
        require(_itemBalances.length > 0, "INVALID_ITEM_BALANCES");
        require(_boxPrice < _packPrice, "INVALID_PACK_PRICE");
        require(_boxCountInPack > 1, "TOO_SMALL_PACK_SIZE");
        require(_boxCountInPack < _itemBalances.length, "TOO_LARGE_PACK_SIZE");
        require(bytes(_cid).length >= 46, "INVALID_CID");

        boxPrice = _boxPrice;
        packPrice = _packPrice;
        boxCountInPack = _boxCountInPack;
        itemsCount = uint32(_itemBalances.length);
        cid = _cid;
        remainingAirdropUsersCount = _airdropUsersCount;
        admin = msg.sender;

        // mint all items
        for (uint32 i = 0; i < _itemBalances.length; i++) {
            _mint(address(this), i, _itemBalances[i], "");
        }
    }

    function buyGiftBox() public payable {
        require(msg.value >= boxPrice, "VALUE_LESS_THAN_PRICE");

        uint256 tip = msg.value - boxPrice;

        if (tip > 0) {
            userTips[msg.sender] += tip;
        }

        _buyBoxes(msg.sender, 1);
    }

    function buyGiftPack() public payable {
        require(msg.value >= packPrice, "VALUE_LESS_THAN_PRICE");

        uint256 tip = msg.value - packPrice;

        if (tip > 0) {
            userTips[_msgSender()] += tip;
        }

        _buyBoxes(msg.sender, boxCountInPack);
    }

    function balanceOfAll(address to) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](itemsCount);

        for (uint32 i = 0; i < itemsCount; i++) {
            result[i] = balanceOf(to, i);
        }

        return result;
    }

    function claimItem(
        uint256[] calldata itemIds,
        bytes calldata signature
    ) public {
        require(claimedAddresses[msg.sender] == false, "ALREADY_RECEIVED");

        address signer = keccak256(abi.encodePacked(
                msg.sender,
                itemIds
            ))
            .toEthSignedMessageHash()
            .recover(signature);

        require(signer == admin, "INVALID_SIGNATURE");


        uint256[] memory itemAmounts = new uint256[](itemIds.length);

        for (uint32 i = 0; i < itemIds.length; i++) {
            require(itemIds[i] < itemsCount, "INVALID_ITEMID");
            itemAmounts[i] = 1;

            // search for dublicates
            for (uint32 j = 0; j < itemIds.length; j++) {
                if (i == j) {
                    continue;
                }

                require(itemIds[i] != itemIds[j], "DUB_ITEMID_DETECTED");
            }
        }

        remainingAirdropUsersCount--;
        claimedAddresses[msg.sender] = true;

        _safeBatchTransferFrom(address(this), msg.sender, itemIds, itemAmounts, "");

        emit ItemsClaimed(msg.sender, itemIds);
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        return toFullURI(cid, id);
    }


    // helper functions
    function _buyBoxes(address to, uint8 count) internal {
        uint32 validItemCount = 0;
        uint256 totalAvailableSupply = 0;
        bool[] memory validItems = new bool[](itemsCount);

        for (uint32 i = 0; i < itemsCount; i++){
            uint256 availableSupply = balanceOf(address(this), i);

            if (availableSupply > 0) {
                validItemCount++;
                totalAvailableSupply += availableSupply;
                validItems[i] = true;
            }
        }

        require(totalAvailableSupply >= count, "NOT_ENOUGH_ITEMS_FOR_PACK");

        uint256 randomNumber = _randomNumber();

        uint256[] memory selectedItemIds = new uint256[](count);
        uint256[] memory selectedItemAmounts = new uint256[](count);

        // prepare selected items and amounts
        for (uint8 current = 0; current < count; current++) {
            // pick the random index
            uint256 randomIndex = randomNumber % validItemCount;

            for (uint32 i = 0; i < itemsCount; i++) {
                if (validItems[i]) {
                    if (randomIndex == 0) {
                        selectedItemIds[current] = i;
                        selectedItemAmounts[current] = 1;
                        break;
                    }
                    
                    randomIndex--;
                }
            }

            // shift to prepare for the next iteration.
            randomNumber = randomNumber >>= 1;
        }

        // batch transfer
        _safeBatchTransferFrom(address(this), to, selectedItemIds, selectedItemAmounts, "");

        emit BoxOpened(to, selectedItemIds);
    }

    function _randomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp)));
    }

    function toFullURI(string memory hash, uint256 id) internal pure returns (string memory) {
        return string(abi.encodePacked("ipfs://", hash, "/", uint2str(id), ".json"));
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }

        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }

        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            bstr[--k] = bytes1(uint8(48 + uint8(_i % 10)));
            _i /= 10;
        }

        return string(bstr);
    }


    // process all requests and increase tips
    fallback () external payable {
        userTips[msg.sender] += msg.value;
    }

    receive () external payable {
        userTips[msg.sender] += msg.value;
    }
}