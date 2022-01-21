// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Contribution is Ownable {
    struct ContributionEvent {
        uint256 id;
        uint256 minETH;
        uint256 maxETH;
        bool isOpen;
        uint256 hardCap;
        uint256 availableETH;
    }

    uint256 public nextContributionEventId;
    uint256 public currentContributionEventId;

    mapping(uint256 => ContributionEvent) private events; // eventId => event
    mapping(uint256 => mapping(address => uint256)) private contributions; // eventId => (address => amount)

    event ContributionEventCreated(
        uint256 id,
        uint256 minETH,
        uint256 maxETH,
        bool isOpen,
        uint256 hardCap,
        uint256 availableETH
    );
    event Contributed(
        uint256 contributionEventId,
        address contributor,
        uint256 amount
    );
    event CurrentContributionEventSet(uint256 contributionEventId);
    event ContributionEventVisibilityChanged(
        uint256 contributionEventId,
        bool isOpen
    );

    function setCurrentContributionEvent(uint256 _id) public onlyOwner {
        require(_id > 0 && _id <= nextContributionEventId, "E005");
        currentContributionEventId = _id;
        emit CurrentContributionEventSet(currentContributionEventId);
    }

    function setContributionEventIsOpen(uint256 _id, bool _isOpen)
        public
        onlyOwner
    {
        require(_id > 0 && _id <= nextContributionEventId, "E005");
        events[_id].isOpen = _isOpen;
        emit ContributionEventVisibilityChanged(_id, _isOpen);
    }

    function getContributionEvent(uint256 _id)
        public
        view
        returns (
            uint256,
            uint256,
            bool,
            uint256,
            uint256
        )
    {
        require(_id > 0 && _id <= nextContributionEventId, "E005");
        return (
            events[_id].minETH,
            events[_id].maxETH,
            events[_id].isOpen,
            events[_id].hardCap,
            events[_id].availableETH
        );
    }

    function getContribution(uint256 _eventId, address _contributor)
        public
        view
        returns (uint256)
    {
        require(_eventId > 0 && _eventId <= nextContributionEventId, "E005");
        return contributions[_eventId][_contributor];
    }

    function createContributionEvent(
        uint256 _minETH,
        uint256 _maxETH,
        uint256 _hardcap
    ) public onlyOwner {
        require(_minETH > 0, "E006");
        require(_maxETH > 0, "E007");
        require(_minETH <= _maxETH, "E008");
        require(_hardcap > 0, "E010");
        uint256 id = ++nextContributionEventId;
        events[id] = ContributionEvent({
            id: id,
            minETH: _minETH,
            maxETH: _maxETH,
            isOpen: false,
            hardCap: _hardcap,
            availableETH: _hardcap
        });

        emit ContributionEventCreated(
            id,
            _minETH,
            _maxETH,
            false,
            _hardcap,
            _hardcap
        );
    }

    function contribute(uint256 ethValue, address _contributor) private {
        require(events[currentContributionEventId].isOpen, "E009");
        require(
            contributions[currentContributionEventId][_contributor] == 0,
            "E003"
        );
        require(ethValue >= events[currentContributionEventId].minETH, "E001");
        require(ethValue <= events[currentContributionEventId].maxETH, "E002");
        require(
            events[currentContributionEventId].availableETH >= ethValue,
            "E004"
        );
        events[currentContributionEventId].availableETH -= ethValue;
        contributions[currentContributionEventId][_contributor] = ethValue;

        emit Contributed(currentContributionEventId, _contributor, ethValue);
    }

    receive() external payable {
        contribute(msg.value, msg.sender);
    }

    function withdrawAllETH() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawTokens(address _tokenAddress) public {
        IERC20 tokenContract = IERC20(_tokenAddress);
        tokenContract.transfer(
            msg.sender,
            tokenContract.balanceOf(address(this))
        );
    }
}

// Error Codes
// E001: Contribution is below minimum
// E002: Contribution is above maximum
// E003: Contribution already made
// E004: Contribution is above available ETH
// E005: Contribution event id must be between 1 and nextContributionEventId
// E006: minETH must be greater than 0
// E007: maxETH must be greater than 0
// E008: minETH must be less than or equal to maxETH
// E009: Contribution event is closed
// E010: hardCap must be greater than 0