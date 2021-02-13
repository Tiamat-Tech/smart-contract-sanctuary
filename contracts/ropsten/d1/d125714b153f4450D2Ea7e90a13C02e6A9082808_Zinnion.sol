pragma solidity ^0.6.12;

import "./aave/FlashLoanReceiverBaseV2.sol";
import "./interfaces/ILendingPoolAddressesProviderV2.sol";
import "./interfaces/ILendingPoolV2.sol";
import './uniswap/IUniswapV2Router02.sol';

contract Zinnion is FlashLoanReceiverBaseV2, Withdrawable {
    string public message;

    mapping(address => bool) private whitelistedMap;
    address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address internal constant SUSHISWAP_ROUTER_ADDRESS = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    IUniswapV2Router02 public uniswapRouter;
    IUniswapV2Router02 public sushiswapRouter;
    
    // EVENTS   
    event Whitelisted(address indexed account, bool isWhitelisted);
    event Swap(address indexed account, address[] indexed path, uint amountIn, uint amountOut);
    event Logging(string message);

    constructor(address _addressProvider) FlashLoanReceiverBaseV2(_addressProvider) public {
        addAddress(msg.sender);
        message = "Hello World!";
        uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
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
    function sabendos(
        uint amountIn,
        address[] calldata path,
        uint[] calldata path_min_accept,
        uint[] calldata exchanges,
        bool weth
    ) external onWhiteList {
        bool go_back_to_eth = false;
        for (uint i=0; i< path.length; i++) {
            // Uni Swap
            if (exchanges[0] == 0){
                // We need to change ETH to WETH
                if (i == 0) {
                    if (weth) {
                        emit Logging("WRAPPING ETH TO WETH");
                        //emit LoggingUint(amountIn);
                        // go_back_to_eth = true;
                        // address[] memory wethpath = new address[](2);
                        // wethpath[0] = uniswapRouter.WETH();
                        // wethpath[1] = path[i+1];
                        // uint deadline = block.timestamp + 15;
                        // IERC20(path[0]).approve(address(uniswapRouter), amountIn);
                        // uint256[] memory amounts = getAmountOut(amountIn, path); 
                        // uniswapRouter.swapETHForExactTokens.value(amounts)(amounts, wethpath, address(this), deadline);                                                                    
                    }
                }

                // require(
                //     IERC20(path[i]).approve(address(uniswap), amountIn),
                //     "Could not approve sell"
                // );

                //emit Logging("approved");

                // address[] memory pair;
                // pair[0] = path[i];
                // pair[1] = path[i+1];

                //uint256[] memory amounts = uniswap.getAmountsOut(amountIn, path);

                if (path.length == i+1){
                    if (go_back_to_eth){
                        // uniswap.swapExactTokensForETH (
                        //     amountIn, 
                        //     path_min_accept[i] * 10 ** 18, 
                        //     getPathForTokenToETH(path[i+1],exchanges[i]), 
                        //     address(this), 
                        //     deadline
                        // );                   
                        // since we are path.length == i+1 we are done with all swaps
                        break;                         
                    }                   
                }

                // uniswap.swapExactTokensForTokens(
                //     amountIn,
                //     path_min_accept[i],
                //     pair,
                //     address(this),
                //     deadline
                // );   

                if (path.length == i+1){
                        break;                         
                }
            } 

            // Sushi Swap
            if (exchanges[0] == 0){

            }                     
        }
    }

    // SWAP
    function swapTokensForTokens(
        uint amountIn,
        address[] calldata path      
    ) external onWhiteList {
        for (uint i=0; i< path.length; i++) {
            if (path.length > i+1){
                address[] memory execution_path = new address[](2);
                execution_path[0] = path[i];
                execution_path[1] = path[i+1];

                IERC20(execution_path[i]).approve(address(uniswapRouter), amountIn);
            
                uint256[] memory amounts = getAmountOut(amountIn, execution_path); 

                uniswapRouter.swapExactTokensForTokens(
                    amountIn,
                    amounts[amounts.length - 1],
                    execution_path,
                    address(this),
                    block.timestamp + 300
                );
                
                emit Swap(msg.sender, execution_path, amountIn, amounts[amounts.length - 1]);
            }
        }
    }
    
    // UTILS    
    function getAmountOut(uint amountIn, address[] memory path) private returns(uint256[] memory){
        return uniswapRouter.getAmountsOut(amountIn, path);
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