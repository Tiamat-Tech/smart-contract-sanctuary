pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import './IOneSplit.sol';
import './BondingCurve.sol';
import './ETHPool.sol';
import './WBTCPool.sol';
import './YearnVault.sol';
// import './ETHStakingPool.sol';
// import './WBTCStakingPool.sol';

contract HegicTransactionBundler {
  using Address for address;
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // Addresses
  address payable public OWNER;

  address public HEGIC_ADDRESS = 0x584bC13c7D411c00c01A62e8019472dE68768430;
  address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
  address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

  address public RHEGIC_SWAP = 0x1F533aCf0C12D12997c49F4B64192030B6647c46;
  address public HEGIC_BONDING_CURVE_ADDRESS = 0x25B904ba7F17663f9005d34dB03c97171E4d4Cb7;
  address public ONE_SPLIT_ADDRESS = 0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E;
  address public ETH_POOL = 0x878F15ffC8b894A1BA7647c7176E4C01f74e140b;
  address public WBTC_POOL = 0x20DD9e22d22dd0a6ef74a520cb08303B5faD5dE7;
  address public ETH_STAKING_POOL = 0x8FcAEf0dBf40D36e5397aE1979c9075Bf34C180e;
  address public WBTC_STAKING_POOL = 0x493134A9eAbc8D2b5e08C5AB08e9D413fb4D1a55;
  address public YEARN_VAULT = 0xe11ba472F74869176652C35D30dB89854b5ae84D;

  // One OneSplit
  IOneSplit oneSplitContract = IOneSplit(ONE_SPLIT_ADDRESS);
  // Bonding Curve
  BondingCurve bondingCurveContract = BondingCurve(HEGIC_BONDING_CURVE_ADDRESS);
  // ETH Pool
  ETHPool ETHPoolContract = ETHPool(ETH_POOL);
  // WBTC Pool
  WBTCPool WBTCPoolContract = WBTCPool(WBTC_POOL);
  // Yearn Vault
  YearnVault YearnVaultContract = YearnVault(YEARN_VAULT);

  uint256 public LP_FEE = 10;
  uint256 public YEARN_FEE = 5;

  uint256 ONE_SPLIT_PARTS = 10;
  uint256 ONE_SPLIT_FLAGS = 0;
  uint256 FLAGS = 0;

  // Modifiers
  modifier onlyOwner() {
      require(msg.sender == OWNER, "caller is not the owner!");
      _;
  }

  fallback() external payable {}

  constructor() public payable {
      OWNER = msg.sender;
  }

  function getAmount(uint originalAmount, bool isLPFlow) internal returns(uint256){
    uint256 amount = isLPFlow ? LP_FEE * 10 ** 18 : YEARN_FEE * 10 ** 18;
    // get expected returnAmount
    (uint256 expectedHegic, uint256[] memory distribution) = oneSplitContract.getExpectedReturn(DAI_ADDRESS, HEGIC_ADDRESS, amount, ONE_SPLIT_PARTS, ONE_SPLIT_FLAGS);

    return originalAmount.add(expectedHegic);
  }

  function runLPFlow(bool isETH, bool isUni, bool isClaiming, uint amount) external {

    // claim hegic from rhegic -> hegic contract
    if(isClaiming){
      RHEGIC_SWAP.functionDelegateCall(abi.encodeWithSignature("withdraw()"));
    }

    // add fee for this flow
    uint256 amountToTransfer = getAmount(amount, true);
    require(IERC20(HEGIC_ADDRESS).balanceOf(msg.sender) >= amountToTransfer);

    IERC20(HEGIC_ADDRESS).safeTransferFrom(msg.sender, address(this), amountToTransfer);

    uint256 beforeBalance = isETH ? address(this).balance : IERC20(WBTC_ADDRESS).balanceOf(address(this));

    if(isUni){
      // get expected returnAmount
      (uint256 expectedETH, uint256[] memory distribution) = oneSplitContract.getExpectedReturn(HEGIC_ADDRESS, isETH ? ETH_ADDRESS : WBTC_ADDRESS, amount, ONE_SPLIT_PARTS, ONE_SPLIT_FLAGS);

      //_oneSplitSwap()
      _oneSplitSwap(HEGIC_ADDRESS, isETH ? ETH_ADDRESS : WBTC_ADDRESS, amount, expectedETH, distribution, FLAGS);

    } else {
      bondingCurveContract.sell(amount);
    }

    uint256 afterBalance = isETH ? address(this).balance : IERC20(WBTC_ADDRESS).balanceOf(address(this));

    if(isETH){
      // get writeETH before/after providing to pool
      uint256 writeETHBefore = IERC20(ETH_POOL).balanceOf(address(this));
      ETHPoolContract.provide{value: afterBalance - beforeBalance}(0);
      uint256 writeETHAfter = IERC20(ETH_POOL).balanceOf(address(this));

      // transfer to homie
      IERC20(ETH_POOL).safeTransfer(msg.sender, writeETHAfter - writeETHBefore);

      //stake it for him
      ETH_STAKING_POOL.functionDelegateCall(abi.encodeWithSignature("stake()"));
    }else{
      // get writeWBTC before/after providing to pool
      uint256 writeWBTCBefore = IERC20(WBTC_POOL).balanceOf(address(this));
      WBTCPoolContract.provide(afterBalance - beforeBalance, 0);
      uint256 writeWBTCAfter = IERC20(WBTC_POOL).balanceOf(address(this));

      // transfer to homie
      IERC20(WBTC_POOL).safeTransfer(msg.sender, writeWBTCAfter - writeWBTCBefore);

      //stake it for him
      WBTC_STAKING_POOL.functionDelegateCall(abi.encodeWithSignature("stake()"));
    }
  }

  function runHegicYearnVaultFlow(bool isClaiming, uint amount) external {
    // claim hegic from rhegic -> hegic contract
    if(isClaiming){
      RHEGIC_SWAP.functionDelegateCall(abi.encodeWithSignature("withdraw()"));
    }

    // add fee for this flow
    uint256 amountToTransfer = getAmount(amount, false);
    require(IERC20(HEGIC_ADDRESS).balanceOf(msg.sender) >= amountToTransfer);

    // transfer to contract
    IERC20(HEGIC_ADDRESS).safeTransferFrom(msg.sender, address(this), amountToTransfer);

    // approve vault with amount
    IERC20(HEGIC_ADDRESS).approve(YEARN_VAULT, amount);

    //deposit
    YearnVaultContract.deposit(amount, msg.sender);
  }

  function _oneSplitSwap(address _from, address _to, uint256 _amount, uint256 _minReturn, uint256[] memory _distribution, uint256 _flags) internal {
      // Approve tokens
      IERC20(_from).approve(ONE_SPLIT_ADDRESS, _amount);

      // Swap tokens: give _from, get _to
      oneSplitContract.swap(_from, _to, _amount, _minReturn, _distribution, _flags);

      // Reset approval
      IERC20(_from).approve(ONE_SPLIT_ADDRESS, 0);
  }

  function updateTokenSwapSC(address _newAddress) external onlyOwner {
    RHEGIC_SWAP = _newAddress;
  }

  function updateETHStakingSC(address _newAddress) external onlyOwner {
    ETH_STAKING_POOL = _newAddress;
  }

  function updateWBTCStakingSC(address _newAddress) external onlyOwner {
    WBTC_STAKING_POOL = _newAddress;
  }

  function updateYearnVaultSC(address _newAddress) external onlyOwner {
    YEARN_VAULT = _newAddress;
  }

  function setLPFee(uint256 _fee) external onlyOwner {
    LP_FEE = _fee;
  }

  function setYearnFee(uint256 _fee) external onlyOwner {
    YEARN_FEE = _fee;
  }

  // KEEP THIS FUNCTION IN CASE THE CONTRACT RECEIVES TOKENS!
  function withdrawToken(address _tokenAddress) public onlyOwner {
      uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
      IERC20(_tokenAddress).safeTransfer(OWNER, balance);
  }

  // KEEP THIS FUNCTION IN CASE THE CONTRACT KEEPS LEFTOVER ETHER!
  function withdrawEther() public onlyOwner {
      address self = address(this); // workaround for a possible solidity bug
      uint256 balance = self.balance;
      OWNER.transfer(balance);
  }
}