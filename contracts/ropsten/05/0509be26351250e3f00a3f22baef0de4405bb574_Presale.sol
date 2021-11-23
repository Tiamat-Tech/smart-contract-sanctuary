/**
 *Submitted for verification at Etherscan.io on 2021-11-23
*/

pragma solidity ^0.8.4;
// SPDX-License-Identifier: Unlicensed


abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}



contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }   
    
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }


    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}



library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    

}



contract Presale is Context, Ownable {
    using SafeMath for uint256;
    
    mapping (address => uint256) public _contributions;

    IERC20 public _token;
    uint256 private _tokenDecimals;
    address payable public _wallet;
    uint256 public _rate;
    uint256 public _weiRaised;
    uint256 public endICO;
    uint public minPurchase;
    uint public availableTokensICO;

    event TokensPurchased(address  purchaser, address  beneficiary, uint256 value, uint256 amount);
    
    constructor (uint256 rate, address payable wallet, IERC20 token, uint256 tokenDecimals)  {
        require(rate > 0, "Pre-Sale: rate is 0");
        require(wallet != address(0), "Pre-Sale: wallet is the zero address");
        require(address(token) != address(0), "Pre-Sale: token is the zero address");
        
        _rate = rate;
        _wallet = wallet;
        _token = token;
        _tokenDecimals = 9 - tokenDecimals;
    }


    receive () external payable {
        if(endICO > 0 && block.timestamp < endICO){
            buyTokens(_msgSender());
        }
        else{
            endICO = 0;
            revert('Pre-Sale is closed');
        }
    }
    
    
    //Start Pre-Sale
    function startICO() external onlyOwner {
        availableTokensICO = _token.balanceOf(address(this));
        require(availableTokensICO > 0 , 'availableTokens must be > 0');
        minPurchase = 1 * 10**9;
        _weiRaised = 0;
    }
    
    function stopICO() external onlyOwner {
        endICO = 0;
    }
    
    
    //Pre-Sale 
    function buyTokens(address beneficiary) public  payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        _weiRaised = _weiRaised.add(weiAmount);
        availableTokensICO = availableTokensICO - tokens;
        _contributions[beneficiary] = _contributions[beneficiary].add(weiAmount);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
    }

    function buyTokens2(address beneficiary) public  payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        _weiRaised = _weiRaised.add(weiAmount);
        availableTokensICO = availableTokensICO - tokens;
        _contributions[beneficiary] = _contributions[beneficiary].add(weiAmount);
        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);
         uint256 tokensAmt = _getTokenAmount(_contributions[msg.sender]);
        _contributions[msg.sender] = 0;
        _token.transfer(msg.sender, tokensAmt);
        require(address(this).balance > 0, 'Contract has no money');
        _wallet.transfer(address(this).balance);
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(weiAmount != 0, "Crowdsale: weiAmount is 0");
        require(weiAmount >= minPurchase, 'have to send at least: minPurchase');
        this; 
    }

    function claimTokens() external {
        uint256 tokensAmt = _getTokenAmount(_contributions[msg.sender]);
        _contributions[msg.sender] = 0;
        _token.transfer(msg.sender, tokensAmt);
    }


    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(_rate).div(10**_tokenDecimals);
    }

    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }
    
     function withdraw() external onlyOwner {
         require(address(this).balance > 0, 'Contract has no money');
        _wallet.transfer(address(this).balance);    
    }
    
    function checkContribution(address addr) public view returns(uint256){
        return _contributions[addr];
    }
    
    function setRate(uint256 newRate) external onlyOwner {
        _rate = newRate;
    }
    
    function setAvailableTokens(uint256 amount) public onlyOwner {
        availableTokensICO = amount;
    }
 
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }
    
    function setWalletReceiver(address payable newWallet) external onlyOwner(){
        _wallet = newWallet;
    }
    
    function setMinPurchase(uint256 value) external onlyOwner{
        minPurchase = value;
    }
    
    function takeTokens(IERC20 tokenAddress)  public onlyOwner {
        IERC20 tokenBEP = tokenAddress;
        uint256 tokenAmt = tokenBEP.balanceOf(address(this));
        require(tokenAmt > 0, 'BEP-20 balance is 0');
        tokenBEP.transfer(_wallet, tokenAmt);
    }
    
}