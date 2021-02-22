/**
 *Submitted for verification at Etherscan.io on 2021-02-22
*/

pragma solidity =0.8.1;

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

interface IAuctionFeeManager {
    function processFee(address user, uint amount) external;
}

contract Ownable {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed from, address indexed to);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Ownable: Caller is not the owner");
        _;
    }

    function transferOwnership(address transferOwner) public onlyOwner {
        require(transferOwner != newOwner);
        newOwner = transferOwner;
    }

    function acceptOwnership() virtual public {
        require(msg.sender == newOwner);
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint a, uint b) internal pure returns (uint) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint c = a - b;

        return c;
    }

    function mul(uint a, uint b) internal pure returns (uint) {
      if (a == 0) {
            return 0;
        }

        uint c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint a, uint b) internal pure returns (uint) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint a, uint b) internal pure returns (uint) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in construction, 
        // since the code is only stored at the end of the constructor execution.

        uint size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}

library SafeERC20 {
    using SafeMath for uint;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint value) internal {
        uint newAllowance = token.allowance(address(this), spender).add(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint value) internal {
        uint newAllowance = token.allowance(address(this), spender).sub(value);
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { 
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint private _guardCounter;

    constructor () {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    modifier nonReentrant() {
        _guardCounter += 1;
        uint localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter, "ReentrancyGuard: reentrant call");
    }
}

interface IRouter {
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IERC20Permit is IERC20 {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

interface IBurnable is IERC20Permit {
    function burnTokens(uint amount) external returns (bool success);
}

contract HardStakingNFTAuction is ReentrancyGuard, Ownable, IERC721Receiver {
    using SafeMath for uint;
    using SafeERC20 for IBurnable;
    using SafeERC20 for IERC20;

    struct Auction {
        uint tokenId;
        uint auctionEnd;
        uint topBid;
        address topBidder;
        bool isWithdrawn;
    }

    IERC20Permit public immutable stakeToken;
    IBurnable public immutable burnToken;
    IERC721 public immutable auctionToken;
    IAuctionFeeManager public auctionFeeManager;
    uint public rewardRate; 
    uint public immutable auctionRoundDuration; 
    uint public constant rewardDuration = 365 days; 
    uint public minStakeAmount;
    uint public auctionFee;

    uint public lastAuctionId;
    mapping(uint => Auction) public auctions;
    mapping(uint => uint) public auctionTokenId;
    mapping(uint => uint) public tokenAuctionId;
    
    mapping(address => uint) public userWeightedStakeDate;
    mapping(address => mapping(uint => uint)) public userStakeLocks;
    mapping(address => mapping(uint =>  uint)) public userStakeAmounts;
    mapping(address => mapping(uint =>  uint)) public userBidAmounts;
    mapping(address => uint[]) public _userAuctions;

    IRouter public swapRouter;
    uint public discountRate; 
    bool public isSetPrice;
    uint public stakeTokenToConvertibleTokenRate;

    uint private _totalSupply;
    mapping(address => uint) private _balances;

    event Staked(address indexed user, uint stakeAmount, uint totalBid, uint auctionId, bool isRestake);
    event NewAuction(uint roundId, uint tokenId);
    event NewTopBid(uint auctionId, uint bidAmount, address indexed bidder);
    event Withdrawn(address indexed user, uint burnAmount);
    event BurnForToken(uint burnAmount, uint receiveAmount);
    event AuctionTokenWithdrawn(address indexed sender, uint tokenId, uint auctionId);
    event RewardPaid(address indexed user, uint reward);
    event RewardUpdated(uint reward);
    event UpdateStakeTokenToConvertibleTokenRate(uint newRate);
    event Rescue(address indexed to, uint amount);
    event RescueAuctionToken(address indexed to, uint tokenId);
    event RescueToken(address indexed to, address token, uint amount);

    constructor(
        address _burnToken,
        address _stakeToken,
        address _auctionToken,
        address _auctionFeeManger,
        uint _rewardRate,
        uint _auctionRoundDuration,
        uint _inititalRate,
        uint _minStakeAmount
    ) {
        require(_stakeToken != _burnToken, "HardStakingNFTAuction: stake and burn tokens are equal");
        burnToken = IBurnable(_burnToken);
        stakeToken = IERC20Permit(_stakeToken);
        auctionToken = IERC721(_auctionToken);
        auctionFeeManager = IAuctionFeeManager(_auctionFeeManger);
        rewardRate = _rewardRate;
        auctionRoundDuration = _auctionRoundDuration;
        isSetPrice = true;
        stakeTokenToConvertibleTokenRate = _inititalRate;
        minStakeAmount = _minStakeAmount;
        auctionFee = 10;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        //equal to return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
        return 0x150b7a02;
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint) {
        return _balances[account];
    }

    function userAuctions(address user) external view returns (uint[] memory auctionIds) {
        return _userAuctions[user];
    }

    function earned(address account) public view returns (uint) {
        return (_balances[account].mul(block.timestamp.sub(userWeightedStakeDate[account])).mul(rewardRate)) / (100 * rewardDuration);
    }


    function stakeWithPermit(uint amount, uint auctionId, uint deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
        stakeToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        // permit
        _stake(amount, auctionId, msg.sender, false, false);
    }

    function stake(uint amount, uint auctionId) external nonReentrant {
        _stake(amount, auctionId, msg.sender, false, false);
    }

    function stakeFor(uint amount, uint auctionId, address user) external nonReentrant {
        _stake(amount, auctionId, user, false, false);
    }

    function stakeAndBurnWithPermit(uint amount, uint auctionId, uint deadline, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
        require(amount >= 0, "HardStakingNFTAuction: Can't stake 0");
        burnToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
        uint stakeTokenAmount = _burnTokenForStakeToken(amount);
        // permit
        _stake(stakeTokenAmount, auctionId, msg.sender, true, false);
    }

    function stakeAndBurn(uint amount, uint auctionId) external nonReentrant {
        require(amount >= 0, "HardStakingNFTAuction: Can't stake 0");
        uint stakeTokenAmount = _burnTokenForStakeToken(amount);
        _stake(stakeTokenAmount, auctionId, msg.sender, true, false);
    }

    function stakeAndBurnFor(uint amount, uint auctionId, address user) external nonReentrant {
        require(amount >= 0, "HardStakingNFTAuction: Can't stake 0");
        uint stakeTokenAmount = _burnTokenForStakeToken(amount);
        _stake(stakeTokenAmount, auctionId, user, true, false);
    }


    function restake(uint previousAuctionId, uint currentAuctionId) external nonReentrant {
        Auction storage auction = auctions[previousAuctionId];
        require(block.timestamp > auction.auctionEnd, "HardStakingNFTAuction: Locked");
        uint previousAmount = userStakeAmounts[msg.sender][previousAuctionId];
        require(previousAmount >= minStakeAmount, "HardStakingNFTAuction: Amount is less than minimal allowed stake amount"); //minStakeAmount may have been increased from the previous stake, so we need to recheck it
        
        if (auction.topBidder == msg.sender) {
            uint tokenId = auction.tokenId;
            auction.isWithdrawn = true;
            auctionToken.transferFrom(address(this), msg.sender, previousAuctionId);
            emit AuctionTokenWithdrawn(msg.sender, tokenId, previousAuctionId);
        }

        _stake(previousAmount, currentAuctionId, msg.sender, false, true);
    }

    function withdraw(uint auctionId) public nonReentrant {
        uint amount = userStakeAmounts[msg.sender][auctionId];
        require(amount > 0, "HardStakingNFTAuction: This auction stake was withdrawn");
        require(userStakeLocks[msg.sender][auctionId] < block.timestamp, "HardStakingNFTAuction: Locked");

        Auction memory auction = auctions[auctionId];
        if (auction.topBidder == msg.sender) {
            uint tokenId = auction.tokenId;
            auction.isWithdrawn = true;
            auctionToken.transferFrom(address(this), msg.sender, tokenId);
            emit AuctionTokenWithdrawn(msg.sender, tokenId, auctionId);
        }
        
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        userStakeAmounts[msg.sender][auctionId] = 0;
        //userBidAmounts is not cleared on withdraw and stay for history
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant {
        uint reward = earned(msg.sender);
        if (reward > 0) {
            userWeightedStakeDate[msg.sender] = block.timestamp;
            stakeToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function withdrawAndGetRewardByTokenId(uint tokenId) external {
        uint auctionId = tokenAuctionId[tokenId];
        getReward();
        withdraw(auctionId);
    }

    function withdrawByTokenId(uint tokenId) external {
        uint auctionId = tokenAuctionId[tokenId];
        withdraw(auctionId);
    }

    function withdrawAndGetReward(uint auctionId) external {
        getReward();
        withdraw(auctionId);
    }

    function withdrawForAllAuctionsAndGetReward() external {
        getReward();
        withdrawForAllAuctions();
    }

    function withdrawForAllAuctions() public {
        for (uint i; i < _userAuctions[msg.sender].length; i++) {
            withdraw(_userAuctions[msg.sender][i]);
        }
    }


    function getConvertibleTokenEquivalentAmount(uint amount) public view returns (uint) { 
        if (isSetPrice) {
            return amount * stakeTokenToConvertibleTokenRate / 1e18;
        } else {
            return getConvertibleTokenEquivalentAmountFromRouter(amount);
        }
    }

    function getConvertibleTokenEquivalentAmountFromRouter(uint amount) public view returns (uint) {
        address[] memory path = new address[](2);

        path[0] = address(burnToken);            
        path[1] = address(stakeToken);
        return swapRouter.getAmountsOut(amount, path)[1].mul(1000 + discountRate) / 1000;
    }

    function isAuctionActive(uint auctionId) public view returns (bool) {
        return block.timestamp < auctions[auctionId].auctionEnd;
    }


    function _burnTokenForStakeToken(uint amount) private returns (uint) {
        burnToken.safeTransferFrom(msg.sender, address(this), amount);
        burnToken.burnTokens(amount);
        uint convertibleTokenAmount = getConvertibleTokenEquivalentAmount(amount);
        emit BurnForToken(amount, convertibleTokenAmount);
        return convertibleTokenAmount;
    }

    function _stake(uint amount, uint auctionId, address user, bool isBurnToken, bool isRestake) private {
        require(auctionId <= lastAuctionId, "HardStakingNFTAuction: No such auction Id");
        require(amount >= minStakeAmount, "HardStakingNFTAuction: Amount is less than minimal allowed stake amount");
        Auction storage auction = auctions[auctionId];
        if (auction.auctionEnd == 0) _initAuction(auctionId);
        else require(auction.auctionEnd > block.timestamp, "HardStakingNFTAuction: Round is finished");
        
        if(!isRestake) {
            if (!isBurnToken) stakeToken.transferFrom(msg.sender, address(this), amount);
        }

        if (auctionFee != 0) {
            uint feeAmount = amount * auctionFee / 100;
            stakeToken.transfer(address(auctionFeeManager), feeAmount);
            auctionFeeManager.processFee(user, feeAmount);
            amount = amount.sub(feeAmount);
        }

        if(!isRestake) {
            uint previousAmount = _balances[user];
            uint newAmount = previousAmount.add(amount);
            userWeightedStakeDate[user] = (userWeightedStakeDate[user].mul(previousAmount) / newAmount).add(block.timestamp.mul(amount) / newAmount);
            _balances[user] = newAmount;
            _totalSupply = _totalSupply.add(amount);
        }

        uint totalBid;
        uint currentBid = amount.mul(auction.auctionEnd - block.timestamp) / auctionRoundDuration;
        totalBid = userBidAmounts[user][auctionId].add(currentBid);
        userBidAmounts[user][auctionId] = totalBid;
        if (totalBid > auction.topBid) {
            auction.topBid = totalBid;
            auction.topBidder = user;
            emit NewTopBid(auctionId, totalBid, user);
        }

        uint previousStakeForCurrentAuction = userStakeAmounts[user][auctionId];
        emit Staked(user, amount, totalBid, auctionId, isRestake);
        if (previousStakeForCurrentAuction == 0) {
            _userAuctions[user].push(auctionId);
            userStakeLocks[user][auctionId] = auction.auctionEnd;
        } else {
            amount = amount.add(previousStakeForCurrentAuction);
        }
        userStakeAmounts[user][auctionId] = amount;        
    }

    function _initAuction(uint auctionId) private {
        uint auctionEnd = block.timestamp.add(auctionRoundDuration);
        auctions[auctionId].auctionEnd = auctionEnd;
    }




    function startNewAuctions(uint[] memory tokenIds, uint[] memory startBidAmounts) external { 
        require(tokenIds.length == startBidAmounts.length, "HardStakingNFTAuction: Wrong lengths");
        for (uint i; i < tokenIds.length; i++) {
            startNewAuction(tokenIds[i], startBidAmounts[i]);
        }
    }

    function startNewAuction(uint tokenId, uint startBidAmount) public onlyOwner {
        require(tokenAuctionId[tokenId] == 0, "HardStakingNFTAuction: Token already was on an auction");
        uint auctionId = ++lastAuctionId;
        auctionTokenId[auctionId] = tokenId;
        tokenAuctionId[tokenId] = auctionId;
        
        auctions[auctionId].tokenId = tokenId;
        auctions[auctionId].topBid = startBidAmount;
        
        emit NewAuction(auctionId, auctionId);
    }

    function updateStakeTokenToConvertibleTokenRate(uint newRate) external onlyOwner {
        require(newRate > 0, "HardStakingNFTAuction: New rate is must be greater than 0");
        stakeTokenToConvertibleTokenRate = newRate;
        emit UpdateStakeTokenToConvertibleTokenRate(newRate);
    }    
    
    function updateDiscountRate(uint newDiscountRate) external onlyOwner {
        require(newDiscountRate < 1000, "HardStakingNFTAuction: New discount rate must be less than 0");
        discountRate = newDiscountRate;
    }

    function updateRewardRate(uint newRewardRate) external onlyOwner {
        rewardRate = newRewardRate;
        emit RewardUpdated(newRewardRate);
    }

    function updateMinStakeAmount(uint newMinStakeAmount) external onlyOwner {
        require(newMinStakeAmount > 0, "HardStakingNFTAuction: New min stake amount must be greater than 0");
        minStakeAmount = newMinStakeAmount;
    }
    
    function updateAuctionFee(uint newAuctionFee) external onlyOwner {
        auctionFee = newAuctionFee;
    }
    

    function updateSwapRouter(address newSwapRouter) external onlyOwner {
        require(newSwapRouter != address(0), "HardStakingNFTAuction: Address is zero");
        swapRouter = IRouter(newSwapRouter);
    }

    function updateAuctionFeeManager(address newAuctionFeeManager) external onlyOwner {
        require(newAuctionFeeManager != address(0), "HardStakingNFTAuction: Address is zero");
        auctionFeeManager = IAuctionFeeManager(newAuctionFeeManager);
    }

    function rescue(address to, address tokenAddress, uint amount) external onlyOwner {
        require(to != address(0), "HardStakingNFTAuction: Cannot rescue to the zero address");
        require(amount > 0, "HardStakingNFTAuction: Cannot rescue 0");
        require(tokenAddress != address(stakeToken), "HardStakingNFTAuction: Cannot rescue stake token");
        
        IERC20(tokenAddress).safeTransfer(to, amount);
        emit RescueToken(to, address(tokenAddress), amount);
    }

    function rescueUnbiddedAuctionToken(address to, uint tokenId) external onlyOwner {
        require(to != address(0), "HardStakingNFTAuction: Cannot rescue to the zero address");
        uint auctionId = tokenAuctionId[tokenId];
        require(auctionId != 0, "HardStakingNFTAuction: Token is not on auction");
        require(auctions[auctionId].auctionEnd == 0, "HardStakingNFTAuction: Token has been bidden");
        
        auctionToken.transferFrom(address(this), to, tokenId);
        emit RescueAuctionToken(to, tokenId);
    }

    function rescue(address payable to, uint amount) external onlyOwner {
        require(to != address(0), "HardStakingNFTAuction: Cannot rescue to the zero address");
        require(amount > 0, "HardStakingNFTAuction: Cannot rescue 0");

        to.transfer(amount);
        emit Rescue(to, amount);
    }
}