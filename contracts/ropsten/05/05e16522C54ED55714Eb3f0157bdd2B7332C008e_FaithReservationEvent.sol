// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

// TODO what to do about rentrancy, and safety
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// TODO add multi token support 
// https://learn.figment.io/tutorials/create-vault-smart-contract

// TODO MAKE ALL require statements fail with a const public string.

interface IReservationToken {
    function balanceOf(address owner) external view  returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external returns (uint256);
}

contract FaithReservationEvent is AccessControl {
    uint256 public holdsTotal = 0;
    uint256 public depositsTotal = 0;
    uint256 public claimedTotal = 0;
    uint256 public balancesTotal = 0;

    IReservationToken public claimTokenContract;  // the token being traded
    uint256 public decimalsFromClaimTokenContract = 0;

    uint256 private price;              // the price, in wei, per token
    bool private claimsOpen = false;
    bool private holdsOpen = false;
    address owner;

    // Address where funds are distributed
    address private teamWallet;

    mapping(address => uint256) private _holds;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _claims;

    event Held(address buyer, uint256 amount);
    event Claimed(address buyer, uint256 amount);
    event DepositedVault(address buyer, uint256 amount);
    event WithdrawnVault(address buyer, uint256 amount);
    event Withdrawn(address buyer, uint256 amount);

    constructor(IReservationToken _claimTokenContract, uint256 _price) {
        owner = msg.sender;
        
        // create a single token vault with a single price
        claimTokenContract = _claimTokenContract;                           // reference to token contract for token stored in the vault
        decimalsFromClaimTokenContract = claimTokenContract.decimals();     // multiplier for calcs
        price = _price;                                                     // price per token
    }

    function getHoldsTotal() public view returns (uint256) {
        return holdsTotal;
    }

    function getBalancesTotal() public view returns (uint256) {
        return balancesTotal;
    }

    function getDepositsTotal() public view returns (uint256) {
        return depositsTotal;
    }

    function getPriceInWei() public view returns (uint256) {
        return price;
    }

    // pass in number of tokens expected and send wei with the message payable
    // consider removing numberOfTokens, not really needed, requires perfect alignment with the front end
    function hold(uint256 weiAmount, uint256 numberOfTokensExpected) public payable {
        
        // check to make sure holds are open
        require(holdsOpen, "holds not open");

        // check the passed wei matches what is passed and isn't empty
        require(msg.value == weiAmount, "passed payable does not match hold parameter");
        require(msg.value != 0, "passed payable is zero");

        // TODO make sure passed number of tokens expected is a whole number

        // calculate the number of tokens from the ethereum passed 
        uint256 numberOfTokensImplicit = msg.value / price;

        // check the caller expects the correct number of tokens passed by comparing the tokens expected with implicit
        require(numberOfTokensImplicit == numberOfTokensExpected, "number of tokens expected does not match number of tokens based on ethereum passed");
        
        // calculate the actual number of tokens with all the decimal places
        uint256 scaledNumberOfTokens = numberOfTokensImplicit * uint256(10) ** decimalsFromClaimTokenContract;        

        // check that the totalnumber of tokens requested wont go over the number in the vault to start
        require(holdsTotal + scaledNumberOfTokens <= depositsTotal, "not enough tokens available to cover hold amount requested");
        
        // keep track of total tokens requested and eth deposted
        _holds[msg.sender] += scaledNumberOfTokens;
        _balances[msg.sender] += msg.value;

        emit Held(msg.sender, numberOfTokensExpected);
        
        // keep track of total number of tokens held and total eth deposited
        holdsTotal += scaledNumberOfTokens;
        balancesTotal += msg.value;
    }

    function claim(uint256 numberOfTokens) public {

        // check to make sure claims are open
        require(claimsOpen, "claims not open");

        // check the caller has tokens to be issued
        // TODO check if this comparison should be to address(0x0)
        require(_holds[msg.sender] != 0, "caller does not have any tokens on hold");

        uint256 scaledNumberOfTokens = numberOfTokens * uint256(10) ** decimalsFromClaimTokenContract;        

        // check there are enough coins to cover the request
        // scaledNumberOfTokens <= _holds[msg.sender]

        // send tokens to the caller
        claimTokenContract.transfer(msg.sender, scaledNumberOfTokens);

        emit Claimed(msg.sender, numberOfTokens);

        // track total tokens claimed
        _claims[msg.sender] += scaledNumberOfTokens;
        claimedTotal += scaledNumberOfTokens;    
    }

    // Deposit tokens to be held by the contract vault
    // TODO need to add access control to this
    function depositVault(uint256 amountToDeposit) public {

        // do a test, not sure this is even required        
        require(amountToDeposit > 0);

        // calculate the actual number of tokens with all the decimal places
        uint256 scaledNumberOfTokens = amountToDeposit * uint256(10) ** decimalsFromClaimTokenContract;        

        // TODO add a check for deposit <= approved allowance for this spender
        // TOOD check the amount to deposit is available
        //      require(claimTokenContract.balanceOf(address(this)) >= scaledNumberOfTokens);
        
        // transfer tokens from the caller to this contract 
        require(claimTokenContract.transferFrom(msg.sender, address(this), scaledNumberOfTokens));

        depositsTotal += scaledNumberOfTokens;
        emit DepositedVault(msg.sender, amountToDeposit);
    }
    
    // withdraw eth
    // TODO need to add access control to this
    function withdraw() public returns(bool result) {
        
        payable(msg.sender).transfer(address(this).balance);

        emit Withdrawn(payable(msg.sender), balancesTotal);

        return true;
    }

    // withdraw tokens from the vault
    // TODO add access ctronl
    function withdrawVault() public returns (bool result) {
        // retrieve the number of tokens left in the vault
        uint256 scaledTokensRemaining = claimTokenContract.balanceOf(address(this));

        // Send all tokens in vault to the caller.
        claimTokenContract.transfer(msg.sender, scaledTokensRemaining);

        // adjust the deposits variable
        depositsTotal -= scaledTokensRemaining;

        emit WithdrawnVault(msg.sender, scaledTokensRemaining);
        return true;
    }

    // TODO add access control
    function closeHolds() public {
        
        holdsOpen = false;
    }

    function openHolds() public {
        
        // only allow holds if there are tokens in the vault

        // TODO add code

        holdsOpen = true;
    }
    function closeClaims() public {
        
        claimsOpen = false;
    }
    function openClaims() public {
                
        claimsOpen = true;
    }

    function getClaimsOpenState() public view returns (bool) {
        return claimsOpen;
    }

    function getHoldsOpenState() public view returns (bool) {
        return holdsOpen;
    }

    function getTokensRemainingToClaim() public view returns (uint256) {

      return _holds[msg.sender] - _claims[msg.sender];
    }
}