// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title RewardCollection contract
 * @dev Extends ERC1155 Non-Fungible Token Standard basic implementation
 */

interface IPhatPandaz {
    function lastTransfer(uint256) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface IDateTime {
    function toTimestamp(uint16 year, uint8 month, uint8 day, uint8 hour, uint8 minute) external view returns (uint256);
}

contract RewardCollection is ERC1155, Ownable {
    IPhatPandaz phatPandaz = IPhatPandaz(0x0025F638e410BCB1E535EaDb776E28B1d5588d93);
    IDateTime dateTime = IDateTime(0x9696ad295BE3016C00e80e8aaBbc38EB2A4ff26A);

    uint256 public startTimestamp = 1645387200; // Mar 1st 22 11PM UTC

    mapping(uint256 => mapping (uint256 => bool)) private _rewardClaimNormal;
    mapping(uint256 => mapping (uint256 => bool)) private _rewardClaimSpecial;
    mapping(uint256 => mapping (uint256 => bool)) private _rewardClaimPlatinum;


    mapping(uint256 => uint256) private _totalSupply;

    uint256 private constant FERTILIZER = 0;
    uint256 private constant COCO_CUBEZ = 1;
    uint256 private constant SEEDZ = 2;
    uint256 private constant PLANT = 3;

    uint256 public lastDateNormal = 202202;
    uint256 public lastDateSpecial = 202202;
    uint256 public lastDatePlatinum = 202202;

    uint8 public gapMonthNormal = 3;
    uint8 public gapMonthSpecial = 2;
    uint8 public gapMonthPlatinum = 1;

    uint256 public startHour = 23; // 11PM

    uint256 public holdLimitNormal = 90 days;
    uint256 public holdLimitSpecial = 60 days;

    uint256[] private platinumList = [1, 2, 248, 315, 367, 389, 421, 536, 549, 644, 712, 806, 882, 948, 956, 1020, 1360];
    uint256[] private zkittlezList = [3, 4, 118, 154, 205, 230, 285, 308, 329, 360, 380, 387, 422, 443, 458, 465, 535, 535, 556, 557, 598, 608, 618, 674, 739, 791, 840, 847, 852, 864, 871, 880, 906, 1015, 1086, 1094, 1164, 1165, 1303, 1362];
    uint256[] private terpHogzList = [5, 6, 105, 138, 173, 182, 249, 302, 369, 400, 409, 465, 476, 508, 514, 576, 608, 624, 721, 814, 858, 871, 910, 929, 1000, 1078, 1162, 1177, 1190, 1264, 1291, 1317, 1365];
    uint256[] private charCoirList = [7, 8, 108, 146, 163, 230, 259, 306, 310, 356, 419, 444, 449, 491, 492, 730, 731, 760, 761, 866, 951, 967, 1158, 1212, 1301, 1352];
    uint256[] private vegBloomList = [9, 10, 145, 286, 429, 493, 638, 646, 714, 770, 776, 777, 780, 860, 875, 881, 906, 919, 982, 993, 1006, 1007, 1064, 1204, 1247, 1262, 1304, 1357];

    constructor() ERC1155("") {
        
    }

    function setURI(string memory uri_) external onlyOwner {
        _setURI(uri_);
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        _burn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        _burnBatch(account, ids, values);
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] -= amounts[i];
            }
        }
    }

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return totalSupply(id) > 0;
    }

    function updateGapMonthNormal(uint8 _gapMonthNormal) external onlyOwner {
        require(_gapMonthNormal >=1 && _gapMonthNormal <= 12, "Invalid gap");
        gapMonthNormal = _gapMonthNormal;
    }

    function updateGapMonthSpecial(uint8 _gapMonthSpecial) external onlyOwner {
        require(_gapMonthSpecial >=1 && _gapMonthSpecial <= 12, "Invalid gap");
        gapMonthSpecial = _gapMonthSpecial;
    }

    function updateGapMonthPlatinum(uint8 _gapMonthPlatinum) external onlyOwner {
        require(_gapMonthPlatinum >=1 && _gapMonthPlatinum <= 12, "Invalid gap");
        gapMonthPlatinum = _gapMonthPlatinum;
    }

    function updateStartHour(uint8 _startHour) external onlyOwner {
        require(_startHour >=0 && _startHour <= 23, "Invalid start hour");
        startHour = _startHour;
    }

    function updateHoldLimitNormal(uint256 _holdLimitNormal) external onlyOwner {
        require(_holdLimitNormal >=0 && _holdLimitNormal <= 730 days, "Invalid hold limit");
        holdLimitNormal = _holdLimitNormal;
    }

    function updateHoldLimitSpecial(uint256 _holdLimitSpecial) external onlyOwner {
        require(_holdLimitSpecial >=0 && _holdLimitSpecial <= 730 days, "Invalid hold limit");
        holdLimitSpecial = _holdLimitSpecial;
    }

    function isZkittlez(uint256 tokenId) internal view returns (bool) {
        uint256 i;
        for(i = 0; i < zkittlezList.length; i++) {
            if(tokenId == zkittlezList[i])
                return true;
        }
        return false;
    }

    function isTerpHogz(uint256 tokenId) internal view returns (bool) {
        uint256 i;
        for(i = 0; i < terpHogzList.length; i++) {
            if(tokenId == terpHogzList[i])
                return true;
        }
        return false;
    }

    function isCharCoir(uint256 tokenId) internal view returns (bool) {
        uint256 i;
        for(i = 0; i < charCoirList.length; i++) {
            if(tokenId == charCoirList[i])
                return true;
        }
        return false;
    }

    function isVegBloom(uint256 tokenId) internal view returns (bool) {
        uint256 i;
        for(i = 0; i < vegBloomList.length; i++) {
            if(tokenId == vegBloomList[i])
                return true;
        }
        return false;
    }

    function isPlatinum(uint256 tokenId) internal view returns (bool) {
        uint256 i;
        for(i = 0; i < platinumList.length; i++) {
            if(tokenId == platinumList[i])
                return true;
        }
        return false;
    }

    function isNormal(uint256 tokenId) internal view returns (bool) {
        if (isZkittlez(tokenId))
            return false;
        if (isTerpHogz(tokenId))
            return false;
        if (isCharCoir(tokenId))
            return false;
        if (isVegBloom(tokenId))
            return false;
        if (isPlatinum(tokenId))
            return false;
        return true;
    }

    function getEndTimestamp(uint8 which) public view returns (uint256) {
        uint16 year;
        uint8 month;
        uint256 lastDate;

        if(which == 0)
            lastDate = lastDateNormal;
        else if(which == 1)
            lastDate = lastDateSpecial;
        else
            lastDate = lastDatePlatinum;

        year = uint16(lastDate / 100);
        month = uint8(lastDate % 100);

        if(which == 0)
            month = month + gapMonthNormal;
        else if(which == 1)
            month = month + gapMonthSpecial;
        else
            month = month + gapMonthPlatinum;

        year = year + month / 13;
        month = month % 12 == 0 ? 12 : month % 12;

        return dateTime.toTimestamp(year, month, 1, uint8(startHour), 0);
    }

    function claimPlant() external {
        uint256[] memory ids = new uint256[](3);
        ids[0] = FERTILIZER;
        ids[1] = COCO_CUBEZ;
        ids[2] = SEEDZ;

        uint256[] memory values = new uint256[](3);
        values[0] = 1;
        values[1] = 1;
        values[2] = 1;

        _burnBatch(msg.sender, ids, values);

        _mint(msg.sender, PLANT, 1, "");
    }

    function claimPlatinum(uint256 tokenId) external {
        require(block.timestamp >= startTimestamp, "Not started yet");
        require(phatPandaz.ownerOf(tokenId) == msg.sender, "You are not owner.");
        require(isPlatinum(tokenId), "Not Platinum Pandaz");

        if(block.timestamp > getEndTimestamp(2)) {
            uint256 year = lastDatePlatinum / 100;
            uint256 nextMonth = lastDatePlatinum % 100 + gapMonthPlatinum;
            lastDatePlatinum = (year + nextMonth / 13) * 100 + nextMonth % 12 == 0 ? 12 : nextMonth % 12;
        }

        require(_rewardClaimPlatinum[lastDatePlatinum][tokenId] == false, "Already claimed");
        _rewardClaimPlatinum[lastDatePlatinum][tokenId] = true;
        _mint(msg.sender, SEEDZ, 1, "");
    }

    function claimSpecial(uint256 tokenId) internal {
        require(block.timestamp >= startTimestamp, "Not started yet");
        require(phatPandaz.ownerOf(tokenId) == msg.sender, "You are not owner.");

        if(block.timestamp > getEndTimestamp(1)) {
            uint256 year = lastDateSpecial / 100;
            uint256 nextMonth = lastDateSpecial % 100 + gapMonthSpecial;
            lastDateSpecial = (year + nextMonth / 13) * 100 + nextMonth % 12 == 0 ? 12 : nextMonth % 12;
        }

        require(lastDateSpecial == 202203 || block.timestamp - phatPandaz.lastTransfer(tokenId) >= holdLimitSpecial, "Not hodl enough");
        require(_rewardClaimSpecial[lastDateSpecial][tokenId] == false, "Already claimed");
        _rewardClaimSpecial[lastDateSpecial][tokenId] = true;
    }

    function claimZkittlez(uint256 tokenId) external {
        require(isZkittlez(tokenId), "Not Zkittlez Pandaz");

        claimSpecial(tokenId);

        _mint(msg.sender, SEEDZ, 1, "");
    }

    function claimTerpHogz(uint256 tokenId) external {
        require(isTerpHogz(tokenId), "Not Terp Hogz Pandaz");

        claimSpecial(tokenId);

        _mint(msg.sender, SEEDZ, 1, "");
    }

    function claimCharCoir(uint256 tokenId) external {
        require(isCharCoir(tokenId), "Not Char Coir Pandaz");

        claimSpecial(tokenId);

        _mint(msg.sender, COCO_CUBEZ, 1, "");
    }

    function claimVegBloom(uint256 tokenId) external {
        require(isVegBloom(tokenId), "Not Veg+Bloom Pandaz");

        claimSpecial(tokenId);

        _mint(msg.sender, FERTILIZER, 1, "");
    }

    function claimNormal(uint256 tokenId, uint256 randNo) external {
        require(block.timestamp >= startTimestamp, "Not started yet");
        require(phatPandaz.ownerOf(tokenId) == msg.sender, "You are not owner.");
        require(isNormal(tokenId), "Not Normal Pandaz");

        if(block.timestamp > getEndTimestamp(0)) {
            uint256 year = lastDateNormal / 100;
            uint256 nextMonth = lastDateNormal % 100 + gapMonthNormal;
            lastDateNormal = (year + nextMonth / 13) * 100 + nextMonth % 12 == 0 ? 12 : nextMonth % 12;
        }

        require(lastDateNormal == 202203 || block.timestamp - phatPandaz.lastTransfer(tokenId) >= holdLimitNormal, "Not hodl enough");
        require(_rewardClaimNormal[lastDateNormal][tokenId] == false, "Already claimed");
        _rewardClaimNormal[lastDateNormal][tokenId] = true;


        uint256 rand = uint256(keccak256(abi.encode(block.timestamp, block.difficulty, msg.sender, tokenId, randNo))) % 1000;

        if((rand >= 200 && rand < 250) || (rand >= 600 && rand < 650))
            _mint(msg.sender, FERTILIZER, 1, "");
        else if((rand >= 100 && rand < 140) || (rand >= 450 && rand < 485))
            _mint(msg.sender, COCO_CUBEZ, 1, "");
        else if((rand >= 300 && rand < 330) || (rand >= 830 && rand < 850))
            _mint(msg.sender, SEEDZ, 1, "");
    }

    function updateStartTimestamp(uint8 _startTimestamp) external onlyOwner {
        startTimestamp = _startTimestamp;
    }
}