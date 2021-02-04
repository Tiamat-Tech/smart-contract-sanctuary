// SPDX-License-Identifier: UNLICENSED
/*
https://everin.one/
*/
pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';


contract EverToken is ERC20, Ownable {
    using SafeMath for uint256;

    event Burned(address indexed burner, uint256 burnAmount);
    event MintedReward(address indexed minter, uint256 mintAmount);

    address public spendingAndPromotion;
    address public developer;
    IUniswapV2Pair public uniswapExchange;
    IUniswapV2Factory public immutable factory;
    mapping(address => bool) private _whitelist;

    constructor(
        address _developer,
        address _spendingAndPromotion,
        uint256 _forUniswapAmount
    ) public ERC20("EverToken", "EVER") {
        spendingAndPromotion = _spendingAndPromotion;
        developer = _developer;
        factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);    
        _mint(msg.sender, _forUniswapAmount);
    }
    
    function transfer(address recipient, uint256 amount) public override(ERC20) returns (bool){
        require(address(uniswapExchange) != address(0) || _whitelist[recipient]==true,
        "token purchase is not available during the liquidity creation period");
        return ERC20.transfer(recipient, amount);
    }

    function initWhitelist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            _whitelist[_addresses[i]] = true;
        }
    }

    function mintReward(uint256 _amount) external onlyOwner {
        uint256 amountForDeveloper = _amount.div(100); //1%
        uint256 amountForTeam = amountForDeveloper.mul(9); //9%
        _mint(address(owner()), _amount);
        _mint(developer, amountForDeveloper);
        _mint(spendingAndPromotion, amountForTeam);
        emit MintedReward(
            owner(),
            _amount.add(amountForDeveloper).add(amountForTeam)
        );
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
        emit Burned(msg.sender, _amount);
    }
    //Wrapped Ether
    //Ropsten 0xc778417E063141139Fce010982780140Aa0cD5Ab
    //MainNet 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    function openUniswapExchange(address second_token) external onlyOwner {
        require(address(uniswapExchange) == address(0),"Uniswap Exchange already opened!");
        uniswapExchange = IUniswapV2Pair(factory.getPair(address(this), second_token));
        require(address(uniswapExchange) != address(0), "Invalid uniswapExchange");
    }
   
    /**
     * @notice external price function for Token to Ether trades with an exact output.
     * @param eth_bought Amount of output Ether.
     * @return Amount of Tokens needed to buy output Ether.
     */
    function getTokensNeededToBuy(uint256 eth_bought)
        external
        view
        returns (uint256)
    {
        if (address(uniswapExchange) == address(0) || eth_bought <= 0) {
            return 0;
        }
        (uint112 reserves0, uint112 reserves1,) = uniswapExchange.getReserves();
        (uint112 reserveIn, uint112 reserveOut) = uniswapExchange.token0() == address(this) ? (reserves0, reserves1) : (reserves1, reserves0);
        if (reserveIn > 0 && reserveOut > 0 && eth_bought < reserveOut){
            uint256 numerator = eth_bought.mul(1000).mul(reserveIn);
            uint256 denominator = uint256(reserveOut).sub(eth_bought).mul(997);
            return (numerator / denominator).add(1);
        }else{
            return 0;
        }

        
    }
}