// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./RewardToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Distribution is Ownable {
    using SafeERC20 for RewardToken;
    using SafeMath for uint256;

    enum State{deposited, distributed, removed}

    struct BeneficiaryInfo {
        address beneficiary; 
        uint256 amountToken; 
        bool alreadyPaid;
    }

    RewardToken public token;
    bool private isLocked = true;

    mapping(address => BeneficiaryInfo) public beneficiaries;

    event Deposit(address indexed from, address indexed to, uint256 amount, State state);
    event DecreaseReward(address indexed who, uint256 amount, State state);
    event TransferReward(address indexed who, uint256 amount, State state);
    event EmergencyWithdraw(address indexed to, uint256 amount, State state);

    constructor(
        address _token
    ) {
        require(
            _token != address(0),
             "Token Address is not Zero"
        );
        token = RewardToken(_token);
    }

    modifier checkForZero(address _beneficiaries, uint256 _amount) {
        require(
            _beneficiaries != address(0),
            "Address of Beneficiaries cannot be zero"
        );
        require(
            _amount != 0, 
            "Balances of Beneficiaries cannot be zero"
        );
        _;
    }

    modifier whenNotLocked() {
        require(
            !isLocked,
            "Not allowed - locked"
        );
        _;
    }

    // Should transfer tokens from owner to distribution contract
    function deposit(
        uint256 _amount
    ) public onlyOwner {
        require(
            _amount != 0, 
            "Amount cannot be zero"
        );
        token.safeTransferFrom(owner(), address(this), _amount);
        emit Deposit(owner(), address(this), _amount, State.deposited);
    }

    // Should add beneficiary with tokens amount for each beneficiary from owner
    function addBeneficiaries(
        address[] memory _beneficiaries,
        uint256[] memory _amount
    ) public onlyOwner {
        require(_beneficiaries.length == _amount.length, "Length of arrays is invalid");
        for(uint i; i < _beneficiaries.length; i++) {
            require(
                address(_beneficiaries[i]) != address(0),
                "Address of Beneficiaries cannot be zero"
            );
        }
        for(uint i; i < _amount.length; i++) {

            require(
                _amount[i] != 0,
                "Balances of Beneficiaries cannot be zero"
            );
        }
        BeneficiaryInfo storage beneficiaryInfo;
        for(uint i; i < _beneficiaries.length; i++) {
            beneficiaryInfo = beneficiaries[_beneficiaries[i]];
            beneficiaryInfo.beneficiary = _beneficiaries[i];
            beneficiaryInfo.amountToken = _amount[i];
            beneficiaryInfo.alreadyPaid = false;
            beneficiaries[_beneficiaries[i]] = beneficiaryInfo;
        }
    }

    // Should add beneficiary with tokens amount from owner
    function addBeneficiary(
        address _beneficiary,
        uint256 _amount
    ) public checkForZero(_beneficiary, _amount) onlyOwner {
        BeneficiaryInfo storage beneficiaryInfo = beneficiaries[_beneficiary];
        beneficiaryInfo.beneficiary = _beneficiary;
        beneficiaryInfo.amountToken = _amount;
        beneficiaryInfo.alreadyPaid = false;
        beneficiaries[_beneficiary] = beneficiaryInfo;
    }

    // Should decrease amount of rewards for benefeciary
    function decreaseReward(
        address _beneficiary, 
        uint256 _amount
    ) public checkForZero(_beneficiary, _amount) onlyOwner {
        beneficiaries[_beneficiary].amountToken -= _amount;
        emit DecreaseReward(_beneficiary, _amount, State.removed);
    }
    
    // Should transfer amout of reward tokens back to the owner
    function emergencyWithdraw(uint256 _amount) 
        public onlyOwner {
        require(
            _amount != 0, 
            "Amount cannot be zero"
        );
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient tokens balance"
        );
        token.safeTransfer(owner(), _amount);
        emit EmergencyWithdraw(owner(), _amount, State.removed);
    }

    // Should transfer reward tokens to beneficiary
    function claim() whenNotLocked public {
        require(!beneficiaries[msg.sender].alreadyPaid, "Amount is paid");
        uint256 amountToken = beneficiaries[msg.sender].amountToken;
        token.safeTransfer(msg.sender, amountToken);
        beneficiaries[msg.sender].alreadyPaid = true;
        emit TransferReward(msg.sender, amountToken, State.distributed);
    }

    // Should lock/unlock rewards for beneficiary
    function lockRewards(bool _lock) public onlyOwner {
        isLocked = _lock;
    }

}