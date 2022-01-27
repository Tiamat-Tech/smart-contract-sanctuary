/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// Sources flattened with hardhat v2.8.3 https://hardhat.org

// File @openzeppelin/contracts/utils/[email protected]

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}



pragma solidity ^0.8.0;
contract Oracle {
    using Counters for Counters.Counter;
  
    struct Offer {
        string title;
        string description;
        uint256 reward;
        uint256 numberOfOracles;
        uint256 oracleLockValue;
        uint256 deadline;
        uint256 id;
    }

    struct answerType{
        address[] senders;
        uint256 answersCount;
        string fileHash;
        string fileUrl;
    }

    struct MoreInfo {
        address owner;
        uint256 answersTypeCount;
        mapping (uint256 => answerType) answers;
    }

    mapping(uint256 => Offer) private offers;
    mapping(uint256 => MoreInfo) private moreinfo;

    uint256 private offersCount;
    Counters.Counter private activeOffersCount;

    event NewOffer(Offer);

    function createOffer(
        string calldata title,
        string calldata description,
        uint256 numberOfOracles,
        uint256 oracleLockValue,
        uint256 activeDays
    ) public payable returns (uint256) {
        require(msg.value > 0, "Reward must be greater than 0");

        Offer storage o = offers[++offersCount];
        o.title = title;
        o.description = description;
        o.reward = msg.value;
        o.numberOfOracles = numberOfOracles;
        o.oracleLockValue = oracleLockValue;
        o.deadline = block.timestamp + (activeDays * 24 * 60 * 60);
        o.id = offersCount;

        MoreInfo storage i = moreinfo[offersCount];
        i.owner = msg.sender;

        activeOffersCount.increment();

        emit NewOffer(o);

        return offersCount;
    }

    function getOffer(uint256 offerNumber) public view returns (Offer memory) {
        return offers[offerNumber];
    }

    function getActiveOffers() public view returns (Offer[] memory) {
        Offer[] memory activeOffers = new Offer[](activeOffersCount.current());

        uint256 j = 0;

        for (uint256 i = 0; i <= offersCount; i++) {
            if (block.timestamp < offers[i].deadline) {
                activeOffers[j] = offers[i];
                j++;
            }
        }

        return activeOffers;
    }
    function submitAnswer(uint256 offerNumber, string memory fileHash, string memory url) public payable{
        require(msg.value == offers[offerNumber].oracleLockValue, "Wrong lock value.");
        if(moreinfo[offerNumber].answersTypeCount == 0){
            moreinfo[offerNumber].answersTypeCount++;
            answerType storage answer = moreinfo[offerNumber].answers[moreinfo[offerNumber].answersTypeCount];
            answer.senders.push(msg.sender);
            answer.answersCount=1;
            answer.fileHash=fileHash;
            answer.fileUrl=url;
        }else{
            bool found=false;
            for (uint256 i = 0; i <=  moreinfo[offerNumber].answersTypeCount; i++) {
                string memory oldFileHash=moreinfo[offerNumber].answers[i].fileHash;
                if(keccak256(abi.encodePacked(oldFileHash)) == keccak256(abi.encodePacked(fileHash))){
                    answerType storage answer = moreinfo[offerNumber].answers[i];
                    answer.senders.push(msg.sender);
                    answer.answersCount++;
                    found=true;
                }
            }
            if(found == false){
            moreinfo[offerNumber].answersTypeCount++;
            answerType storage answer = moreinfo[offerNumber].answers[moreinfo[offerNumber].answersTypeCount];
            answer.senders.push(msg.sender);
            answer.answersCount=1;
            answer.fileHash=fileHash;
            answer.fileUrl=url;
            }

        }

    }
}