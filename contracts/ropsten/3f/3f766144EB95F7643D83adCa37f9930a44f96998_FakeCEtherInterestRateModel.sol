pragma solidity ^0.5.16;

import "./src/WhitePaperInterestRateModel.sol";

contract FakeCEtherInterestRateModel is WhitePaperInterestRateModel {
    constructor()
    WhitePaperInterestRateModel(
      0.02 * (10 ** 18),
      0.3 * (10 ** 18)
    )
    public
    {}
}