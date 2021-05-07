// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./token/StandardToken.sol";
import "./lib/SafeMath.sol";
import "./interfaces/IDataFeed.sol";

/**
    @title Treasury
    @notice The Treasury is essentially the entry point. It controls the creation and destruction of shares and tokens etc.
*/
contract Treasury {
    StandardToken public token; // Token contract.
    StandardToken public share; // Share contract.
    address public oracle;

    enum Policy {Neutral, Expand, Contract}
    struct Cycle {
        Policy policy;
        uint256 toMint; // # of shares or tokens to mint.
        uint256 startBlock;
        uint256 totalBid;
        mapping(address => uint256) bids; // User -> Bid Amount
    }

    uint256 public index = 0;
    mapping(uint256 => Cycle) public cycles;

    uint256 public constant TIME_BETWEEN_CYCLES = 5; // Time between cycles in blocks.
    uint256 public constant PEG_PRICE = 1e6; // $1 USD

    uint256 public sharePrice = 100e6; // 100 coins to a share.
    uint256 public coinPrice = PEG_PRICE; // $1 to a coin.

    constructor(address _token, address _share) public {
        token = StandardToken(_token);
        share = StandardToken(_share);

        require(
            share.decimals() == 18 && token.decimals() == 18,
            "18 Decimals required."
        );
        cycles[index++] = Cycle(Policy.Neutral, 0, block.number, 0);

        oracle = msg.sender;
    }

    // TODO: update the cycle function with better algo.
    function newCycle() public {
        Cycle memory prevCycle = cycles[index];
        require(block.number > prevCycle.startBlock + TIME_BETWEEN_CYCLES);

        if (prevCycle.policy == Policy.Contract) token.burn(prevCycle.totalBid);
        else if (prevCycle.policy == Policy.Expand)
            share.burn(prevCycle.totalBid);

        Policy newPolicy;
        uint256 amountToMint;
        uint256 target = (token.totalSupply() * coinPrice) / PEG_PRICE;

        if (coinPrice == PEG_PRICE) newPolicy = Policy.Neutral;
        else if (coinPrice > PEG_PRICE) {
            newPolicy = Policy.Expand;
            amountToMint =
                ((token.totalSupply() - target) * PEG_PRICE) /
                sharePrice;
        } else {
            newPolicy = Policy.Contract;
            amountToMint = ((target - token.totalSupply()) * 10) / 100;
        }

        index++;
        cycles[index] = Cycle(newPolicy, amountToMint, block.number, 0);

        if (newPolicy == Policy.Contract) {
            share.mint(address(this), amountToMint);
        } else if (newPolicy == Policy.Expand) {
            token.mint(address(this), amountToMint);
        }
    }

    function updateCoinPrice(uint256 _price) public {
        require(msg.sender == oracle, "Oracle only");
        require(_price > (coinPrice * 9) / 10, "Price change was over 10%.");
        require(_price < (coinPrice * 11) / 10, "Price change was over 10%.");
        coinPrice = _price;
    }

    function placeBid(uint256 amount) public {
        Cycle storage c = cycles[index];

        require(block.number < c.startBlock + TIME_BETWEEN_CYCLES);
        require(c.policy != Policy.Neutral);
        require(amount > PEG_PRICE);

        if (c.policy == Policy.Expand)
            share.transferFrom(msg.sender, address(this), amount);
        else if (c.policy == Policy.Contract)
            token.transferFrom(msg.sender, address(this), amount);

        c.bids[msg.sender] += amount;
        c.totalBid += amount;
    }

    function claimBid(uint256 c) public {
        uint256 bidAmount = cycles[c].bids[msg.sender];

        require(
            block.number > cycles[c].startBlock + TIME_BETWEEN_CYCLES &&
                bidAmount > 0 &&
                cycles[c].policy != Policy.Neutral
        );

        uint256 amountToPay =
            (bidAmount * cycles[c].toMint) / cycles[c].totalBid;

        if (cycles[c].policy == Policy.Expand)
            share.transfer(msg.sender, amountToPay);
        else if (cycles[c].policy == Policy.Contract)
            token.transfer(msg.sender, amountToPay);

        delete cycles[c].bids[msg.sender];
    }

    function updateSharePrice(uint256 _price) public {
        require(msg.sender == oracle, "Oracle only");
        require(_price > (sharePrice * 9) / 10, "Price change was over 10%.");
        require(_price < (sharePrice * 11) / 10, "Price change was over 10%.");
        sharePrice = _price;
    }

    function getUserBids(uint256 id, address user)
        public
        view
        returns (uint256)
    {
        return cycles[id].bids[user];
    }

    function getCurrentBidPrice() public view returns (uint256) {
        Cycle storage c = cycles[index];
        return (c.totalBid * PEG_PRICE) / c.toMint;
    }
}