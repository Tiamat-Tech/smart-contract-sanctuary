//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./MockRouterInterface.sol";

struct Presale {
  address userAddress;
  uint256 start;
  uint256 end;
  bool alive;
  // price of eth per ERC20, this is a ratio
  uint256 price;
  uint256 amountMantissa;
  uint256 soldMantissa;
  address tokenAddress;
  IERC20 token;
}

contract PresaleContract is Ownable {
  MockRouterInterface router;

  uint256 private feeBasisPoints;

  using Counters for Counters.Counter;
  Counters.Counter private nextPresaleID;
  mapping(uint256 => Presale) private presales;

  constructor(uint256 _feeBasisPoints, address routerAddress) {
    feeBasisPoints = _feeBasisPoints;
    router = MockRouterInterface(routerAddress);
  }

  function getNextPresaleID() private returns (uint256) {
    uint256 presaleID = nextPresaleID.current();
    nextPresaleID.increment();
    return presaleID;
  }

  function startPresale(
    uint256[] memory starts,
    uint256[] memory ends,
    uint256[] memory prices,
    uint256[] memory amounts,
    address[] memory tokenAddresses
  ) public {
    require(
      starts.length == ends.length &&
        starts.length == prices.length &&
        starts.length == amounts.length &&
        starts.length == tokenAddresses.length,
      "length mismatch"
    );

    for (uint256 i = 0; i < starts.length; i++) {
      // Register presale
      Presale memory p = Presale(
        msg.sender,
        starts[i],
        ends[i],
        true,
        prices[i],
        amounts[i],
        0,
        tokenAddresses[i],
        IERC20(tokenAddresses[i])
      );
      uint256 presaleID = getNextPresaleID();
      presales[presaleID] = p;

      p.token.transferFrom(msg.sender, address(this), amounts[i]);
    }
  }

  function getPresale(uint256 presaleID) public view returns (Presale memory) {
    return presales[presaleID];
  }

  function buy(uint256 presaleID, uint256 amountMantissa) public payable {
    Presale memory p = getPresale(presaleID);
    require(p.alive, "presale ended");
    require(block.timestamp > p.start, "presale not started");
    uint256 availableMantissa = p.amountMantissa - p.soldMantissa;
    require(availableMantissa >= amountMantissa, "not enough tokens");
    uint256 totalPriceMantissa = amountMantissa * p.price;
    require(msg.value >= totalPriceMantissa, "not enough ETH");

    // assume we have enough ERC20 to send to client
    // assume client has enough ETH to pay
    // assume presale is alive

    presales[presaleID].soldMantissa += amountMantissa;
    p.token.transfer(msg.sender, amountMantissa);
  }

  function withdraw(uint256 presaleID) public {
    Presale memory p = getPresale(presaleID);

    require(p.userAddress == msg.sender, "not presale owner");
    require(!p.alive, "presale alive");

    uint256 availableMantissa = (p.amountMantissa - p.soldMantissa);
    p.token.transfer(msg.sender, availableMantissa);
  }

  function endPresale(uint256 presaleID) public {
    Presale memory p = getPresale(presaleID);

    require(p.alive, "presale not alive");
    require(block.timestamp > p.end, "presale not ended");
    presales[presaleID].alive = false;

    // Create liquitity if we actually sold anything
    if (p.soldMantissa > 0) {
      p.token.transferFrom(p.userAddress, address(this), p.soldMantissa);
      uint256 totalETHMantissa = p.price * p.soldMantissa;
      uint256 fee = (totalETHMantissa * feeBasisPoints) / 10000;

      uint256 liquitiyETH = totalETHMantissa - fee;

      p.token.approve(address(router), p.soldMantissa);
      router.addLiquidityETH{ value: liquitiyETH }(
        p.tokenAddress,
        p.soldMantissa,
        p.soldMantissa,
        liquitiyETH,
        p.userAddress,
        block.timestamp + 60 * 60
      );

      (bool sent, bytes memory data) = owner().call{ value: fee }("");
      require(sent, "Failed to send Ether");
    }
  }

  function changeFee(uint256 newFewBasisPoints) public onlyOwner {
    feeBasisPoints = newFewBasisPoints;
  }
}