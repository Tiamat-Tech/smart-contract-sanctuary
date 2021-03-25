// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library MomentState {

    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Represents an address' ownership of a particular moment (ERC1155 token) with a unique # mint number.
    struct Moment {
        address owner;
        address creator;
        string URI;

        uint momentID;
        uint mintNumber;  
        uint rarity;

        uint price;
        bool forSale;

        uint blockOfPurchase;
    }

    /// @notice Represents the total state of a particular moment. 
    struct MomentStore {
        address creator;
        string URI;
        uint momentID;

        mapping(uint => Moment) moment;
        mapping(address => EnumerableSet.UintSet) mintNumbersOwned;
        uint nextMintNumber;
    }

    function onMomentUpload (
        MomentStore storage self,
        uint _momentID,
        string calldata _URI,
        address _creator
    ) public {

        self.creator = _creator;
        self.URI = _URI;
        self.momentID = _momentID;
    }

    function onMomentMint(
        MomentStore storage self,
        address _creator,
        address _to,
        uint _momentID,
        uint rarity
    ) public returns (uint mintNumber) {

        self.nextMintNumber += 1;
        mintNumber = self.nextMintNumber;

        Moment memory moment;

        // Immutable
        moment.creator = _creator;
        moment.momentID = _momentID;
        moment.mintNumber = mintNumber;
        moment.URI = self.URI;
        moment.rarity = rarity;

        // Variables that can be updated
        moment.owner = _to;
        moment.forSale = false;
        moment.price = 0;
        moment.blockOfPurchase = block.number;

        self.moment[mintNumber] = moment;
        EnumerableSet.add(self.mintNumbersOwned[_to], mintNumber);
    }

    function onMomentTransfer(
        MomentStore storage self,
        address _from,
        address _to,
        uint _mintNumber
    ) public {

        EnumerableSet.remove(self.mintNumbersOwned[_from], _mintNumber);
        EnumerableSet.add(self.mintNumbersOwned[_to], _mintNumber);

        Moment memory moment = self.moment[_mintNumber];

        moment.owner = _to;
        moment.forSale = false;
        moment.price = 0;
        moment.blockOfPurchase = block.number;
        
        self.moment[_mintNumber] = moment;
    }

    function onChangeStatus(
        MomentStore storage self,
        uint _mintNumber,
        uint _newPrice, 
        bool _forSale
    ) public {

        Moment memory moment = self.moment[_mintNumber];

        moment.forSale = _forSale;
        moment.price = _newPrice;

        self.moment[_mintNumber] = moment;
    }
}