/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HugzToken.sol";

contract HugzDeployer {
    uint256 public TOTAL_SUPPLY = 1000000000000000 * 10**6;
    uint256 public marketingAllocation = TOTAL_SUPPLY / 20;
    uint256 public founderAllocation = TOTAL_SUPPLY / 20;
    uint256 public airdropAllocation = TOTAL_SUPPLY / 10;
    uint256 public liquidityAllocation = TOTAL_SUPPLY / 2;
    uint256 public presaleAllocation = 75000000000000 * 10**6;

    uint256 burnAmount = ((TOTAL_SUPPLY * 3) / 10);

    event Transfer(address indexed _from, address indexed _id, uint256 _value); // Byte32 _id???

    address public _token;
    HugzToken public HugzTokenRef;

    constructor(address _MarketingWallet, address _FounderTimelockContract, address _PresaleContract) {
        HugzToken HugzTokenInstance = new HugzToken();
        HugzTokenRef = HugzTokenInstance;
        _token = HugzTokenInstance.getHugzAddress();

        HugzTokenInstance.setExcludedFromFee(msg.sender, true);
        HugzTokenInstance.setExcludedFromFee(_MarketingWallet, true);
        HugzTokenInstance.setExcludedFromFee(_FounderTimelockContract, true);
        HugzTokenInstance.setExcludedFromFee(_PresaleContract, true);
        HugzTokenInstance.setPresaleContact(_PresaleContract);


        // Burn tokens - 30%
        HugzTokenInstance.burn(burnAmount);

        // Transfer to marketing wallet - 5%
        HugzTokenInstance.transfer(_MarketingWallet, marketingAllocation);

        // Transfer to founder timelock contract - 5%
        HugzTokenInstance.transfer(_FounderTimelockContract, founderAllocation);

//         Transfer to presale contract - 7.5%
        HugzTokenInstance.transfer(
            _PresaleContract,
            presaleAllocation
        );
        //         Transfer to liquidity contract - 50%
    HugzTokenInstance.transfer(
        _PresaleContract,
                    liquidityAllocation
                );

        // Transfer to pubco wallet

    }

    /* Testing Functions */
    function getHugzAddress() external view returns (address) {
        return _token;
    }

    function getHugzBalance(address _holder) external view returns (uint256) {
        IERC20 token = IERC20(_token);
        return token.balanceOf(_holder);
    }

    function transferHugz(address _recipient, uint256 _amount) external {
        HugzTokenRef.transferFrom(msg.sender, _recipient, _amount);
        emit Transfer(msg.sender, _recipient, _amount);
    }

    function getHugzRef() external view returns (HugzToken) {
        return HugzTokenRef;
    }
}