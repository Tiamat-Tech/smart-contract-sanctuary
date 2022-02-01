pragma solidity 0.7.6;

import "./IMinterUpgradeableFPaymentSplitter.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract SplitPayments is Initializable {

    IMinterUpgradeableFPaymentSplitter minter;

    constructor() public {
    }

    function setMinterContract(address minterAddress) external initializer {
        minter = IMinterUpgradeableFPaymentSplitter(minterAddress);
    }

    receive() external payable {
        minter.recieveRoyaltyStake{value: address(this).balance}();
    }
    fallback() external payable {
        minter.recieveRoyaltyStake{value: address(this).balance}();
    }
}