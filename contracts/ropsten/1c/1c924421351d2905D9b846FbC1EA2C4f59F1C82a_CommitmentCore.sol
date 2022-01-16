//SPDX-L cense-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Commitment.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CommitmentCore is KeeperCompatibleInterface {
	using EnumerableMap for EnumerableMap.UintToAddressMap;
	using SafeMath for uint;
	
	event CommitmentContractCreated(address indexed owner, address contractAddress, uint64 date, address recipient);

	EnumerableMap.UintToAddressMap private eoaToContractAddressCommitments;

	modifier validateParams(uint64 date, address payable recipient, uint amountToSave) {
		require(recipient != address(0), "Come on now, we don't want to see your ETH burned. Recipient is set to the zero address");
		require(recipient != msg.sender, "What's the point, you'll never actually have a financial commitment if the money goes to you.");
		require(eoaToContractAddressCommitments.contains(convertToUint(msg.sender)) == false, "You already have a commitment. One at a time...for now");
    _;
	}
	
	function newCommitment(uint64 date, address payable recipient, uint amountToSave) validateParams(date, recipient, amountToSave) external payable {
			Commitment commitmentContract = new Commitment{value: msg.value}(date, recipient, msg.sender, amountToSave); 
			address commitmentAddress = address(commitmentContract);
			eoaToContractAddressCommitments.set(convertToUint(msg.sender), commitmentAddress);
			emit CommitmentContractCreated(msg.sender, commitmentAddress, date, recipient);
	}	
	
	function checkUpkeep(bytes calldata checkdata) external override view returns (bool, bytes memory) {
		bool upKeep = false;
		address[50] memory payableAddresses;
		uint[50] memory amountsStaked;
		address[50] memory contracts;
		uint[50] memory ownerFees;	
		uint8 count = 0;
		for (uint i = 0; i < eoaToContractAddressCommitments.length(); i++) {
			(uint256 committer, address contractAddress) = eoaToContractAddressCommitments.at(i);			
			Commitment commitment = Commitment(contractAddress);
		    if (commitment.isTimeToEvaluate()) {
				if (commitment.didAccomplishGoal()) {
					payableAddresses[count] = address(uint160(committer));
					amountsStaked[count] = contractAddress.balance;
				} else {
					payableAddresses[count] = commitment.getRecipient();
					(uint recipientAmount, uint ownerAmount) = calculateOwnerSplit(contractAddress);
					amountsStaked[count] = recipientAmount;
					ownerFees[count] = ownerAmount;
			}
			contracts[count] = contractAddress;
			upKeep = true;
			++count;	
		}
				
		}			
	// Increase the performacne and reduce the pay here by trimming the arrays before sending them over the net
	//	for (uint8 i = 0; i < payableAddresses.length; i++) {
//			if (payableAddresses[i] == address(0)) {
//				break;
//			}
//			trimmedPay
//}	
		return (upKeep, abi.encode(payableAddresses, amountsStaked, contracts, ownerFees));
	}


	function performUpkeep(bytes calldata performData) external override {

		(address[50] memory payableAddresses, uint[50] memory amountsStaked, address[50] memory contracts, uint[50] memory ownerFees) = abi.decode(performData, (address[50], uint[50], address[50], uint[50]));	

		for (uint8 i = 0; i < payableAddresses.length; i++) {
			if (payableAddresses[i] == address(0)) {
				break;
			}	

    Commitment(contracts[i]).executePayout(payable(payableAddresses[i]), amountsStaked[i]); 
		if (ownerFees[i] > 0) {
			Commitment(contracts[i]).executePayout(payable(0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199), ownerFees[i]);
		}
		}
	}
	
	function getCommitment(address committer) external view returns (address) {
		return eoaToContractAddressCommitments.get(convertToUint(committer));	
	}

	function convertToUint(address addr) private pure returns (uint) {
		return uint256(uint160(addr));	
	}

	 function calculateOwnerSplit(address contractAddress) private view returns (uint, uint) {
		uint balance = contractAddress.balance;
		uint ownerAmount = balance.mul(375).div(10000);
		return (balance.sub(ownerAmount), ownerAmount);
	 }

	receive() external payable {}
}