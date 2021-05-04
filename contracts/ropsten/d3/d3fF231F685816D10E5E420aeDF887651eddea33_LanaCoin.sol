pragma solidity >=0.6.0 <0.8.0;

import "./Oracle.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LanaCoin is ERC20 {
    mapping (address=>uint256) bondHolders;
    mapping (address=>uint256) shareHolders;
    mapping (address=>uint256) tokenHolders;

    MockOracle oracle = new MockOracle();

    constructor() ERC20("LANA Coin", "LANA") public {}

    function getOraclePrice() view public returns (uint256) {
        return oracle.getValue();
    }
}