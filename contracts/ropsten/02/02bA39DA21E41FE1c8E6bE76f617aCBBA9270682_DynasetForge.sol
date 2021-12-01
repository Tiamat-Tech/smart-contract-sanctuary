// SPDX-License-Identifier: MIT
pragma solidity ^0.6.4;

import "@openzeppelin/contracts/math/SafeMath.sol";
//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
//import "./interfaces/IUniswapV2Recipe.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/OneInchAgregator.sol";
import "./interfaces/IDynaset.sol";

contract DynasetForge is AccessControl {
    using SafeMath for uint256;

    event Deposit(address user, uint256 amount);
    event WithdrawETH(address user, uint256 amount, address receiver);
    event WithdrawOuput(address user, uint256 amount, address receiver);
    event Forge(address user, uint256 amount, uint256 price);
    event Cooldown(address indexed user);

    // uses the default admin role
    bytes32 constant public CONTROLLER_ROLE = DEFAULT_ADMIN_ROLE;
    bytes32 constant public BLACK_SMITH = keccak256(abi.encode("BLACK_SMITH"));

    mapping(address => uint256) public ethBalanceOf;
    mapping(address => uint256) public outputBalanceOf;

    OneInchAgregator constant OneInch = OneInchAgregator(
        0x11111112542D85B3EF69AE05771c2dCCff4fAa26
    );

    IWETH public constant WETH = IWETH(
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );

    using SafeMath for uint256;
    mapping(address => uint256) public burnCooldown;
    uint256 public _COOLDOWN_SECONDS;

    IERC20 public Dynaset;
    IERC20 public RewardToken;
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
        address _xsdao
    ) public {
        _setupRole(BLACK_SMITH, _blacksmith);
        Dynaset = IERC20(_dynaset);
        RewardToken = IERC20(_xsdao);
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
    function initializeContribution(uint256 _min, uint256 _max) external onlyRole(BLACK_SMITH)
    {
        minContribution = _min;
        maxContribution = _max;
    }

    // _maxprice should be equal to the sum of _receivers.
    // this variable is needed because in the time between calling this function
    // and execution, the _receiver amounts can differ.
    function forge(
        address[] memory _receivers,//users for witch you will mint tokens
        address _dynaset,
        uint256 _outputAmount,//expected amount to be minted in the dynaset
        uint256 _maxPrice,//maximum eth contributed by the receivers
        uint256 realPrice//get quote in weth value of all the underlying tokens corresponding to the _outputAmount expected from the dynaset
    ) public DynasetForgeIsReady onlyRole(BLACK_SMITH) {

        require(realPrice <= _maxPrice, "PRICE_ERROR");

        uint256 totalInputAmount = 0;
        for (uint256 i = 0; i < _receivers.length; i++) {

            uint256 userAmount = ethBalanceOf[_receivers[i]];
            if (totalInputAmount == realPrice) {
                break;
            } else if (totalInputAmount.add(userAmount) <= realPrice) {
                totalInputAmount = totalInputAmount.add(userAmount);
            } else {
                userAmount = realPrice.sub(totalInputAmount);
                // e.g. totalInputAmount = realPrice
                totalInputAmount = totalInputAmount.add(userAmount);
            }

            ethBalanceOf[_receivers[i]] = ethBalanceOf[_receivers[i]].sub(
                userAmount
            );

            uint256 userForgeAmount = _outputAmount.mul(userAmount).div(
                realPrice
            );
            outputBalanceOf[_receivers[i]] = outputBalanceOf[_receivers[i]].add(
                userForgeAmount
            );

            emit Forge(_receivers[i], userForgeAmount, userAmount);
        }
        // Provided balances are too low.
        require(totalInputAmount == realPrice, "INSUFFICIENT_FUNDS");

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

    //swap tokens get quote amount from one inchapi for each underlying,  weth-> underlying 
    function _swapToToken(
        address _token,//weth
        uint256 _amount,//amount to send
        bytes32[] calldata _data,//data from one inch
        address _dynaset // approve the dynaset for the swapped token
    ) external payable onlyRole(BLACK_SMITH) {  

        require(msg.value >= _amount, "Amount ETH too low");

        //convert to weth the eth deposited to the contract
        WETH.deposit{value: _amount}();

        OneInch.unoswap(_token,_amount,0,_data);
  
        IERC20(_token).approve(_dynaset, _amount);
    }

    function deposit() public payable DynasetForgeIsReady {
        require(hasContributed[msg.sender] == false, "deposit: user already contributed");
        require(msg.value <= maxContribution, "deposit: amount > max");
        require(minContribution <= msg.value, "deposit: amount < min");
        hasContributed[msg.sender] = true;

        require(deposit_enabled == true, "deposit: cooldown already enable");
      
        ethBalanceOf[msg.sender] = ethBalanceOf[msg.sender].add(msg.value);
        require(address(this).balance <= cap, "MAX_CAP");
        emit Deposit(msg.sender, msg.value);
    }

    receive() external payable {
        deposit();
    }

    function withdrawAll(address payable _receiver) external DynasetForgeIsReady {
        require(withdraw_enabled == true, "deposit: cooldown already enable");
        withdraw_enabled = false;
        withdrawAllETH(_receiver);
        withdrawOutput(_receiver);
    }

    function withdrawAllETH(address payable _receiver) public DynasetForgeIsReady {
        require(withdraw_enabled == true, "deposit: cooldown already enable");
        withdraw_enabled = false;
        withdrawETH(ethBalanceOf[msg.sender], _receiver);
    }

    function withdrawETH(uint256 _amount, address payable _receiver)
        public
        DynasetForgeIsReady
    {
        require(withdraw_enabled == true, "deposit: cooldown already enable");
        withdraw_enabled = false;
        ethBalanceOf[msg.sender] = ethBalanceOf[msg.sender].sub(_amount);
        _receiver.transfer(_amount);
        emit WithdrawETH(msg.sender, _amount, _receiver);
    }

    function withdrawOutput(address _receiver) public DynasetForgeIsReady {
        require(withdraw_enabled == true, "deposit: cooldown already enable");
        withdraw_enabled = false;
        uint256 _amount = outputBalanceOf[msg.sender];
        outputBalanceOf[msg.sender] = 0;

        Dynaset.transfer(_receiver, _amount);
  
        emit WithdrawOuput(msg.sender, _amount, _receiver);
    }

    function setCap(uint256 _cap) external onlyRole(BLACK_SMITH) {
        cap = _cap;
    }

    function setDynaset(address _Dynaset) public onlyRole(BLACK_SMITH) {
        // Only able to change Dynaset from address(0) to an actual address
        // Otherwise old outputBalances can conflict with a new Dynaset
        // require(address(Dynaset) == address(0), "Dynaset_ALREADY_SET");
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

   function withdrawAnyTokens(address token,uint256 amount) external onlyRole(BLACK_SMITH) {
        IERC20 Token = IERC20(token);
     //   uint256 currentTokenBalance = Token.balanceOf(address(this));
        Token.transfer(msg.sender, amount); 
    }
}