// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "./libs/SafeMath.sol";
import "./libs/Ownable.sol";

interface ISponsoredContract {
    function getUserLendingState(bytes32 _lendingId)
        external
        view
        returns (uint256);
}

contract LiquidateSponsor is Ownable {
    enum LendingInfoState {
        NONE,
        WAITTING,
        CLOSED
    }

    struct LendingInfo {
        address user;
        uint256 expendGas;
        uint256 amount;
        LendingInfoState state;
    }

    bool public isPaused;
    address public liquidateSponsor;
    address public sponsoredContract;
    uint256 public totalSupply;
    uint256 public totalRequest;
    uint256 public sponsorAmount = 0.1 ether;

    mapping(bytes32 => LendingInfo) public lendingInfos;

    event SponsoredContribution(bytes32 sponsor, uint256 amount);
    event RequestSponsor(bytes32 sponsor, uint256 amount);
    event PayFee(
        bytes32 sponsor,
        address user,
        uint256 sponsorAmount,
        uint256 expendGas
    );

    modifier onlySponsor() {
        require(
            msg.sender == liquidateSponsor,
            "LiquidateSponsor: not a sponsor"
        );
        _;
    }

    constructor() public {
        liquidateSponsor = msg.sender;
    }

    function setSponsoredContract(address _s) external onlySponsor {
        sponsoredContract = _s;
    }

    function payFee(
        bytes32 _lendingId,
        address _user,
        uint256 _expendGas
    ) public {
        if (msg.sender == sponsoredContract && isPaused == false) {
            if (address(this).balance < sponsorAmount) {
                return;
            }

            LendingInfo storage lendingInfo = lendingInfos[_lendingId];

            if (
                lendingInfo.state == LendingInfoState.NONE ||
                lendingInfo.state == LendingInfoState.WAITTING
            ) {
                lendingInfo.expendGas = _expendGas;
                lendingInfo.state = LendingInfoState.CLOSED;

                payable(_user).transfer(sponsorAmount);

                emit PayFee(_lendingId, _user, sponsorAmount, _expendGas);
            }
        }
    }

    function addSponsor(bytes32 _lendingId, address _user) public payable {
        if (msg.sender == sponsoredContract && isPaused == false) {
            lendingInfos[_lendingId] = LendingInfo({
                user: _user,
                amount: msg.value,
                expendGas: 0,
                state: LendingInfoState.NONE
            });

            totalSupply += msg.value;
            totalRequest++;

            emit SponsoredContribution(_lendingId, msg.value);
        }
    }

    function requestSponsor(bytes32 _lendingId) public {
        if (msg.sender == sponsoredContract && isPaused == false) {
            LendingInfo storage lendingInfo = lendingInfos[_lendingId];

            if (address(this).balance < sponsorAmount) {
                lendingInfo.state = LendingInfoState.WAITTING;
                return;
            }

            if (
                lendingInfo.state == LendingInfoState.NONE ||
                lendingInfo.state == LendingInfoState.WAITTING
            ) {
                lendingInfo.state = LendingInfoState.CLOSED;

                payable(lendingInfo.user).transfer(lendingInfo.amount);

                totalRequest--;
            }

            emit RequestSponsor(_lendingId, lendingInfo.amount);
        }
    }

    // function manualSponsor(bytes32 _lendingId) public {
    //     if (isPaused == false) {
    //         LendingInfo storage lendingInfo = lendingInfos[_lendingId];

    //         require(msg.sender == lendingInfo.user, "!user");

    //         uint256 state = ISponsoredContract(sponsoredContract)
    //             .getUserLendingState(_lendingId);

    //         require(state == 1, "!state");

    //         if (address(this).balance < sponsorAmount) {
    //             lendingInfo.state = LendingInfoState.WAITTING;
    //             return;
    //         }

    //         if (
    //             lendingInfo.state == LendingInfoState.NONE ||
    //             lendingInfo.state == LendingInfoState.WAITTING
    //         ) {
    //             lendingInfo.state = LendingInfoState.CLOSED;

    //             payable(lendingInfo.user).transfer(lendingInfo.amount);

    //             totalRequest--;
    //         }
    //     }
    // }

    function refund() public onlyOwner {
        require(totalRequest == 0, "!totalRequest");
        require(address(this).balance > 0, "!balance");

        payable(owner()).transfer(address(this).balance);
    }

    function pause() external onlySponsor {
        isPaused = true;
    }

    function resume() external onlySponsor {
        isPaused = false;
    }
}