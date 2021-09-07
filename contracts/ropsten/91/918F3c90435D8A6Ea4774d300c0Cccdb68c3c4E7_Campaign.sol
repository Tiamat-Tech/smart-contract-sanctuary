pragma solidity 0.7.6;
pragma abicoder v2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@eth-optimism/contracts/iOVM/bridge/tokens/iOVM_L1StandardBridge.sol";
//import "./4_SimpleNFT.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {UniswapV2Library} from "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

// SPDX-License-Identifier: MIT
interface IWETH {
     function deposit() external payable;
     function transfer(address to, uint value) external returns (bool);
     function withdraw(uint) external;
 }
contract Campaign {
    
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    
    uint256 constant MAX_UINT = 2 ** 256 - 1;
    
    uint public id;
    string public name;
    uint public currFund;
    uint public goal;
    address payable public owner;
    bool public finished = false;
    string public description;
    string[] public mails;
    uint public mailCount;
    address public wantToken;
    uint public endTimeStamp;
    mapping(address => bool) donators;
    //SimpleNFT public nfts;
    string public URI;
    address public wantTokenL2;
    
    address public v3factory=0x1F98431c8aD98523631AE4a59f267346ea31F984;
    address public v3router=0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public WETH=0xd0A1E359811322d97991E03f863a0C30C2cF029C;
    mapping(address => bool) private routerApprovedTokens;
    address public L2;
    address public L1StandardBridge = 0x22F24361D548e5FaAfb36d1437839f080363982B;
    uint24 public constant poolFee = 3000;

    constructor(uint _id, string memory _name, uint _goal, string memory _description, uint _endTimeStamp, address _wantToken, string memory _uri, address _l2Address, address _wantTokenL2, address payable _beneficiary){
        id = _id;
        name = _name;
        currFund = 0;
        goal = _goal;
        description = _description;
        owner = _beneficiary;
        endTimeStamp = _endTimeStamp;
        wantToken = _wantToken;
        URI = _uri;
        L2 = _l2Address;
        wantTokenL2 = _wantTokenL2;
    }
    event GoalReached(uint totalFund, uint goal, uint campaignId, string name, string[] mails);
    event Donated(uint amount, uint campaignId, string name, string mail, address donorToken);
    
    function donateTokens(string memory _mail, address _donorToken, uint256 _finalDonationAmount) private {
        IERC20(_donorToken).transferFrom(
                msg.sender,
                address(this),
                _finalDonationAmount
            );
            
        currFund += _finalDonationAmount;
        mails.push(_mail);
        mailCount++;

        if (currFund == goal) {
            emit GoalReached(currFund, goal, id, name, mails);
            finished = true;
            withdraw();
        }
            
        emit Donated(msg.value, id, name, _mail, _donorToken);
        if (donators[msg.sender] == false){
                //nfts.createSimpleNFT(_uri);
            donators[msg.sender] = true;
        }
        if (L2 != address(0)){
            uint256 _amount = IERC20(_donorToken).balanceOf(address(this));
            iOVM_L1StandardBridge(L1StandardBridge).depositERC20To(wantToken, wantTokenL2, L2, _amount, 2000000, "0x");
        }
        return;
    }
    
    function donate(string memory _mail, address _donorToken, uint256 _amountIn) public payable returns(bool sufficient) {

        require(IERC20(_donorToken).balanceOf(msg.sender) >= _amountIn, "Campaign::donate: Insuficient funds");
        require(endTimeStamp > block.timestamp, "Campaign::donate: This campaign has already finished");
        //require(currFund + _amountIn <= goal, "Campaign::donate: Hard cap reached");
        require(_donorToken != address(0), "SupportChildren::donate: donorToken == 0x, use donateETH instead");
        
        bool isCampaignInETH = wantToken == address(0);
        uint256 _finalDonationAmount = 0;

        if (!isCampaignInETH && wantToken == _donorToken) {
            _finalDonationAmount = getMaxDonationAmount(_amountIn);
            donateTokens(_mail, _donorToken, _finalDonationAmount);
            return true;
        } else {
        address _wantToken = wantToken;
        if (isCampaignInETH) {
            _wantToken = WETH; // no direct pairs to eth in uniswap v2
        }
        require(
            IUniswapV3Factory(v3factory).getPool(_donorToken, _wantToken, poolFee) != address(0),
            "SupportChildren::donate: No direct pool exists"
        );

        address[] memory path = new address[](2);
        path[0] = _donorToken;
        path[1] = _wantToken;
        uint256 _amountInWantTokens;
        uint256 _maxDonationAmountInWantTokens;

        IERC20(_donorToken).transferFrom(
            msg.sender,
            address(this),
            _amountIn
        );

        if (routerApprovedTokens[_donorToken] != true) {
            IERC20(_donorToken).approve(address(v3router), MAX_UINT);
            routerApprovedTokens[_donorToken] = true;
        }

        uint256 _swapReturnValues;

        if (isCampaignInETH) {
            ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: _donorToken,
                tokenOut: WETH,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1000,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            _swapReturnValues = ISwapRouter(v3router).exactInputSingle(params);
            // uint256 bal = IERC20(WETH).balanceOf(address(this));
            // if (bal>0){
            //     IWETH(WETH).withdraw(bal);
            // }
            if (L2 != address(0)){
                iOVM_L1StandardBridge(L1StandardBridge).depositETHTo{value: address(this).balance}(L2,2000000,"0x");
            }
        } else {
            ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: path[0],
                tokenOut: path[1],
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1000,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
            _swapReturnValues = ISwapRouter(v3router).exactInputSingle(params);
            if (L2 != address(0)){
                iOVM_L1StandardBridge(L1StandardBridge).depositERC20To(wantToken, wantTokenL2, L2, IERC20(_donorToken).balanceOf(address(this)), 2000000, "0x");
            }
        }
        _finalDonationAmount = getMaxDonationAmount(_swapReturnValues);
        if (_finalDonationAmount < _swapReturnValues) {
            IERC20(wantToken).transfer(msg.sender, _swapReturnValues - _finalDonationAmount);
        }
        currFund += _finalDonationAmount;
            mails.push(_mail);
            mailCount++;
        
        if (currFund == goal) {
            emit GoalReached(currFund, goal, id, name, mails);
            finished = true;
            withdraw();
        }
        
        emit Donated(msg.value, id, name, _mail, _donorToken);
        if (donators[msg.sender] == false){
            //nfts.createSimpleNFT(_uri);
            donators[msg.sender] = true;
        }
        return true;
        }
        
    }
    
    function expiredWithdraw() public {
        require(endTimeStamp < block.timestamp, "Campaign::expiredWithdraw: This campaign is still active");
        require(msg.sender == owner, "campaign::expiredWithdraw: Only the beneficiary can withdraw the funds");
        if (wantToken == address(0)){
            uint256 balance = address(this).balance;
            owner.transfer(balance);
        }else{
            uint256 balance = IERC20(wantToken).balanceOf(address(this));
            IERC20(wantToken).transfer(owner, balance);
        }
    }

    function withdraw() private returns(bool sufficient) {
        if (wantToken == address(0)){
            uint256 balance = address(this).balance;
            owner.transfer(balance);
        }else{
            uint256 balance = IERC20(wantToken).balanceOf(address(this));
            IERC20(wantToken).transfer(owner, balance);
        }
        
        return true;
        }
        
    function changeEndDate(uint _endTimeStamp) public {
        endTimeStamp = _endTimeStamp;
    }
    
    function donateETH(string memory _mail) external payable {
        require(endTimeStamp > block.timestamp, "Campaign::donate: This campaign has already finished");
        require(msg.value > 0, "SupportChildren::donateETH: You must send ether");

        uint256 _finalDonationAmount = 0;

        if (wantToken == address(0)) {

            _finalDonationAmount = getMaxDonationAmount(msg.value);
            currFund += _finalDonationAmount;

            if (msg.value > _finalDonationAmount) {
                payable(msg.sender).transfer(msg.value - _finalDonationAmount);
            }
            if (donators[msg.sender] == false){
                donators[msg.sender] = true;
            }
            emit Donated(msg.value, id, name, _mail, WETH);
            if (L2 != address(0)){
                iOVM_L1StandardBridge(L1StandardBridge).depositETHTo{value: address(this).balance}(L2,2000000,"0x");
            }
            return;
        }else{

        require(IUniswapV3Factory(v3factory).getPool(WETH, wantToken, poolFee) != address(0), "no direct pool exists");

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = wantToken;
        uint256 _maxDonationAmountInWantTokens;

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: path[0],
                tokenOut: path[1],
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 1000,
                amountIn: msg.value,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        uint _swapReturnValues =
        ISwapRouter(v3router).exactInputSingle{value: msg.value}(params);
        _finalDonationAmount = getMaxDonationAmount(_swapReturnValues);

        if (donators[msg.sender] == false){
            donators[msg.sender] = true;
        }

        if (_finalDonationAmount < _swapReturnValues) {
            IERC20(wantToken).transfer(msg.sender, _swapReturnValues - _finalDonationAmount);
        }

        currFund += _finalDonationAmount;

        // if (msg.value > _finalDonationAmount) {
        //     payable(msg.sender).transfer(msg.value - _finalDonationAmount);
        // }

        emit Donated(msg.value, id, name, _mail, WETH);
        if (L2 != address(0)){
                iOVM_L1StandardBridge(L1StandardBridge).depositERC20To(wantToken, wantTokenL2, L2, IERC20(wantToken).balanceOf(address(this)), 2000000, "0x");
            }
        return;
        }
    }

    function getMaxDonationAmount(uint256 _amountIn) internal view returns (uint256 maxDonationAmount) {
        uint256 _maxPossibleDonation = goal - currFund;
        if (_amountIn <= _maxPossibleDonation) {
            return _amountIn;
        }
        return _maxPossibleDonation;
    }
    
}