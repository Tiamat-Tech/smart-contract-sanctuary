// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../EKTA_ERC20/IEKTAERC20.sol";

contract EktaManagerDev is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant STATE_UPDATE_REQUESTER = keccak256("STATE_UPDATE_REQUESTER");
    bytes32 public constant MAPPER_ROLE = keccak256("MAPPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(address => address) public EktaEthPairs; // EKTA Token => ETH Token
    mapping(address => address) public EthEktaPairs; // ETH Token => EKTA Token

    event Deposited(address indexed ektaToken, address indexed ethToken, uint amount, address indexed user);
    event WithDrawn(address indexed ektaToken, address indexed ethToken, uint amount, address indexed user);
    event AddedTokenPair(address indexed ethToken, address indexed ektaToken);
    event UpdatedTokenPair(address indexed ethToken, address indexed ektaToken);
    event NativeWithdraw(address fromAddress, address toAddress, uint amount);
    event TokenFromContractTransferred(address externalAddress,address toAddress, uint amount);
    event EthFromContractTransferred(address toAddress, uint amount);

    constructor(address _owner) public {
        //Setting up roles
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(STATE_UPDATE_REQUESTER, _owner);
        _setupRole(MAPPER_ROLE, _owner);
        _setupRole(PAUSER_ROLE, _owner);
    }

    function addTokenPairs(address _ektaToken, address _ethToken) external onlyRole(MAPPER_ROLE) nonReentrant whenNotPaused returns(bool) {
        require(_ektaToken != address(0) && _ethToken != address(0), "EktaManager: Token address cant be zero address");
        require(EktaEthPairs[_ektaToken] == address(0) && EthEktaPairs[_ethToken] == address(0), "EktaManager: Already mapped");

        _mapToken(_ektaToken, _ethToken);
        emit AddedTokenPair(_ektaToken, _ethToken);
        return true;
    }

    function updateTokenPairs(address _ektaToken, address _ethToken) external onlyRole(MAPPER_ROLE) nonReentrant whenNotPaused returns(bool) {
        require(_ektaToken != address(0) && _ethToken != address(0), "EktaManager: Token address cant be zero address");
        require(EktaEthPairs[_ektaToken] != _ethToken, "EktaManager: Pair already exists");
        require(EktaEthPairs[_ektaToken] != address(0), "EktaManager: Pair dont exists");

        // clean token pairs to avoid re-mapping
        cleanTokenPairs(_ektaToken);

        _mapToken(_ektaToken, _ethToken);
        emit UpdatedTokenPair(_ektaToken, _ethToken);
        return true;
    }

    function _mapToken(address _ektaToken, address _ethToken) internal {
        // update EktaEthPairs and EthEktaPairs mapping
        EktaEthPairs[_ektaToken] = _ethToken;
        EthEktaPairs[_ethToken] = _ektaToken;
    }

    function cleanTokenPairs(address _ektaToken) public onlyRole(MAPPER_ROLE) whenNotPaused returns(bool) {
        address _ethToken = EktaEthPairs[_ektaToken];
        EktaEthPairs[_ektaToken] = address(0);
        EthEktaPairs[_ethToken] = address(0);
        return true;
    }

    function depositTokenOnEkta(IEKTAERC20 _ektaerc20, address _user, uint amount) external onlyRole(STATE_UPDATE_REQUESTER){
        _ektaerc20.deposit(_user, amount);
        address ethToken = EktaEthPairs[address(_ektaerc20)];
        emit Deposited(address(_ektaerc20), ethToken, amount, _user);
    }

    function withdrawTokenOnEkta(address _ektaerc20, uint _amount) external {
        // transfer the balance to this address
        IERC20(_ektaerc20).safeTransferFrom(msg.sender, address(this), _amount);
        //Call withdraw function from the token
        IEKTAERC20(_ektaerc20).withdraw(_amount);
        address ethToken = EktaEthPairs[_ektaerc20];
        emit WithDrawn(_ektaerc20, ethToken, _amount, msg.sender);
    }

    receive() external payable {
        withdrawNativeFromEkta();
    }

    function withdrawNativeFromEkta() payable public {
        uint256 amountInWei = msg.value;
        emit NativeWithdraw(msg.sender, address(this), amountInWei);
    }

    function withdrawERC20Token(address _tokenContract, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenContract != address(0), "Bridge: Address cant be zero address");
        IERC20 tokenContract = IERC20(_tokenContract);
        tokenContract.transfer(msg.sender, amount);
        emit TokenFromContractTransferred(_tokenContract, msg.sender, amount);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawEthFromContract(address user, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "Bridge: Address cant be zero address");
        require(amount <= getBalance(), "Bridge: Amount exceeds balance");
        address payable _user = payable(user);
        _user.transfer(amount);
        emit EthFromContractTransferred(user, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE){
        _unpause();
    }
}