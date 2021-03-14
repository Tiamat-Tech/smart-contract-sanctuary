// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

library MomentState {

    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Represents an address' ownership of a particular moment (ERC1155 token) with a unique # mint number.
    struct Moment {
        address owner;
        bool forSale;

        uint momentID;
        uint mintNumber;  
        string URI;

        uint price;
        uint timeOfPurchase;
    }

    /// @notice Represents the total state of a particular moment. 
    struct MomentStore {
        address creator;
        string URI;
        uint momentID;

        mapping(uint => Moment) mintNumber_to_moment;
        uint nextMintNumber;
    }

    /// @notice Represents the state of a pack, and an address' ownership of it.
    struct Pack {
        address owner;
        uint id;
        
        uint[] momentIDs;
        uint[] mintNumbers;

        uint price;
        bool forSale;
    }

    function onMomentMint(
        MomentStore storage self,
        uint _momentID,
        string calldata _URI,
        address _creator
    ) public {

        self.creator = _creator;
        self.URI = _URI;
        self.momentID = _momentID;
    }

    function onPublishMoment(
        MomentStore storage self,
        uint _momentID,
        string calldata _URI,
        address _creator
    ) public returns (uint mintNum){

        self.nextMintNumber = self.nextMintNumber + 1;
        mintNum = self.nextMintNumber;

        self.mintNumber_to_moment[mintNum].owner = _creator;
        self.mintNumber_to_moment[mintNum].forSale = false;
        self.mintNumber_to_moment[mintNum].momentID = _momentID;
        self.mintNumber_to_moment[mintNum].mintNumber = mintNum;
        self.mintNumber_to_moment[mintNum].URI = _URI;
        self.mintNumber_to_moment[mintNum].price = 0;
        self.mintNumber_to_moment[mintNum].timeOfPurchase = block.timestamp;

    }

    function onPackMint(
        Pack storage pack,
        address _creator,
        uint _packID,
        uint[] calldata _momentIDs,
        uint[] calldata _mintNumbers,
        uint _price
    ) public {

        pack.owner = _creator;
        pack.id = _packID;
        pack.momentIDs = _momentIDs;
        pack.mintNumbers = _mintNumbers;
        pack.price = _price;
        pack.forSale = true;

    }

    function onPackPurchase(
        Pack storage pack,
        address _to
    ) public {
        pack.owner = _to;
        pack.forSale = false;
    }

    function onSingleMomentTransfer(
        MomentStore storage self,
        address _to,
        uint _mintNumber
    ) public {

        self.mintNumber_to_moment[_mintNumber].owner = _to;
        self.mintNumber_to_moment[_mintNumber].forSale = false;
        self.mintNumber_to_moment[_mintNumber].price = 0;
        self.mintNumber_to_moment[_mintNumber].timeOfPurchase = block.timestamp;
    }

    function onSaleStatus(
        MomentStore storage self,
        uint _mintNumber,
        uint _newPrice, 
        bool _forSale
    ) public {

        Moment memory moment = self.mintNumber_to_moment[_mintNumber];

        moment.forSale = _forSale;
        moment.price = _newPrice;

        self.mintNumber_to_moment[_mintNumber] = moment;
    }
}