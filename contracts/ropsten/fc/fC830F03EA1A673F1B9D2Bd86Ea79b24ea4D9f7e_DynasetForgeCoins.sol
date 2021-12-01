// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/OneInchAgregator.sol";
import "./interfaces/IDynaset.sol";

contract DynasetForgeCoins is AccessControl {
    using SafeMath for uint256;

    event Deposit(address user, uint256 amount);
    event WithdrawETH(address user, uint256 amount, address receiver);
    event WithdrawOuput(address user, uint256 amount, address receiver);
    event Forge(address user, uint256 amount, uint256 price);

    // uses the default admin role
    bytes32 constant public CONTROLLER_ROLE = DEFAULT_ADMIN_ROLE;

    bytes32 constant public BLACK_SMITH = keccak256(abi.encode("BLACK_SMITH"));

    mapping(address => uint256) public tokenBalanceOf;
    mapping(address => uint256) public outputBalanceOf;
    
    using SafeMath for uint256;

    bool isWithdrawActive = false;

    IERC20 public Dynaset;
    IERC20 public RewardToken;
    IERC20 public TokenContrib;
    uint256 public cap;

    // boolean to simulate cooldown
    bool withdraw_enabled = true;
    bool deposit_enabled = true;
    // contribution
    uint256 minContribution;
    uint256 maxContribution;
    // all contributors
    mapping(address => bool) public hasContributed;

    constructor(
        address _blacksmith,
        address _dynaset,
        address _token
    ) public {
        _setupRole(BLACK_SMITH, _blacksmith);
        Dynaset = IERC20(_dynaset);
        TokenContrib  = IERC20(_token);
    }

    modifier DynasetForgeIsReady {
        require(address(Dynaset) != address(0), "DYNASET_NOT_SET");
        _;
    }

    modifier onlyRole(bytes32 _role) {
        require(hasRole(_role, msg.sender), "AUTH_FAILED");
        _;
    }

    // Initialisation contribution
    function initializeContribution(uint256 _min, uint256 _max) external 
    onlyRole(BLACK_SMITH)
    {
        minContribution = _min;
        maxContribution = _max;
    }

    // _maxprice should be equal to the sum of _receivers.
    // this variable is needed because in the time between calling this function
    // and execution, the _receiver amounts can differ.
    function forge(
        address[] memory _receivers,
        address _dynaset,
        uint256 _outputAmount,
        uint256 _maxPrice,//maximum eth contributed by the receivers
        uint256 _realPrice
    ) public onlyRole(BLACK_SMITH) {

        require(_realPrice <= _maxPrice, "PRICE_ERROR");

        uint256 totalInputAmount = 0;
        for (uint256 i = 0; i < _receivers.length; i++) {

            uint256 userAmount = tokenBalanceOf[_receivers[i]];
            if (totalInputAmount == _realPrice) {
                break;
            } else if (totalInputAmount.add(userAmount) <= _realPrice) {
                totalInputAmount = totalInputAmount.add(userAmount);
            } else {
                userAmount = _realPrice.sub(totalInputAmount);
                // e.g. totalInputAmount = realPrice
                totalInputAmount = totalInputAmount.add(userAmount);
            }

            tokenBalanceOf[_receivers[i]] = tokenBalanceOf[_receivers[i]].sub(
                userAmount
            );

            uint256 userForgeAmount = _outputAmount.mul(userAmount).div(
                _realPrice
            );
            outputBalanceOf[_receivers[i]] = outputBalanceOf[_receivers[i]].add(
                userForgeAmount
            );

            emit Forge(_receivers[i], userForgeAmount, userAmount);
        }
        // Provided balances are too low.
        require(totalInputAmount == _realPrice, "INSUFFICIENT_FUNDS");
        _mintDynaset(_dynaset, _outputAmount);
    }

    function _mintDynaset(address _dynaset, uint256 _dynasetAmount) internal {
        (address[] memory tokens, uint256[] memory amounts) = IDynaset(_dynaset)
            .calcTokensForAmount(_dynasetAmount);

        //check if enough tokens for swap
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 amount = amounts[i];
            IERC20 underlygin_token = IERC20(token);
            require (underlygin_token.balanceOf(address(this)) >= amount,"not enough tokens" );
            IERC20(token).approve(_dynaset, amount);
        }

        IDynaset dynaset = IDynaset(_dynaset);
        dynaset.joinDynaset(_dynasetAmount);
    }

    function deposit(uint256 amount) external  {
        require(hasContributed[msg.sender] == false, "deposit: user already contributed");
        require(amount <= maxContribution, "deposit: amount > max");
        require(minContribution <= amount, "deposit: amount < min");
        hasContributed[msg.sender] = true;

        require(deposit_enabled == true, "deposit: cooldown already enable");


        require (TokenContrib.balanceOf(address(msg.sender)) >= amount,"not enough tokens");
        TokenContrib.transferFrom(msg.sender,address(this),amount);
        tokenBalanceOf[msg.sender] = tokenBalanceOf[msg.sender].add(amount);

        require(TokenContrib.balanceOf(address(this)) <= cap, "MAX_CAP");
        emit Deposit(msg.sender, amount);
    }


    function withdrawAll(address payable _receiver) external {
        withdrawOutput(_receiver);
    }


    function withdrawUSDT(uint256 _amount, address _receiver)
        public
        
    {
        require(withdraw_enabled == true, "deposit: cooldown already enable");
        withdraw_enabled = false;
        tokenBalanceOf[msg.sender] = tokenBalanceOf[msg.sender].sub(_amount);
        TokenContrib.transfer(_receiver,_amount);
        emit WithdrawETH(msg.sender, _amount, _receiver);
    }

    function withdrawOutput(address _receiver) public {
        require(withdraw_enabled == true, "deposit: cooldown already enable");
        withdraw_enabled = false;
        uint256 _amount = outputBalanceOf[msg.sender];
        Dynaset.transfer(_receiver, _amount);
        outputBalanceOf[msg.sender] = 0;

    }

    function setCap(uint256 _cap) external onlyRole(BLACK_SMITH) {
        cap = _cap;
    }

    function setDynaset(address _Dynaset) public onlyRole(BLACK_SMITH) {

        Dynaset = IERC20(_Dynaset);
    }


    function getCap() external view returns (uint256) {
        return cap;
    }

    function resetCooldown() internal
    {
        require(withdraw_enabled == false && deposit_enabled == false, "resetCooldown: cooldown already reset");
        withdraw_enabled = true;
        deposit_enabled = true;
    }

    function setWithdraw(bool _enable) internal
    {
        withdraw_enabled = _enable;
    }

    function setDeposit(bool _enable) internal
    {
        deposit_enabled = _enable;
    }

   function withdrawAnyTokens(address token) external onlyRole(BLACK_SMITH) {
        IERC20 Token = IERC20(token);
        uint256 currentTokenBalance = Token.balanceOf(address(this));
        Token.transfer(msg.sender, currentTokenBalance); 
    }
}