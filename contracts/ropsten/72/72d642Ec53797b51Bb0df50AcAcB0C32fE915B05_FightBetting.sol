pragma solidity 0.8.3;

// SPDX-License-Identifier: MIT



import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract IRewardDistributionRecipient is Ownable {
    address public rewardDistribution;

    function notifyRewardAmount(uint256 reward, uint256 _duration) virtual external;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(address _rewardDistribution) external onlyOwner {
        rewardDistribution = _rewardDistribution;
    }
}

// TODO: Make this use `GamesCore` and update `GamesCore` to support BNB.
contract FightBetting is IRewardDistributionRecipient {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // TODO: Remove after extending GamesCore.sol
    address public croupier;

    enum Fighter {
        Undecided,
        Rookie,
        Loomdart
    }

    IERC20 public token;

    string public constant desc = "CT Fight Night Dubai 2021: RookieXBT vs Loomdart";

    uint256 public constant endTime = 1634400000;
    uint256 public constant lastClaimTime = endTime + 1 days * 365 * 0.25;

    bool public isPaused;
    bool public isCanceled;
    bool public isFinal;
    bool public isFeesClaimed;

    Fighter public winner;

    mapping(address => uint256) public loomdartBNBBet;
    mapping(address => uint256) public rookieBNBBet;
    mapping(address => uint256) public loomdartXBLZDBet;
    mapping(address => uint256) public rookieXBLZDBet;

    uint256 public loomdartBNBPot;
    uint256 public rookieBNBPot;
    uint256 public loomdartXBLZDPot;
    uint256 public rookieXBLZDPot;

    event LoomdartBNBBet(address indexed user, uint256 amount);
    event RookieBNBBet(address indexed user, uint256 amount);
    event LoomdartXBLZDBet(address indexed user, uint256 amount);
    event RookieXBLZDBet(address indexed user, uint256 amount);

    event EarningsPaid(address indexed user, uint256 bnbEarnings, uint256 tokenEarnings);

    modifier checkStatus() {
        require(!isFinal, "fight is decided");
        require(!isCanceled, "fight is canceled, claim your bet");
        require(!isPaused, "betting not started");
        require(block.timestamp < endTime, "betting has ended");
        _;
    }

    constructor(address _croupier, address _token) {
        croupier = _croupier;
        token = IERC20(_token);
        rewardDistribution = msg.sender;
    }

    function BNBBet(Fighter fighter) public payable checkStatus {
        require(msg.value != 0, "no bnb sent");
        if (fighter == Fighter.Loomdart) {
            loomdartBNBBet[msg.sender] += msg.value;
            loomdartBNBPot += msg.value;
            emit LoomdartBNBBet(msg.sender, msg.value);
        } else if (fighter == Fighter.Rookie) {
            rookieBNBBet[msg.sender] += msg.value;
            rookieBNBPot += msg.value;
            emit RookieBNBBet(msg.sender, msg.value);
        } else {
            revert("LFG! Pick one already!");
        }
    }

    function XBLZDBet(Fighter fighter, uint256 amount) public checkStatus {
        require(amount != 0, "no token sent");
        if (fighter == Fighter.Loomdart) {
            token.safeTransferFrom(msg.sender, address(this), amount);
            loomdartXBLZDBet[msg.sender] += amount;
            loomdartXBLZDPot += amount;
            emit LoomdartXBLZDBet(msg.sender, amount);
        } else if (fighter == Fighter.Rookie) {
            token.safeTransferFrom(msg.sender, address(this), amount);
            rookieXBLZDBet[msg.sender] += amount;
            rookieXBLZDPot += amount;
            emit RookieXBLZDBet(msg.sender, amount);
        } else {
            revert("LFG! Pick one already!");
        }
    }

    function pauseBetting() external onlyRewardDistribution {
        isPaused = true;
    }

    function unpauseBetting() external onlyRewardDistribution {
        isPaused = false;
    }

    function cancelFight() external onlyRewardDistribution {
        require(!isFinal, "fight is decided");
        isCanceled = true;
    }

    function finalizeFight(Fighter fighter) external onlyRewardDistribution {
        require(!isFinal, "fight is decided");
        require(!isCanceled, "fight is canceled");
        require(fighter == Fighter.Loomdart || fighter == Fighter.Rookie, "invalid fighter");
        winner = fighter;
        isFinal = true;
    }

    function getFees() external onlyRewardDistribution returns (uint256 bnbFees, uint256 tokenFees) {
        require(!isFeesClaimed, "fees claimed");
        if (isFinal) {
            isFeesClaimed = true;

            if (winner == Fighter.Loomdart) {
                bnbFees = rookieBNBPot.mul(1e18).div(1e20);
                if (bnbFees != 0) {
                    _safeTransfer(bnbFees, true);
                }

                tokenFees = rookieXBLZDPot.mul(1e18).div(1e20);
                if (tokenFees != 0) {
                    _safeTransfer(tokenFees, false);
                }
            } else if (winner == Fighter.Rookie) {
                bnbFees = loomdartBNBPot.mul(1e18).div(1e20);
                if (bnbFees != 0) {
                    _safeTransfer(bnbFees, true);
                }

                tokenFees = loomdartXBLZDPot.mul(1e18).div(1e20);
                if (tokenFees != 0) {
                    _safeTransfer(tokenFees, false);
                }
            }
        }
    }

    function rescueFunds(address tokenAddress) external onlyRewardDistribution {
        if (tokenAddress == address(0)) {
            Address.sendValue(payable(msg.sender), address(this).balance);
        } else {
            IERC20(token).safeTransfer(payable(msg.sender), IERC20(tokenAddress).balanceOf(address(this)));
        }
    }

    function earned(address account) public view returns (uint256 bnbEarnings, uint256 tokenEarnings) {
        if (isFinal) {
            uint256 _loomdartBNBBet = loomdartBNBBet[account];
            uint256 _rookieBNBBet = rookieBNBBet[account];
            uint256 _loomdartXBLZDBet = loomdartXBLZDBet[account];
            uint256 _rookieXBLZDBet = rookieXBLZDBet[account];

            uint256 winnings;
            uint256 fee;

            if (winner == Fighter.Loomdart && _loomdartBNBBet != 0) {
                winnings = rookieBNBPot.mul(_loomdartBNBBet).div(loomdartBNBPot);
                fee = winnings.mul(1e18).div(1e20);
                winnings -= fee;
                bnbEarnings = _loomdartBNBBet.add(winnings);
            } else if (winner == Fighter.Rookie && _rookieBNBBet != 0) {
                winnings = loomdartBNBPot.mul(_rookieBNBBet).div(rookieBNBPot);
                fee = winnings.mul(1e18).div(1e20);
                winnings -= fee;
                bnbEarnings = _rookieBNBBet.add(winnings);
            }

            if (winner == Fighter.Loomdart && _loomdartXBLZDBet != 0) {
                winnings = rookieXBLZDPot.mul(_loomdartXBLZDBet).div(loomdartXBLZDPot);
                fee = winnings.mul(1e18).div(1e20);
                winnings -= fee;
                tokenEarnings = _loomdartXBLZDBet.add(winnings);
            } else if (winner == Fighter.Rookie && _rookieXBLZDBet != 0) {
                winnings = loomdartXBLZDPot.mul(_rookieXBLZDBet).div(rookieXBLZDPot);
                fee = winnings.mul(1e18).div(1e20);
                winnings -= fee;
                tokenEarnings = _rookieXBLZDBet.add(winnings);
            }
        } else if (isCanceled) {
            bnbEarnings = loomdartBNBBet[account] + rookieBNBBet[account];
            tokenEarnings = loomdartXBLZDBet[account] + rookieXBLZDBet[account];
        }
    }

    function getRewards() public {
        require(isFinal || isCanceled, "fight not decided");

        (uint256 bnbEarnings, uint256 tokenEarnings) = earned(msg.sender);
        if (bnbEarnings != 0) {
            loomdartBNBBet[msg.sender] = 0;
            rookieBNBBet[msg.sender] = 0;
            _safeTransfer(bnbEarnings, true);
        }
        if (tokenEarnings != 0) {
            loomdartXBLZDBet[msg.sender] = 0;
            rookieXBLZDBet[msg.sender] = 0;
            _safeTransfer(tokenEarnings, false);
        }
        emit EarningsPaid(msg.sender, bnbEarnings, tokenEarnings);
    }

    function _safeTransfer(uint256 amount, bool isBNB) internal {
        uint256 balance;
        if (isBNB) {
            balance = address(this).balance;
            if (amount > balance) {
                amount = balance;
            }
            Address.sendValue(payable(msg.sender), amount);
        } else {
            balance = token.balanceOf(address(this));
            if (amount > balance) {
                amount = balance;
            }
            token.safeTransfer(msg.sender, amount);
        }
    }

    // TODO: Remove after extending GamesCore.sol
    function setToken(address _token) external onlyOwner {
        require(_token != address(0x0));
        token = IERC20(_token);
    }

    // TODO: Remove after extending GamesCore.sol
    function setCroupier(address _addr) public onlyOwner {
        croupier = _addr;
    }

    // unused
    function notifyRewardAmount(uint256, uint256) external override pure { return; }
}