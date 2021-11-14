// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

// No SafeMath needed for Solidity 0.8+
import "@openzeppelin/contracts/access/AccessControl.sol";

// TODO natspec docs

interface IReservationToken {
    function balanceOf(address owner) external view  returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract FaithReservationEvent is AccessControl {
    uint256 public holdsTotal = 0;                      // total amount of tokens held from the vault
    uint256 public depositsTotal = 0;                   // total amount of tokens available to hold
    uint256 public claimedTotal = 0;                    // total amount of tokens claimed from the vault
    uint256 public balancesTotal = 0;                   // total amount of eth deposited into the vault
    uint256 public offChainBalancesTotal = 0;                   // total amount of eth deposited into the vault

    IReservationToken public claimTokenContract;        // the token being traded
    uint256 public decimalsFromClaimTokenContract = 0;  // the number of decimal places in the above token contract

    uint256 private price;                              // the price, in wei, per token
    bool private claimsOpen = false;                    // is the claims window open
    bool private holdsOpen = false;                     // is the holds window open

    // Address where funds are distributed
    address private teamWallet;                         // 

    mapping(address => uint256) private _holds;             // map of contract callers and the amount held
    mapping(address => uint256) private _balances;          // map of contract callers and the amount deposited in eth
    mapping(address => uint256) private _claims;            // map of contract callers and the amount claimed (after holding)
    mapping(address => uint256) private _offchainbalances;  // map of contract callers and the amount claimed (after holding)

    // Event Logs
    event Held(address buyer, uint256 amount);
    event Claimed(address buyer, uint256 amount);
    event DepositedVault(address buyer, uint256 amount);
    event WithdrawnVault(address buyer, uint256 amount);
    event Withdrawn(address buyer, uint256 amount);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(IReservationToken _claimTokenContract, uint256 _price, address _adminRole) {
        _setupRole(ADMIN_ROLE, _adminRole);                                  // after contract creation, the passed address becomes the admin 
        
        // create a single token vault with a single price
        claimTokenContract = _claimTokenContract;                           // reference to the ERC20 token contract for tokens stored in the vault
        decimalsFromClaimTokenContract = claimTokenContract.decimals();     // multiplier for calcs
        price = _price;                                                     // price per token
    }

    function getHoldsTotal() public view returns (uint256) {
        return holdsTotal;
    }

    function getBalancesTotal() public view returns (uint256) {
        return balancesTotal;
    }

    function getOffchainBalancesTotal() public view returns (uint256) {
        return offChainBalancesTotal;
    }

    function getDepositsTotal() public view returns (uint256) {
        return depositsTotal;
    }

    function getPriceInWei() public view returns (uint256) {
        return price;
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

    // pass in number of tokens expected and send wei with the message payable
    // consider removing numberOfTokens passed, not really needed, requires perfect alignment with the front end
    function hold(uint256 weiAmount, uint256 numberOfTokensExpected) public payable {
        
        // check to make sure holds are open
        require(holdsOpen, "holds not open");

        // check the passed wei matches what is passed and isn't empty
        require(msg.value == weiAmount, "passed payable does not match hold parameter");
        require(msg.value != 0, "passed payable is zero");

        // TODO any need to check for overflows on the numbers??

        // calculate the number of tokens from the ethereum passed 
        uint256 numberOfTokensImplicit = msg.value / price;

        // check the caller expects the correct number of tokens passed by comparing the tokens expected with implicit
        require(numberOfTokensImplicit == numberOfTokensExpected, "number of tokens expected does not match number of tokens based on ethereum passed");
        
        // calculate the actual number of tokens with all the decimal places
        uint256 scaledNumberOfTokens = numberOfTokensImplicit * uint256(10) ** decimalsFromClaimTokenContract;        

        // check that the totalnumber of tokens requested wont go over the number in the vault to start
        require(holdsTotal + scaledNumberOfTokens <= depositsTotal, "not enough tokens available to cover hold amount requested");
        
        // keep track of the callers total tokens held and eth deposted
        _holds[msg.sender] += scaledNumberOfTokens;
        _balances[msg.sender] += msg.value;

        // keep track of contracts total number of tokens held and total eth deposited
        holdsTotal += scaledNumberOfTokens;
        balancesTotal += msg.value;

        emit Held(msg.sender, numberOfTokensExpected);
    }

    function holdForOffchainBuyer(address buyer, uint256 weiAmount, uint256 numberOfTokensExpected) public onlyRole(ADMIN_ROLE) {
        
        // check to make sure holds are open
        require(holdsOpen, "holds not open");

        // check the passed wei matches what is passed and isn't empty
        require(weiAmount != 0, "make sure amount is positive");
        require(numberOfTokensExpected != 0, "make sure amount is positive");
        
        // calculate the number of tokens from the wei amount passed 
        uint256 numberOfTokensImplicit = weiAmount / price;

        // check the caller expects the correct number of tokens passed by comparing the tokens expected with implicit
        require(numberOfTokensImplicit == numberOfTokensExpected, "number of tokens expected does not match number of tokens based on ethereum passed");
        
        // calculate the actual number of tokens with all the decimal places
        uint256 scaledNumberOfTokens = numberOfTokensImplicit * uint256(10) ** decimalsFromClaimTokenContract;        

        // check that the totalnumber of tokens requested wont go over the number in the vault to start
        require(holdsTotal + scaledNumberOfTokens <= depositsTotal, "not enough tokens available to cover hold amount requested");
        
        // keep track of the callers total tokens held and eth deposted
        _holds[buyer] += scaledNumberOfTokens;
        _offchainbalances[buyer] += weiAmount;

        // keep track of contracts total number of tokens held and offchain eth deposited
        holdsTotal += scaledNumberOfTokens;
        offChainBalancesTotal += weiAmount;

        emit Held(msg.sender, numberOfTokensExpected);
    }

    function claim(uint256 numberOfTokens) public {
        _claim(msg.sender, numberOfTokens);
    }

    // enables claims to be performed on behalf of an address by the admin
    function claimForOffchainBuyer(address claimer, uint256 numberOfTokens) public onlyRole(ADMIN_ROLE) {
        _claim(claimer, numberOfTokens);
    }

    // TODO - check the function declaration - any thing else needed? should this be mutex? prob eh
    function _claim(address claimer, uint256 numberOfTokens) private {
        // check to make sure claims are open
        require(claimsOpen, "claims not open");

        // check the offchain buyer has tokens to be issued
        require(_holds[claimer] != 0, "address does not have any tokens on hold");

        uint256 scaledNumberOfTokens = numberOfTokens * uint256(10) ** decimalsFromClaimTokenContract;        

        // TODO check there are enough coins to cover the request
        // scaledNumberOfTokens <= _holds[msg.sender]
        require(scaledNumberOfTokens <= _holds[claimer], "address does not have enough tokens on hold to cover the claim");

        // track total tokens claimed
        _claims[claimer] += scaledNumberOfTokens;
        claimedTotal += scaledNumberOfTokens;    

        // TODO check result of the transfer call - boolean?
        // send tokens to the caller
        claimTokenContract.transfer(claimer, scaledNumberOfTokens);

        emit Claimed(claimer, numberOfTokens);    
    }
    
    // Deposit tokens to be held by the contract vault
    function depositVault(uint256 amountToDeposit) public onlyRole(ADMIN_ROLE) {

        // do a test, not sure this is even required        
        require(amountToDeposit > 0);

        // calculate the actual number of tokens with all the decimal places
        uint256 scaledNumberOfTokens = amountToDeposit * uint256(10) ** decimalsFromClaimTokenContract;        

        // TODO add a check for deposit <= approved allowance for this spender
        // TOOD check the amount to deposit is available
        //      require(claimTokenContract.balanceOf(address(this)) >= scaledNumberOfTokens);
        
        // TODO check result of the transfer call - boolean?
        // transfer tokens from the caller to this contract 
        require(claimTokenContract.transferFrom(msg.sender, address(this), scaledNumberOfTokens), 'Failed to deposit into vault');

        depositsTotal += scaledNumberOfTokens;

        emit DepositedVault(msg.sender, amountToDeposit);
    }
    
    // withdraws all eth
    function withdraw() public onlyRole(ADMIN_ROLE) {        
        // TODO check balance on this contract matches the balances total
        // what happens if it doesn't, maybe just a warning state event??

        require(!holdsOpen && !claimsOpen, 'Cannot withdraw eth while the reservation event is active');

        // TODO check result of the transfer call - boolean?
        //payable(msg.sender).transfer(address(this).balance);
        
        payable(msg.sender).transfer(address(this).balance);
        
        emit Withdrawn(payable(msg.sender), balancesTotal);
    }

    // withdraw tokens from the vault
    function withdrawVault() public onlyRole(ADMIN_ROLE) returns (bool result) {
        // retrieve the number of tokens left in the vault
        uint256 scaledTokensRemaining = claimTokenContract.balanceOf(address(this));

        // adjust the deposits variable
        depositsTotal -= scaledTokensRemaining;

        require(!holdsOpen && !claimsOpen, 'Cannot withdraw remaining vault tokens while the reservation event is active');

        // TODO check result of the transfer call - boolean?
        // Send all tokens in vault to the caller.
        claimTokenContract.transfer(msg.sender, scaledTokensRemaining);

        emit WithdrawnVault(msg.sender, scaledTokensRemaining);
        return true;
    }

    function closeHolds() public onlyRole(ADMIN_ROLE) {
        holdsOpen = false;
    }

    function openHolds() public onlyRole(ADMIN_ROLE) {
        // only allow holds if there are tokens in the vault available to hold
        require(depositsTotal - holdsTotal > 0, 'Not enough tokens deposited (if any) are available to hold');

        holdsOpen = true;
    }
    function closeClaims() public onlyRole(ADMIN_ROLE) {
        
        claimsOpen = false;
    }
    function openClaims() public onlyRole(ADMIN_ROLE) {
                
        claimsOpen = true;
    }
}