pragma solidity ^0.8.0;
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './StakingContract.sol';
import './LiquidityContract.sol';
import './Mindpay.sol';

contract ReserveContract{
    using SafeMath for uint256;
    using Address for address;

    struct Investments{
        uint256 id;
        uint256 etherAmount;
        uint256 correspondingTokenAmount;
        address investor;
        uint256 lockedPeriod;
        bool cancelled;
        bool staked;
    }
    mapping(uint256 => Investments) public investment;
    mapping(address => uint256[]) investmentIDsOf;
    mapping(address => uint256) public reserveTokenBalanceOf;
    mapping(address => uint256) public reserveEtherBalanceOf;
    mapping(address => uint256) public stakedTokenBalanceOf;

    uint256 public lockPeriod = 15 minutes;
    uint256 nextInvestmentId;
    uint256 constant denominator = 1000;
    address admin;
    StakingContract stakingContract;
    Mindpay mindpayToken;
    LiquidityContract liquidityContract;
    constructor(
        address payable _stakingContract, 
        address _mindpayToken, 
        address payable _liquidityContract)
        {
            admin =  msg.sender;
            stakingContract = StakingContract(_stakingContract);
            mindpayToken = Mindpay(_mindpayToken);
            liquidityContract = LiquidityContract(_liquidityContract);
        }
        receive() external payable{
        (bool sent, ) = address(liquidityContract)
                        .call{value: (msg.value.mul(100)).div(denominator)}("");
        require(sent, "Error: Liquidity contract");
        invest(msg.sender,msg.value);
    }

    function mint(address depositer, uint256 etherValue) internal{
        mindpayToken.mint(address(this), tokensToMint(etherValue));
        reserveTokenBalanceOf[depositer] = reserveTokenBalanceOf[depositer].add(tokensToMint(etherValue));
    }

    function tokensToMint(uint256 etherValue) internal pure returns(uint){
        if(etherValue <= 1 ether){
            return etherValue.mul(1000);
        }
        else if(etherValue>1 ether && etherValue <= 5 ether){
            return etherValue.mul(1100);
        }
        return etherValue.mul(1200);
    }

    function invest(address investor, uint256 etherValue) internal{
        investment[nextInvestmentId] = Investments(
                nextInvestmentId,
                (etherValue.mul(900)).div(denominator),
                tokensToMint(etherValue),
                investor,
                block.timestamp + lockPeriod,
                false,
                false
            );
        investmentIDsOf[investor].push(nextInvestmentId);

        reserveEtherBalanceOf[investor] = 
            reserveEtherBalanceOf[investor].add((etherValue.mul(900))
                                            .div(denominator));
        mint(investor, etherValue);
        nextInvestmentId = nextInvestmentId.add(1);        
    }

    function cancelInvestment(uint256 id) external isUnlocked(id){
        require(investment[id].investor == msg.sender, "This is not your investment");
        require(investment[id].cancelled == false, "Investment already cancelled");
        require(investment[id].staked == false, "Investment already staked");
        investment[id].cancelled = true;
        uint256 etherToReturn = investment[id].etherAmount;
        reserveEtherBalanceOf[msg.sender] = reserveEtherBalanceOf[msg.sender].sub(etherToReturn);
        reserveTokenBalanceOf[msg.sender] = reserveTokenBalanceOf[msg.sender]
                                    .sub(investment[id].correspondingTokenAmount);

        mindpayToken.burn(address(this), investment[id].correspondingTokenAmount);
        
        payable(msg.sender).transfer(etherToReturn);
    }   

    function stakeInvestment(uint id) external isUnlocked(id){
        require(investment[id].investor == msg.sender, "This is not your investment");
        require(investment[id].staked == false, "Investment already staked");
        require(investment[id].cancelled == false, "Investment already cancelled");
        
        investment[id].staked = true;
        uint256 etherAmount = investment[id].etherAmount;
        uint256 tokenAmount = investment[id].correspondingTokenAmount;
        
        reserveEtherBalanceOf[msg.sender] = 
                        reserveEtherBalanceOf[msg.sender].sub(etherAmount);
        reserveTokenBalanceOf[msg.sender] = 
                                    reserveTokenBalanceOf[msg.sender]
                                    .sub(tokenAmount);
        
        (bool sent, ) = address(liquidityContract).call{value: etherAmount}("");
        require(sent, "Error: Staking investment");
        mindpayToken.approve(address(stakingContract), tokenAmount);
        stakingContract.depositToken(investment[id].investor, tokenAmount);

        stakedTokenBalanceOf[msg.sender] = 
            stakedTokenBalanceOf[msg.sender].add(tokenAmount);
        
    }

    function withdrawFromStake(uint256 id) external {
        require(investment[id].investor == msg.sender, "Not your investment");
        require(investment[id].staked == true, "Not staked");
        _withdrawFromStake(msg.sender, id);
    }

    function _withdrawFromStake(address investor, uint256 id) private{
        stakedTokenBalanceOf[investor] = stakedTokenBalanceOf[investor]
                                        .sub(investment[id].correspondingTokenAmount);
        stakingContract.withdraw(investor, investment[id].correspondingTokenAmount);
    }


    function addressOfStakingContract() public view returns(address){
        return address(stakingContract);
    }

    function addressOfLiquidityContract() public view returns(address){
        return address(liquidityContract);
    }

    function addressOfMindpayToken() public view returns(address){
        return address(mindpayToken);
    }

    function timeToUnlock(uint256 id) public view returns(uint256){
        if(block.timestamp < investment[id].lockedPeriod){
            return (investment[id].lockedPeriod).sub(block.timestamp);
        }
        return 0;
    }

    function investmentsOf(address investor) public view returns(uint256[] memory){
        return investmentIDsOf[investor];
    }

    function changeAdmin(address _admin) external{
        require(msg.sender == admin, "Only admin");
        admin = _admin;
    }

    function changeLockPeriod(uint256 newPeriod) external{
        require(msg.sender == admin, "Only admin");
        lockPeriod = newPeriod;
    }


    modifier isUnlocked(uint256 investmentId){
        require(
            block.timestamp > investment[investmentId].lockedPeriod, 
            "Funds locked"
            );
        _;
    }
}