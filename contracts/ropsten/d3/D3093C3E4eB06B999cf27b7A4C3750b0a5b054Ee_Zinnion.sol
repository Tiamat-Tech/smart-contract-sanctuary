// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./aave/FlashLoanReceiverBaseV2.sol";
import "./interfaces/ILendingPoolAddressesProviderV2.sol";
import "./interfaces/ILendingPoolV2.sol";
import './uniswap/IUniswapV2Router02.sol';

contract Zinnion is FlashLoanReceiverBaseV2, Withdrawable {
    string public message;

    mapping(address => bool) private whitelistedMap;

    address constant uniswapAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant sushiswapAddress = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    IUniswapV2Router02 uniswap = IUniswapV2Router02(uniswapAddress);
    IUniswapV2Router02 sushiswap = IUniswapV2Router02(sushiswapAddress);

    // EVENTS   
    event Whitelisted(address indexed account, bool isWhitelisted);
    event Swap(address indexed account, address[] indexed path, uint amountIn, uint amountOut);
    event Logging(string message);

    constructor(address _addressProvider) FlashLoanReceiverBaseV2(_addressProvider) public {
        addAddress(msg.sender);
        message = "Hello World!";
    }

    // MODIFIERS
    modifier onWhiteList {
        require(whitelistedMap[msg.sender]);
        _;
    }    

    // Updates message variable
    function update(string memory newMessage) public {
        message = newMessage;
    }

    // WHITE LIST
    function whiteListed(address _address) public view returns (bool) {
        return whitelistedMap[_address];
    }

    function addAddress(address _address) public onlyOwner {
        require(whitelistedMap[_address] != true);
        whitelistedMap[_address] = true;
        emit Whitelisted(_address, true);
    }

    function removeAddress(address _address) public onlyOwner {
        require(whitelistedMap[_address] != false);
        whitelistedMap[_address] = false;
        emit Whitelisted(_address, false);
    }

    // WITHDRAW
    function withdrawToken(address token) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) > 0);
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    // GET BALANCE
    function getTokenBalance(address token) public view onWhiteList returns (uint256){
        return IERC20(token).balanceOf(address(this));
    }

    // SWAP
    function executeArbitrage(
        uint256 amountIn,
        address[] calldata path,
        uint256[] calldata path_min_accept,
        uint256[] calldata exchanges
    ) external onWhiteList {

        uint256 deadline = getDeadline();

        bool go_back_to_eth = false;
        for (uint i=0; i< path.length; i++) {

            // Uni Swap
            if (exchanges[0] == 0){
                // We need to change ETH to WETH
                if (i == 0) {
                    if (keccak256(abi.encodePacked(path[i])) == keccak256("c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")) {
                        Logging("WRAPPING ETH TO WETH");
                        go_back_to_eth = true;
                        uniswap.swapETHForExactTokens{ 
                            value: amountIn 
                        }(
                            amountIn, 
                            getPathForETHToToken(path[i],exchanges[i]), 
                            address(this), 
                            deadline
                        ); 
                    }
                }

                Logging("begin");

                require(
                    IERC20(path[i]).approve(address(uniswap), amountIn),
                    "Could not approve sell"
                );

                Logging("approved");

                address[] memory pair;
                pair[0] = path[i];
                pair[1] = path[i+1];

                //uint256[] memory amounts = uniswap.getAmountsOut(amountIn, path);

                if (path.length == i+1){
                    if (go_back_to_eth){
                        uniswap.swapExactTokensForETH (
                            amountIn, 
                            path_min_accept[i] * 10 ** 18, 
                            getPathForTokenToETH(path[i+1],exchanges[i]), 
                            address(this), 
                            deadline
                        );                   
                        // since we are path.length == i+1 we are done with all swaps
                        break;                         
                    }                   
                }

                uniswap.swapExactTokensForTokens(
                    amountIn,
                    path_min_accept[i],
                    pair,
                    address(this),
                    deadline
                );   

                if (path.length == i+1){
                        break;                         
                }
            } 

            // Sushi Swap
            if (exchanges[0] == 0){

            }                     
        }
    }

    function toAsciiString(address x) public view returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
            byte hi = byte(uint8(b) / 16);
            byte lo = byte(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
        return string(s);
    }

    function char(byte b) public view returns (byte c) {
        if (uint8(b) < 10) return byte(uint8(b) + 0x30);
        else return byte(uint8(b) + 0x57);
    }

    /**
        Using a WETH wrapper here since there are no direct ETH pairs in Uniswap and SushiSwap
     */
    function getPathForETHToToken(address ERC20Token, uint256 exchange) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        if (exchange == 0) {
            path[0] = uniswap.WETH();
        } else if (exchange == 1){
            path[0] = sushiswap.WETH();
        } else {
            revert();
        }
        path[1] = ERC20Token;
        return path;
    }

    /**
        Using a WETH wrapper to convert ERC20 token back into ETH
     */
     function getPathForTokenToETH(address ERC20Token, uint256 exchange) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = ERC20Token;

        if (exchange == 0) {
            path[1] = uniswap.WETH();
        }else if (exchange == 1){
            path[1] = sushiswap.WETH();
        }else{
            revert();
        }  
        return path;
    }
    
    // FLASH LOAN
    /**
     * @dev This function must be called only be the LENDING_POOL and takes care of repaying
     * active debt positions, migrating collateral and incurring new V2 debt token debt.
     *
     * @param assets The array of flash loaned assets used to repay debts.
     * @param amounts The array of flash loaned asset amounts used to repay debts.
     * @param premiums The array of premiums incurred as additional debts.
     * @param initiator The address that initiated the flash loan, unused.
     * @param params The byte array containing, in this case, the arrays of aTokens and aTokenAmounts.
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {

        //
        // This contract now has the funds requested.
        // Your logic goes here.
        //
        
        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.
        
        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }
        
        return true;
    }

    function _flashloan(address[] memory assets, uint256[] memory amounts) internal {
        address receiverAddress = address(this);

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        uint256[] memory modes = new uint256[](assets.length);

        // 0 = no debt (flash), 1 = stable, 2 = variable
        for (uint256 i = 0; i < assets.length; i++) {
            modes[i] = 0;
        }

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function getDeadline() internal view returns (uint256) {
        return block.timestamp + 3000;
    }

    /*
     *  Flash multiple assets 
     */
    function flashloan(address[] memory assets, uint256[] memory amounts) public onlyOwner {
        _flashloan(assets, amounts);
    }

    /*
     *  Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan(address _asset) public onlyOwner {
        bytes memory data = "";
        uint amount = 1 ether;

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        _flashloan(assets, amounts);
    }
}