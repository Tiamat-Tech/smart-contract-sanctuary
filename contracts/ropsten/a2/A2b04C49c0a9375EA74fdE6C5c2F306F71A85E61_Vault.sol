// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "./interfaces/iERC20.sol";
import "./interfaces/iUTILS.sol";
import "./interfaces/iVADER.sol";
import "./interfaces/iROUTER.sol";
import "./interfaces/iPOOLS.sol";
import "./interfaces/iFACTORY.sol";
import "./interfaces/iSYNTH.sol";

contract Vault {
    bool private inited;
    uint256 public erasToEarn;
    uint256 public minGrantTime;
    uint256 public lastGranted;

    address public VADER;
    address public USDV;
    address public ROUTER;
    address public POOLS;
    address public FACTORY;

    uint256 public minimumDepositTime;
    uint256 public totalWeight;

    mapping(address => uint256) private mapMember_weight;
    mapping(address => mapping(address => uint256)) private mapMemberSynth_deposit;
    mapping(address => mapping(address => uint256)) private mapMemberSynth_lastTime;

    // Events
    event MemberDeposits(
        address indexed synth,
        address indexed member,
        uint256 amount,
        uint256 weight,
        uint256 totalWeight
    );
    event MemberWithdraws(
        address indexed synth,
        address indexed member,
        uint256 amount,
        uint256 weight,
        uint256 totalWeight
    );
    event MemberHarvests(
        address indexed synth,
        address indexed member,
        uint256 amount,
        uint256 weight,
        uint256 totalWeight
    );

    // Only DAO can execute
    modifier onlyDAO() {
        require(msg.sender == DAO(), "Not DAO");
        _;
    }

    constructor() {}

    function init(
        address _vader,
        address _usdv,
        address _router,
        address _factory,
        address _pool
    ) public {
        require(inited == false);
        inited = true;
        POOLS = _pool;
        VADER = _vader;
        USDV = _usdv;
        ROUTER = _router;
        FACTORY = _factory;
        POOLS = _pool;
        erasToEarn = 100;
        minimumDepositTime = 1;
        minGrantTime = 2592000; // 30 days
    }

    //=========================================DAO=========================================//
    // Can set params
    function setParams(
        uint256 newEra,
        uint256 newDepositTime,
        uint256 newGrantTime
    ) external onlyDAO {
        erasToEarn = newEra;
        minimumDepositTime = newDepositTime;
        minGrantTime = newGrantTime;
    }

    // Can issue grants
    function grant(address recipient, uint256 amount) public onlyDAO {
        require((block.timestamp - lastGranted) >= minGrantTime, "not too fast");
        lastGranted = block.timestamp;
        iERC20(USDV).transfer(recipient, amount);
    }

    //======================================DEPOSITS========================================//

    // Deposit USDV or SYNTHS
    function deposit(address synth, uint256 amount) external {
        depositForMember(synth, msg.sender, amount);
    }

    // Wrapper for contracts
    function depositForMember(
        address synth,
        address member,
        uint256 amount
    ) public {
        require((iFACTORY(FACTORY).isSynth(synth)), "Not Synth"); // Only Synths
        getFunds(synth, amount);
        _deposit(synth, member, amount);
    }

    function _deposit(
        address _synth,
        address _member,
        uint256 _amount
    ) internal {
        mapMemberSynth_lastTime[_member][_synth] = block.timestamp; // Time of deposit
        mapMemberSynth_deposit[_member][_synth] += _amount; // Record deposit
        uint256 _weight = iUTILS(UTILS()).calcValueInBase(iSYNTH(_synth).TOKEN(), _amount);
        if (iPOOLS(POOLS).isAnchor(iSYNTH(_synth).TOKEN())) {
            _weight = iROUTER(ROUTER).getUSDVAmount(_weight); // Price in USDV
        }
        mapMember_weight[_member] += _weight; // Total member weight
        totalWeight += _weight; // Total weight
        emit MemberDeposits(_synth, _member, _amount, _weight, totalWeight);
    }

    //====================================== HARVEST ========================================//

    // Harvest, get payment, allocate, increase weight
    function harvest(address synth) external returns (uint256 reward) {
        address _member = msg.sender;
        uint256 _weight;
        address _token = iSYNTH(synth).TOKEN();
        reward = calcCurrentReward(synth, _member); // In USDV
        mapMemberSynth_lastTime[_member][synth] = block.timestamp; // Reset time
        if (iPOOLS(POOLS).isAsset(_token)) {
            iERC20(USDV).transfer(POOLS, reward);
            reward = iPOOLS(POOLS).mintSynth(USDV, _token, address(this));
            _weight = iUTILS(UTILS()).calcValueInBase(_token, reward);
        } else {
            iERC20(VADER).transfer(POOLS, reward);
            reward = iPOOLS(POOLS).mintSynth(VADER, _token, address(this));
            _weight = iROUTER(ROUTER).getUSDVAmount(iUTILS(UTILS()).calcValueInBase(_token, reward));
        }
        mapMemberSynth_deposit[_member][synth] += reward;
        mapMember_weight[_member] += _weight;
        totalWeight += _weight;
        emit MemberHarvests(synth, _member, reward, _weight, totalWeight);
    }

    // Get the payment owed for a member
    function calcCurrentReward(address synth, address member) public view returns (uint256 reward) {
        uint256 _secondsSinceClaim = block.timestamp - mapMemberSynth_lastTime[member][synth]; // Get time since last claim
        uint256 _share = calcReward(synth, member); // Get share of rewards for member
        reward = (_share * _secondsSinceClaim) / iVADER(VADER).secondsPerEra(); // Get owed amount, based on per-day rates
        uint256 _reserve;
        if (iPOOLS(POOLS).isAsset(iSYNTH(synth).TOKEN())) {
            _reserve = reserveUSDV();
        } else {
            _reserve = reserveVADER();
        }
        if (reward >= _reserve) {
            reward = _reserve; // Send full reserve if the last
        }
    }

    function calcReward(address synth, address member) public view returns (uint256 reward) {
        uint256 _weight = mapMember_weight[member];
        if (iPOOLS(POOLS).isAsset(iSYNTH(synth).TOKEN())) {
            uint256 _adjustedReserve = iROUTER(ROUTER).getUSDVAmount(reserveVADER()) + reserveUSDV(); // Aggregrate reserves
            return iUTILS(UTILS()).calcShare(_weight, totalWeight, _adjustedReserve / erasToEarn); // Get member's share of that
        } else {
            uint256 _adjustedReserve = iROUTER(ROUTER).getUSDVAmount(reserveVADER()) + reserveUSDV();
            return iUTILS(UTILS()).calcShare(_weight, totalWeight, _adjustedReserve / erasToEarn);
        }
    }

    //====================================== WITHDRAW ========================================//

    // Members to withdraw
    function withdraw(address synth, uint256 basisPoints) external returns (uint256 redeemedAmount) {
        redeemedAmount = _processWithdraw(synth, msg.sender, basisPoints); // Get amount to withdraw
        sendFunds(synth, msg.sender, redeemedAmount);
    }

    function _processWithdraw(
        address _synth,
        address _member,
        uint256 _basisPoints
    ) internal returns (uint256 redeemedAmount) {
        require((block.timestamp - mapMemberSynth_lastTime[_member][_synth]) >= minimumDepositTime, "DepositTime"); // stops attacks
        redeemedAmount = iUTILS(UTILS()).calcPart(_basisPoints, mapMemberSynth_deposit[_member][_synth]); // Share of deposits
        mapMemberSynth_deposit[_member][_synth] -= redeemedAmount; // Reduce for member
        uint256 _weight = iUTILS(UTILS()).calcPart(_basisPoints, mapMember_weight[_member]); // Find recorded weight to reduce
        mapMember_weight[_member] -= _weight; // Reduce for member
        totalWeight -= _weight; // Reduce for total
        emit MemberWithdraws(_synth, _member, redeemedAmount, _weight, totalWeight); // Event
    }

    //============================== ASSETS ================================//

    function getFunds(address synth, uint256 amount) internal {
        if (tx.origin == msg.sender) {
            require(iERC20(synth).transferTo(address(this), amount));
        } else {
            require(iERC20(synth).transferFrom(msg.sender, address(this), amount));
        }
    }

    function sendFunds(
        address synth,
        address member,
        uint256 amount
    ) internal {
        require(iERC20(synth).transfer(member, amount));
    }

    //============================== HELPERS ================================//

    function reserveUSDV() public view returns (uint256) {
        return iERC20(USDV).balanceOf(address(this)); // Balance
    }

    function reserveVADER() public view returns (uint256) {
        return iERC20(VADER).balanceOf(address(this)); // Balance
    }

    function getMemberDeposit(address synth, address member) external view returns (uint256) {
        return mapMemberSynth_deposit[member][synth];
    }

    function getMemberWeight(address member) external view returns (uint256) {
        return mapMember_weight[member];
    }

    function getMemberLastTime(address synth, address member) external view returns (uint256) {
        return mapMemberSynth_lastTime[member][synth];
    }

    function DAO() public view returns (address) {
        return iVADER(VADER).DAO();
    }

    function UTILS() public view returns (address) {
        return iVADER(VADER).UTILS();
    }
}