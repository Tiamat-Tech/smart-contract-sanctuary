// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";
import "./IterableMapping.sol";
import "hardhat/console.sol";

contract RealEstateSell is
    ERC721("", ""),
    ERC721Pausable,
    ERC721Burnable,
    Ownable
{
    address newRealEstate;

    function setNewRealEstate(address _address) external onlyOwner {
        _pause();
        newRealEstate = _address;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    constructor() {
        _setBaseURI("lol/");
        fee = 10;
    }

    using IterableMapping for itmap;
    itmap realEstates;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 fee;

    event NewRealEstate(uint256 id);
    event EditedRealEstate(uint256 id);

    function createRealEstate(RealEstate memory realEstate)
        external
        returns (uint256)
    {
        require(realEstate.id == 0, "Id is not null");
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _mint(msg.sender, id);
        realEstate.id = id;
        realEstates.insert(id, realEstate);
        NewRealEstate(id);
        return id;
    }

    function editRealEstate(RealEstate memory realEstate) external {
        require(realEstates.contains(realEstate.id), "Not Found");
        require(ownerOf(realEstate.id) == msg.sender, "Not Owner");
        realEstates.data[realEstate.id].value = realEstate;
        EditedRealEstate(realEstate.id);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(fee >= 0 && fee <= 100, "Fee must be between 0 and 100");
        fee = _fee;
    }

    function getRealEstates()
        external
        view
        returns (RealEstate[] memory visibleRealEstate)
    {
        RealEstate[] memory realEstatesTemp =
            new RealEstate[](realEstates.size);
        uint256 count = 0;
        for (
            uint256 i = realEstates.iterate_start();
            realEstates.iterate_valid(i);
            i = realEstates.iterate_next(i)
        ) {
            (, RealEstate memory val) = realEstates.iterate_get(i);
            if (val.isSelling == true) {
                realEstatesTemp[count] = val;
                count += 1;
            }
        }

        visibleRealEstate = new RealEstate[](count);
        for (uint256 i = 0; i < count; i++) {
            visibleRealEstate[i] = realEstatesTemp[i];
        }
    }

    function getOwnRealEstates()
        external
        view
        returns (RealEstate[] memory ownRealEstates)
    {
        uint256 size = balanceOf(msg.sender);
        ownRealEstates = new RealEstate[](size);
        for (uint256 i = 0; i < size; i++) {
            uint256 id = tokenOfOwnerByIndex(msg.sender, i);
            ownRealEstates[i] = realEstates.data[id].value;
        }
    }

    function getById(uint256 id) external view returns (RealEstate memory) {
        require(_exists(id), "Not Found");
        if (!realEstates.data[id].value.isSelling) {
            require(ownerOf(id) == msg.sender, "Not Authorized");
        }
        return realEstates.data[id].value;
    }

    function buy(uint256 id) external payable {
        require(_exists(id), "Not Found");
        require(msg.sender != ownerOf(id), "Self buy");
        RealEstate memory realEstate = realEstates.data[id].value;
        require(realEstate.isSelling, "Not Selling");
        require(msg.value == realEstate.price,"Wrong Amount");

        address payable tokenOwner = payable(ownerOf(id));
        tokenOwner.transfer((msg.value / 100) * (100 - fee));

        _transfer(tokenOwner, msg.sender, id);
    }

    function withdraw() external onlyOwner {
        address contractAddr = address(this);
        address payable ownerAddr = payable(owner());
        ownerAddr.transfer(contractAddr.balance);
    }
}