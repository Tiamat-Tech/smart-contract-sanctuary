pragma solidity ^0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Smart contract for the Mad River Trial project by creaticles
 * @notice This contract allows for the funding/voting to the platform using test ETH
 * @author maikir
 */

contract PayToVote is
    Ownable
{
    // Sale toggle
    bool public votingActive;

    //Track addresses that have funded the contract
    mapping (address => uint256) public votedIndexMap;

    struct VoteStruct {
        address voterAddress;
        uint256 voterFunds;
    }

    VoteStruct[] votesArray;

    event VoteWithFunds(address indexed _sender, uint256 _value);

    constructor() public {
      votingActive = true;
   }

    // @dev Allows to enable/disable voting/contributing funds
    function flipSaleState() external onlyOwner {
        votingActive = !votingActive;
    }

    function voteWithFunds() external payable {
        require(votingActive, "Voting must be active");
        if (votedIndexMap[msg.sender] == 0) {
            VoteStruct memory vote = VoteStruct(msg.sender, msg.value);
            votesArray.push(vote);
            votedIndexMap[msg.sender] = votesArray.length;
        } else {
            uint256 arrayIndex = votedIndexMap[msg.sender];
            votesArray[arrayIndex-1].voterFunds += msg.value;
        }
        emit VoteWithFunds(msg.sender, msg.value);
    }

    function getVotesArray() external view returns( VoteStruct[] memory){
        return votesArray;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}