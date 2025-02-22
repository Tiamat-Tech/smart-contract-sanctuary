// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// removed safeMath, see https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2465

pragma solidity "0.8.0";

// @title IFOV3

contract PublicOffering is Ownable {
    using SafeERC20 for IERC20;

    address private implementation;

    // The LP token used
    IERC20 public lpToken;

    // The offering token
    IERC20 public offeringToken;

    // The block number when IFO starts
    uint256 public startBlock;

    // The block number when IFO ends
    uint256 public endBlock;

    // maps the user-address and PoolID to the deposited amount in that Pool
    mapping(address => uint256) private amount;

    // amount of tokens offered for the pool (in offeringTokens)
    uint256 private offeringAmount;
    // price in MGH/USDT => for 1 MGH/USDT price would be 10**12; 10MGH/USDT would be 10**13
    uint256 private price;
    // total amount deposited in the Pool (in LP tokens); resets when new Start and EndBlock are set
    uint256 private totalAmount;

    // Admin withdraw events
    event AdminWithdraw(uint256 amountLP, uint256 amountOfferingToken, uint256 amountWei);

    // Admin recovers token
    event AdminTokenRecovery(address tokenAddress, uint256 amountTokens);

    // Deposit event
    event Deposit(address indexed user, uint256 amount);

    // Harvest event
    event Harvest(address indexed user, uint256 offeringAmount);

    // Event for new start & end blocks
    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);

    // Event when parameters are set for one of the pools
    event PoolParametersSet(uint256 offeringAmount, uint256 price);

    // TimeLock ensures that users have enough time to harvest before Admin withdraws tokens,
    // sets new Start and EndBlocks or changes Pool specifications (~1e5 Blocks)
    modifier TimeLock() {
        require(block.number > endBlock, 'must wait before calling this function');
    _;}



    /**
     * @dev It can only be called once.
     * @param _lpToken: the LP token used
     * @param _offeringToken: the token that is offered for the IFO
     * @param _startBlock: the intial start block for the IFO
     * @param _endBlock: the inital end block for the IFO
     * @param _adminAddress: the admin address
     */

    constructor(
        address _lpToken,
        address _offeringToken,
        uint256 _offeringAmount,
        uint256 _price,
        uint256 _startBlock,
        uint256 _endBlock,
        address _adminAddress
    ) {
        lpToken = IERC20(_lpToken);
        offeringToken = IERC20(_offeringToken);
        setPool(_offeringAmount*10**18, _price*10**6);
        updateStartAndEndBlocks(_startBlock, _endBlock);
        transferOwnership(_adminAddress);
    }

    /**
     * @notice It allows users to deposit LP tokens to pool
     * @param _amount: the number of LP token used (6 decimals)
     */
    function deposit(uint256 _amount) external {

        // Checks that pool was set
        require(offeringAmount > 0, "Pool not set");

        // Checks whether the block number is not too early
        require(block.number > startBlock, "Too early");

        // Checks whether the block number is not too late
        require(block.number < endBlock, "Too late");

        // Checks that the amount deposited is not inferior to 0
        require(_amount > 0, "Amount must be > 0");

        // if its pool1, check if new total amount will be smaller or equal to OfferingAmount / price

        require(
          offeringAmount >= totalAmount + _amount * price,
          'not enough Offering Tokens left in Pool'
        );

        // Transfers funds to this contract
        lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

        // Update the user status
        amount[msg.sender] += _amount;

        // Updates the totalAmount for pool
        totalAmount += _amount;

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @notice It allows users to harvest from pool
     * @notice if user is not whitelisted and the whitelist is active, the user is refunded in lpTokens
     */
    function harvest() external {
        // buffer time between end of deposit and start of harvest for admin to whitelist (~7 hours)
        require(block.number > endBlock, "Too early to harvest");

        // Checks whether the user has participated
        require(amount[msg.sender] > 0, "Did not participate");

        // Initialize the variables for offering and refunding user amounts
        uint256 offeringTokenAmount = _calculateOfferingAmount(msg.sender);

        amount[msg.sender] = 0;

        offeringToken.safeTransfer(address(msg.sender), offeringTokenAmount);

        emit Harvest(msg.sender, offeringTokenAmount);
    }


    /**
     * @notice It allows the admin to withdraw funds
     * @notice TimeLock
     * @param _lpAmount: the number of LP token to withdraw (18 decimals)
     * @param _offerAmount: the number of offering amount to withdraw
     * @param _weiAmount: the amount of Wei to withdraw
     * @dev This function is only callable by admin.
     */
    function finalWithdraw(uint256 _lpAmount, uint256 _offerAmount, uint256 _weiAmount) external  onlyOwner TimeLock {
        require(_lpAmount <= lpToken.balanceOf(address(this)), "Not enough LP tokens");
        require(_offerAmount <= offeringToken.balanceOf(address(this)), "Not enough offering token");

        if (_lpAmount > 0) {
            lpToken.safeTransfer(address(msg.sender), _lpAmount);
        }

        if (_offerAmount > 0) {
            offeringToken.safeTransfer(address(msg.sender), _offerAmount);
        }

        if (_weiAmount > 0){
            payable(address(msg.sender)).transfer(_weiAmount);
        }

        emit AdminWithdraw(_lpAmount, _offerAmount, _weiAmount);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw (18 decimals)
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(lpToken), "Cannot be LP token");
        require(_tokenAddress != address(offeringToken), "Cannot be offering token");

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice It sets parameters for pool
     * @param _offeringAmount : offering amount (in tokens)
     * @dev This function is only callable by admin.
     * @notice can not offer more than the current balance of the contract
     * @notice TimeLock
     */
    function setPool(
        uint256 _offeringAmount,
        uint256 _price
    ) public onlyOwner TimeLock {

        offeringAmount = _offeringAmount;
        price = _price;

        emit PoolParametersSet(_offeringAmount, _price);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @param _startBlock: the new start block
     * @param _endBlock: the new end block
     * @notice TimeLock
     * @notice automatically resets the totalAmount in each Pool to 0
     */
    function updateStartAndEndBlocks(uint256 _startBlock, uint256 _endBlock) public onlyOwner TimeLock {
        require(_startBlock < _endBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");
        //reset the totalAmount in the pool, when initiating new start and end blocks
        totalAmount = 0;
        startBlock = _startBlock;
        endBlock = _endBlock;

        emit NewStartAndEndBlocks(_startBlock, _endBlock);
    }
    /**
     * @notice It returns the pool information
     * @return offeringAmountPool: amount of tokens offered for the pool (in offeringTokens)
     * @return totalAmountPool: total amount pool deposited (in LP tokens)
     */
    function viewPoolInformation()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            offeringAmount,
            price,
            totalAmount
        );
    }
    /**
     * @notice External view function to see user amount in pool
     * @param _user: user address
     */
    function viewUserAmount(address _user)
        external
        view
        returns (uint256)
    {
        return (amount[_user]);
    }

    /**
     * @notice External view function to see user offering amounts 
     * @param _user: user address
     */
    function viewUserOfferingAmount(address _user)
        external
        view
        returns (uint256)
    {
       return _calculateOfferingAmount(_user);
    }


    /**
     * @notice It calculates the offering amount for a user and the number of LP tokens to transfer back.
     * @param _user: user address
     * @return {uint256, uint256} It returns the offering amount, the refunding amount (in LP tokens)
     */
    function _calculateOfferingAmount(address _user)
        internal
        view
        returns (uint256)
    {
        return amount[_user] * price;
    }

    /**
     * @notice It returns the user allocation for pool
     * @dev 100,000,000,000 means 0.1 (10%) / 1 means 0.0000000000001 (0.0000001%) / 1,000,000,000,000 means 1 (100%)
     * @param _user: user address
     * @return it returns the user's share of pool
     */
    function _getUserAllocation(address _user) internal view returns (uint256) {
        if (totalAmount > 0) {
            return amount[_user] * 1e12 / totalAmount;
        } else {
            return 0;
        }
    }

    function setToken( address _lpToken, address _offering) public onlyOwner {
        lpToken = IERC20(_lpToken);
        offeringToken = IERC20(_offering);
    }
}