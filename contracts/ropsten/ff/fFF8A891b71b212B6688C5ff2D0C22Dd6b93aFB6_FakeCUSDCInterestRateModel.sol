pragma solidity ^0.5.16;

import "./src/WhitePaperInterestRateModel.sol";

contract FakeCUSDCInterestRateModel is WhitePaperInterestRateModel {
    constructor()
    WhitePaperInterestRateModel(
      0,//0
      0.2 * (10 ** 18) //200,00000,00000,00000
    )
    public
    {}
}