// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./EKTA_ERC20/IEKTAERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EktaManager is Initializable, UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {

    bytes32 public constant STATE_UPDATE_REQUESTER = keccak256("STATE_UPDATE_REQUESTER");
    bytes32 public constant MAPPER_ROLE = keccak256("MAPPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(string => mapping(address => address)) public EktaEthPairs; // EKTA Token => ETH Token
    mapping(string => mapping(address => address)) public EthEktaPairs; // ETH Token => EKTA Token

    event Deposited(string network, address indexed ektaToken, address indexed ethToken, uint amount, address indexed user);
    event WithDrawn(string network, address indexed ektaToken, address indexed ethToken, uint amount, address indexed user);
    event AddedTokenPair(string indexed network, address indexed ethToken, address indexed ektaToken);
    event UpdatedTokenPair(string indexed network, address indexed ethToken, address indexed ektaToken);
    event NativeWithdraw(string indexed network, address indexed token, address fromAddress, address toAddress, uint amount);
    event TokenFromContractTransferred(address externalAddress,address toAddress, uint amount);
    event NativeFromContractTransferred(address toAddress, uint amount);

    /**
     * @dev Initializes the contract.
     *
     * Requirements:
     * - @param _owner cannot be the zero address.
     */
    function initialize(address _owner) public initializer {
        require(_owner != address(0), "EktaManager: Address cant be zero address");
        
        //Setting up roles
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(STATE_UPDATE_REQUESTER, _owner);
        _setupRole(MAPPER_ROLE, _owner);
        _setupRole(PAUSER_ROLE, _owner);

        // initializing
        __Pausable_init_unchained();
        __AccessControl_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Ownable_init_unchained();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Creates a pair for ekta and eth token by the caller with MAPPER_ROLE.
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param _ektaToken cannot be the zero address.
     * - @param _ethToken cannot be the zero address.
     * 
     * @return A boolean value indicating whether the operation succeeded.
     * 
     * Emits a {AddedTokenPair} event indicating the paired token addresses.
     */
    function addTokenPairs(string memory network, address _ektaToken, address _ethToken) external onlyRole(MAPPER_ROLE) nonReentrant whenNotPaused returns(bool) {
        require(keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("ETH")) || keccak256(abi.encodePacked(network)) == keccak256(abi.encodePacked("BSC")), "EktaManager: Network can be either ETH or BSC");
        require(_ektaToken != address(0) && _ethToken != address(0), "EktaManager: Token address cant be zero address");
        require(EktaEthPairs[network][_ektaToken] == address(0) && EthEktaPairs[network][_ethToken] == address(0), "EktaManager: Already mapped");

        _mapToken(network, _ektaToken, _ethToken);
        emit AddedTokenPair(network, _ektaToken, _ethToken);
        return true;
    }

    /**
     * @dev Updates the eth pair address for ekta token by the caller with MAPPER_ROLE
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param _ektaToken cannot be the zero address.
     * - @param _ethToken cannot be the zero address.
     * 
     * @return A boolean value indicating whether the operation succeeded
     * 
     * Emits a {UpdatedTokenPair} event indicating the paired token addresses
     */
    function updateTokenPairs(string memory network, address _ektaToken, address _ethToken) external onlyRole(MAPPER_ROLE) nonReentrant whenNotPaused returns(bool) {
        require(_ektaToken != address(0) && _ethToken != address(0), "EktaManager: Token address cant be zero address");
        require(EktaEthPairs[network][_ektaToken] != _ethToken, "EktaManager: Pair already exists");
        require(EktaEthPairs[network][_ektaToken] != address(0), "EktaManager: Pair dont exists");

        // clean token pairs to avoid re-mapping
        cleanTokenPairs(network, _ektaToken);

        _mapToken(network, _ektaToken, _ethToken);
        emit UpdatedTokenPair(network, _ektaToken, _ethToken);
        return true;
    }

    /**
     * @dev Internal function to map tokens
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param _ektaToken cannot be the zero address.
     * - @param _ethToken cannot be the zero address.
     */
    function _mapToken(string memory network, address _ektaToken, address _ethToken) internal {
        // update EktaEthPairs and EthEktaPairs mapping
        EktaEthPairs[network][_ektaToken] = _ethToken;
        EthEktaPairs[network][_ethToken] = _ektaToken;
    }

    /**
     * @dev Clears the ekta and eth pair address to avoid re-mapping by the caller with MAPPER_ROLE
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param _ektaToken cant be zero address
     * 
     * @return A boolean value indicating whether the operation succeeded
     */
    function cleanTokenPairs(string memory network, address _ektaToken) public onlyRole(MAPPER_ROLE) whenNotPaused returns(bool) {
        address _ethToken = EktaEthPairs[network][_ektaToken];
        EktaEthPairs[network][_ektaToken] = address(0);
        EthEktaPairs[network][_ethToken] = address(0);
        return true;
    }

    /**
     * @dev mint the token to user 
     * by the caller with STATE_UPDATE_REQUESTER role
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param _ektaerc20 cannot be the zero address.
     * - @param _user cannot be the zero address.
     * - @param amount should be greater than 0.
     * 
     * Emits a {TokenDeposited} event.
     */
    function depositTokenOnEkta(string memory network, IEKTAERC20 _ektaerc20, address _user, uint amount) external onlyRole(STATE_UPDATE_REQUESTER){
        _ektaerc20.deposit(_user, amount);
        address ethToken = EktaEthPairs[network][address(_ektaerc20)];
        emit Deposited(network, address(_ektaerc20), ethToken, amount, _user);
    }

    /**
     * @dev burn token from user
     * by the caller with STATE_UPDATE_REQUESTER role
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param _ektaerc20 cannot be the zero address.
     * - @param _amount should be greater than 0.
     * 
     * Emits a {WithDrawn} event.
     */
    function withdrawTokenOnEkta(string memory network, address _ektaerc20, uint _amount) external {
        // transfer the balance to this address
        IERC20Upgradeable(_ektaerc20).transferFrom(msg.sender, address(this), _amount);
        //Call withdraw function from the token
        IEKTAERC20(_ektaerc20).withdraw(_amount);
        address ethToken = EktaEthPairs[network][_ektaerc20];
        emit WithDrawn(network, _ektaerc20, ethToken, _amount, msg.sender);
    }

    // to recieve Native
    receive() external payable {}

    /**
     * @dev Send native currency to contract address
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param token should be greater than 0.
     * 
     * Emits a {NativeWithdraw} event.
     */
    function withdrawNativeFromEktaToEth(string memory network, address token) payable external {
        uint256 amountInWei = msg.value;
        emit NativeWithdraw(network, token, msg.sender, address(this), amountInWei);
    }

    /**
     * @dev Send native currency to contract address
     *
     * Requirements:
     * - @param network enum value [ETH, BSC].
     * - @param token should be greater than 0.
     * 
     * Emits a {NativeWithdraw} event.
     */
    function withdrawNativeFromEktaToBsc(string memory network, address token) payable external {
        uint256 amountInWei = msg.value;
        emit NativeWithdraw(network, token, msg.sender, address(this), amountInWei);
    }

    /**
     * @dev Recover the amount of particular token from the contract address
     * by caller with DEFAULT_ADMIN_ROLE.
     *
     * Requirements:
     * - @param _tokenContract cannot be the zero address.
     * - @param amount should be greater than 0.
     * 
     * Emits a {TokenFromContractTransferred} event indicating the token address and amount.
     */
    function withdrawERC20Token(address _tokenContract, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenContract != address(0), "EktaManager: Address cant be zero address");
        IERC20Upgradeable tokenContract = IERC20Upgradeable(_tokenContract);
        tokenContract.transfer(msg.sender, amount);
        emit TokenFromContractTransferred(_tokenContract, msg.sender, amount);
    }

    /**
     * @dev Recover Native currency from the contract address
     * by caller with DEFAULT_ADMIN_ROLE.
     *
     * Requirements:
     * - @param user cannot be the zero address.
     * - @param amount.
     * 
     * Emits a {NativeFromContractTransferred} event.
     */
    function withdrawEthFromContract(address user, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(user != address(0), "EktaManager: Address cant be zero address");
        require(amount <= address(this).balance, "EktaManager: Amount exceeds balance");
        address payable _user = payable(user);
        (bool success, ) = _user.call{value: amount}("");
        require(success, "EktaManager: Transfer failed.");
        emit NativeFromContractTransferred(user, amount);
    }

    /**
     * @dev Pause the contract (stopped state)
     * by caller with PAUSER_ROLE.
     *
     * Requirements:
     * - The contract must not be paused.
     * 
     * Emits a {Paused} event.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause the contract (normal state)
     * by caller with PAUSER_ROLE.
     *
     * Requirements:
     * - The contract must be paused.
     * 
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyRole(PAUSER_ROLE){
        _unpause();
    }
}