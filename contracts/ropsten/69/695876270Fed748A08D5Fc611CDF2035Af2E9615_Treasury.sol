pragma solidity ^0.8.0;

import "./Token.sol";
import "./interfaces/IOracle.sol";

contract Treasury {
    Token public shares;
    Token public tokens;
    IOracle public oracle;

    enum Policy { Neutral, Expand, Contract }
    struct Cycle {
        Policy policy;
        uint256 timeStarted;
        uint256 amountToMint;
        uint256 totalBids;
    }

    uint256 public constant PEG_PRICE = 1e6;
    uint256 public constant CYCLE_INTERVAL = 10;

    uint256 currCycle = 0;
    
    uint256 public tokenPrice;
    uint256 public sharePrice;

    mapping(uint256 => Cycle) public cycles;
    mapping(uint256 => uint256) public bids;

    event CycleStarted(uint256 indexed id, Policy policy, uint256 blockNumber);

    constructor(
        address _token,
        address _shares,
        address _oracle
    ) {
        shares = Token(_shares);
        tokens = Token(_token);
        oracle = IOracle(_oracle);

        cycles[currCycle] = Cycle(Policy.Neutral, block.number, 0, 0);
        emit CycleStarted(currCycle, Policy.Neutral, block.number);
    }

    function startCycle() public {
        require(block.number > cycles[currCycle].timeStarted + CYCLE_INTERVAL);

        // Burn old bids
        if (cycles[currCycle].policy == Policy.Expand) tokens.burn(cycles[currCycle].totalBids);
        else if (cycles[currCycle].policy == Policy.Contract) shares.burn(cycles[currCycle].totalBids);

        uint target =  tokens.totalSupply() * tokenPrice / PEG_PRICE;
        Policy newPolicy;
        uint256 amountToMint;
        
        currCycle += 1;
        if(tokenPrice == PEG_PRICE)
            newPolicy = Policy.Neutral;
        else if(getTokenPrice() > PEG_PRICE) {
            newPolicy = Policy.Expand;
            amountToMint = (tokens.totalSupply() - target) * 10 / 100;
        }
        else if(getTokenPrice() < PEG_PRICE) {
            newPolicy = Policy.Contract;
            amountToMint = (tokens.totalSupply() - target) * PEG_PRICE / sharePrice;
        }

        currCycle += 1;
        
        cycles[currCycle] = Cycle(newPolicy, block.number, amountToMint, 0);
        emit CycleStarted(currCycle, newPolicy, block.number);
    }

    function setCoinPrice(uint256 _price) public {
        require(msg.sender == address(oracle));
        tokenPrice = _price;
    }
    
    function setSharePrice(uint256 _price) public {
        require(msg.sender == address(oracle));
        sharePrice = _price;
    }

    function getTokenPrice() view public returns (uint256) {
        return tokenPrice;
    }

    function getSharePrice() view public returns (uint256) {
        return sharePrice;
    }
}