// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Pledge.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

///@title Pledge Factory contract
contract PledgeFactory is AccessControl {
    using SafeERC20 for IERC20;

    ///@dev emited when new pledge contact is deployed
    ///@param user creator of the pledge contact
    ///@param pledge pledge contact address
    event PledgeCreated(address indexed user, address pledge);

    ///@dev emited when token is adder or removed from the allowlist
    ///@param tokenAddress address of the token
    ///@param value result bool value
    event TokenToggled(address indexed tokenAddress, bool value);

    ///@dev emited when pledge is removed from the mapping
    ///@param  pledgeAddress id
    event PledgePurged(address pledgeAddress);

    ///@dev emited when fee value is changed
    ///@param value new fee value
    event FeeSet(uint256 value);

    ///@dev emited when fee token address is changed
    ///@param feeToken new fee token address
    event FeeTokenSet(address feeToken);

    ///@dev emited when treasury address is changed
    ///@param treasury new treasury address
    event TreasurySet(address treasury);

    ///contract admin role hash
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //contract priveleged role hash
    bytes32 public constant PRIVELEGED_ROLE = keccak256("PRIVELEGED_ROLE");

    ///fee value
    uint256 public fee;

    ///deployed pledge contracts counter
    uint256 pledgesCount;

    ///number of allowed tokens
    uint256 tokensCount;

    ///fee token address
    address public feeToken;

    ///treasury address
    address public treasury;

    ///deployed pledge contracts addresses by index mapping
    mapping(uint256 => address) public pledges;

    ///deployed pledge indexes by address mapping
    mapping(address => bool) public activePledges;

    ///list of tokens
    mapping(uint256 => address) tokenList;

    ///allowed tokens
    mapping(address => bool) public tokenAccepted;

    ///available token list
    mapping(address => bool) tokenAdded;

    constructor(address _feeToken, address _treasury) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(PRIVELEGED_ROLE, ADMIN_ROLE);
        feeToken = _feeToken;
        treasury = _treasury;
    }

    ///@dev deploying new pledge contract with parameters
    ///@param _tokenContractAddress address of the token that can be pledged
    ///@param _lockingPeriod locking period in seconds
    ///@param _title the title of the pledge
    ///@param _description the purpose of the pledge
    function createPledge(
        address _tokenContractAddress,
        uint256 _lockingPeriod,
        string memory _title,
        string memory _description
    ) external {
        require(
            tokenAccepted[_tokenContractAddress] == true,
            "createPledge:: token isn't allowed"
        );
        if (fee != 0) {
            IERC20(feeToken).safeTransferFrom(msg.sender, treasury, fee);
        }

        Pledge pledge = new Pledge(
            _tokenContractAddress,
            _lockingPeriod,
            _title,
            _description
        );
        pledges[pledgesCount] = address(pledge);
        activePledges[address(pledge)] = true;
        pledgesCount++;
        pledge.transferOwnership(msg.sender);

        emit PledgeCreated(msg.sender, address(pledge));
    }

    ///@dev removing and adding tokens to the allowlist
    ///@param _tokenAddress address of the token
    ///@param _value bool value to allow/disallow the token
    function toggleToken(address _tokenAddress, bool _value)
        external
        onlyRole(PRIVELEGED_ROLE)
    {
        if (!tokenAdded[_tokenAddress]) {
            tokenAdded[_tokenAddress] = true;
            tokenList[tokensCount] = _tokenAddress;
            tokensCount++;
        }
        tokenAccepted[_tokenAddress] = _value;
        emit TokenToggled(_tokenAddress, _value);
    }

    ///@dev purging pledge from the list
    ///@param _address pledge address
    function purgePledge(address _address) external onlyRole(PRIVELEGED_ROLE) {
        require(activePledges[_address] == true, "purgePledge:: pledge doesn't exist");
        activePledges[_address] = false;
        emit PledgePurged(_address);
    }

    ///@dev setting fee that's needed to be paid
    ///@param _value fee value
    function setFee(uint256 _value) external onlyRole(PRIVELEGED_ROLE) {
        fee = _value;
        emit FeeSet(_value);
    }

    ///@dev setting fee token
    ///@param _address new fee token address
    function setFeeToken(address _address) external onlyRole(PRIVELEGED_ROLE) {
        feeToken = _address;
        emit FeeTokenSet(_address);
    }

    ///@dev setting treasury address
    ///@param _treasury treasury address
    function setTreasury(address _treasury) external onlyRole(PRIVELEGED_ROLE) {
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    function getAllActiveTokens() external view returns (address[] memory) {
        address[] memory _tokenList = new address[](countActiveTokens());
        uint256 counter;
        for (uint256 i = 0; i < tokensCount; i++) {
            if (tokenAccepted[tokenList[i]] == true) {
                _tokenList[counter] = tokenList[i];
                counter++;
            }
        }
        return _tokenList;
    }

    function countActiveTokens() internal view returns (uint256 _counter) {
        for (uint256 i = 0; i < tokensCount; i++) {
            if (tokenAccepted[tokenList[i]] == true) {
                _counter++;
            }
        }
        return _counter;
    }
}