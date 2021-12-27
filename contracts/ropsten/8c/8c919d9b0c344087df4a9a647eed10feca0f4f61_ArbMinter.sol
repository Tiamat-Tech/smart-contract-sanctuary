/**
 *Submitted for verification at Etherscan.io on 2021-12-27
*/

pragma solidity 0.8.7;

interface ISLP{
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function token0() external view returns(address);
    function token1() external view returns(address);
}

pragma solidity 0.8.7;

interface IDAI{
    function mint(uint amount) external;
}

pragma solidity 0.8.7;

interface ERC20{
    function decimals() external view returns(uint8);
    function mint(address to, uint amount) external;
}

pragma solidity 0.8.7;

contract ArbMinter{

    IDAI public DAI = IDAI(0xf80A32A835F79D7787E8a8ee5721D0fEaFd78108);    

    function fixStablePool(ISLP _slp) external {
        //Get Ratio
        (uint112 reserve0,uint112 reserve1,) = _slp.getReserves();
        
        if(ERC20(_slp.token0()).decimals() == 6){
            reserve0 = reserve0*1e12;
        }

        if(ERC20(_slp.token1()).decimals() == 6){
            reserve0 = reserve0*1e12;
        }

        if(reserve0 == reserve1){
            return;
        }
        if(reserve0 > reserve1){
            //Mint USDC/DAI
            mintAndDeposit((reserve0-reserve1),_slp.token0(),address(0),_slp);
        }
        else{
            //Mint bUSD
            mintAndDeposit((reserve1-reserve0),address(0),_slp.token1(),_slp);
        }
        
    }

    function mintAndDeposit(uint256 _amount, address _token0, address _token1, ISLP _slp) internal{
        address sellToken;
        if(_token0 == address(0)){
            sellToken = _token1;
            //Mint DAI
            if(sellToken == address(DAI)){
                DAI.mint(_amount);
            }
            //Mint other ERC20s
            else{
                ERC20(sellToken).mint(address(this),_amount);
            }
            //Deposit (trade) token into pool
            _slp.swap(0,_amount, address(this), "");
        }
        else{
            sellToken = _token0;
            //Mint DAI
            if(sellToken == address(DAI)){
                DAI.mint(_amount);
            }
            //Mint other ERC20s
            else{
                ERC20(sellToken).mint(address(this),_amount);
            }
            //Deposit (trade) token into pool
            _slp.swap(_amount,0, address(this), "");
        }
    }
}