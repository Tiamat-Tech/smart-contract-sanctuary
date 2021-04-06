pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/Constants.sol";
import "./libs/IPancakeRouter02.sol";
import "./libs/IMasterChef.sol";
import "./libs/IRewardPool.sol";

// CHANGE FOR BSC
//import "./libs/SafeBEP20.sol";
//import "./libs/IBEP20.sol";

/*
Note: This contract is ownable, therefor the owner wields a good portion of power.
The owner will be able to initialize the reward pool.
Initiate emergency transfer to masterChef contract.
Emergency swap to BUSD.
Emergency remove liquidity.
Even if fraudalent swapping is caused by the owner, he will only be able to transfer BUSD away.
The BUSD address is a set constant and not changeable.
Thus the owner has only the power to withhold all the funds in this contract
but can only transfer them to the masterChef contract.
After contract is proven to be bug free, ownership will be transferred to another contract 
to automatically govern this one and restrict access to the emergency functionality.

This contract uses the UniSwapRouter interfaces to automatically: 
    removeAllLiquidity of LP tokens
    swap all tokens to BUSD
    swap 20% to Lotl
    burn that lotl
    transfer the remaining BUSD to MasterChef
    initiate reward distribution
*/

contract RewardPool is Ownable, Constants, IRewardPool {
    using SafeERC20 for IERC20;
    IMasterChef public chef;
    address public lotlToken;

    // Visibility will change after testing is done.
    // Only functions ownable will be:
    // swapToBusd
    // removeLiquidity
    // processFees
    // transferAllBUSD
    // initiateRewards
    // setRouterPath

    // Tokens associated with the LP pair. 
    struct LpTokenPair {
    	IERC20 tokenA;
        IERC20 tokenB;

    }
    // All different LP tokens registered.
    IERC20[] public lptoken;
	// All different tokens registered.
	IERC20[] public tokens; 
    // Swapping paths.
    mapping(address => mapping(address => address[])) paths;
	// Maps the LP pair to the tokens 
	mapping (IERC20 => LpTokenPair) lpPairs;
	// Used to determine wether a pool has already been added.
    mapping(IERC20 => bool) public poolExistence;
    // Used to determine wether a token has already been added.
    mapping(IERC20 => bool) public tokenExistence;

    // Modifier to allow only new pools being added.
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    event BurnLotl(address indexed lotl, uint256 amount);

  	constructor(address _chef, address _lotl) public {
  		chef = IMasterChef(_chef);
        lotlToken = _lotl;


  		 // Sell Tokens Paths BSC
         /*
		paths[wbnbAddr][busdAddr] = [wbnbAddr, busdAddr];
		paths[usdtAddr][busdAddr] = [usdtAddr, busdAddr];
		paths[btcbAddr][busdAddr] = [btcbAddr, wbnbAddr, busdAddr];
		paths[wethAddr][busdAddr] = [wethAddr, wbnbAddr, busdAddr];
		paths[daiAddr][busdAddr] = [daiAddr, busdAddr];
		paths[usdcAddr][busdAddr] = [usdcAddr, busdAddr];
		paths[dotAddr][busdAddr] = [dotAddr, wbnbAddr, busdAddr];
		paths[cakeAddr][busdAddr] = [cakeAddr, wbnbAddr, busdAddr];
		paths[worldAddr][busdAddr] = [worldAddr, wbnbAddr, busdAddr];
		paths[gnyAddr][busdAddr] = [gnyAddr, wbnbAddr, busdAddr];
		paths[vaiAddr][busdAddr] = [vaiAddr, ustAddr, wbnbAddr, busdAddr];
		paths[bethAddr, busdAddr] = [bethAddr, wethAddr, wbnbAddr, busdAddr];
        */

        // Ropsten paths
        paths[wbnbAddr][busdAddr] = [wbnbAddr, busdAddr];
        paths[lotlToken][busdAddr] = [lotlToken, busdAddr];
        paths[busdAddr][lotlToken] = [busdAddr, lotlToken];

  		}




  	// Function to add router paths, needed if new LP pairs with new tokens are added.
  	function setRouterPath(address inputToken, address outputToken, address[] calldata _path, bool overwrite) external override onlyOwner {
        address[] storage path = paths[inputToken][outputToken];
        uint256 length = _path.length;
        if (!overwrite) {
            require(length == 0, "setRouterPath: ALREADY EXIST");
        }
        for (uint8 i = 0; i < length; i++) {
            path.push(_path[i]);
        }
    }

    // Uses input token and output token to determine best swapping path.
    function getRouterPath(address inputToken, address outputToken) private view returns (address[] storage){
        address[] storage path = paths[inputToken][outputToken];
        require(path.length > 0, "getRouterPath: MISSING PATH");
        return path;
    }

  	

    // Given X input tokens, return Y output tokens without concern about minimum/slippage.
    function swapToBusd(IERC20 _inputToken, uint256 _amount) public onlyOwner {
        _inputToken.approve(routerAddr, _amount);
        IPancakeRouter02(routerAddr).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            getRouterPath(address(_inputToken), busdAddr),
            address(this),
            getTxDeadline()
        );
    }

    // Swaps BUSD to LOTL without concern about minimum/slippage.
    function swapToLotl(uint256 _amount) public onlyOwner {
        IERC20(busdAddr).approve(routerAddr, _amount);
        IPancakeRouter02(routerAddr).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            getRouterPath(busdAddr, lotlToken),
            address(this),
            getTxDeadline()
        );
    }

    // Burns LOTL
    function burnLotl() public {
        uint256 amount = IERC20(lotlToken).balanceOf(address(this));
        IERC20(lotlToken).transfer(burnAddr,amount);
        emit BurnLotl(lotlToken, amount);
    }
    

    // Given X input LP tokens, returns X,Y output tokens without concern about minimum/slippage.
    function removeLiquidity(IERC20 _lpToken, uint256 _amount) public onlyOwner {
        _lpToken.approve(routerAddr, _amount);
    	IERC20 _tokenA = lpPairs[_lpToken].tokenA;
    	IERC20 _tokenB = lpPairs[_lpToken].tokenB;
        IPancakeRouter02(routerAddr).removeLiquidity(
            address(_tokenA),
            address(_tokenB),
            _amount,
            0,
            0,
            address(this),
            getTxDeadline()
        );
    }

    // Returns current time + 60 second.
    function getTxDeadline() private view returns (uint256){
        return block.timestamp + 60;

    }

    // This function will be called every 7 days.
    // Processes the fess.
    function processFees() public override onlyOwner{
    	removeAllLiquidity;
        swapAllToBUSD;
        burn20Percent;
        transferAllBUSD;
        initiateRewards;
    }

    // Transfers all BUSD to MasterChef
    function transferAllBUSD () public onlyOwner {
        uint256 amount = IERC20(busdAddr).balanceOf(address(this));
        IERC20(busdAddr).approve(address(chef), amount);
        IERC20(busdAddr).transfer(address(chef), amount);
    }
    

    // Swaps 20% of the BUSD to Lotl and burns them.
    function burn20Percent() public onlyOwner {
        uint256 toBurn = IERC20(busdAddr).balanceOf(address(this)) / 5;
        swapToLotl(toBurn);
        burnLotl();
    }
    

    // Swaps all LP tokens to their composits.
    function removeAllLiquidity () public onlyOwner {
        for(uint8 i; i < lptoken.length; i++)
        {
            uint256 lpAmount = lptoken[i].balanceOf(address(this));
            if(lpAmount > 0)
            {
                removeLiquidity(lptoken[i], lpAmount);
            }
        }
    }

    // Swaps all tokens in the contract to BUSD.
    function swapAllToBUSD () public onlyOwner {
        for(uint8 i; i < tokens.length; i++){
            uint256 tokenAmount = tokens[i].balanceOf(address(this));
            if(tokenAmount / 1e18 > 0 && tokens[i] != IERC20(busdAddr)){
                swapToBusd(tokens[i], tokenAmount);
            }
        }
    }

    // Initiates the reward calculation in the MasterChefContract
    function initiateRewards () public onlyOwner {
        chef.calculateRewardPool();
    }
    
    

   	// Add new LP tokens and tokens to the existing storage, can only be called via MasterChef contract.
    function addLpToken(IERC20 _lpToken, IERC20 _tokenA, IERC20 _tokenB, bool isLPToken) public override nonDuplicated(_lpToken){
        if(isLPToken)
        {
            require(msg.sender == address(chef) ,"chef: u no master");
    		lptoken.push(_lpToken);
    		poolExistence[_lpToken] = true;
    		LpTokenPair storage lp = lpPairs[_lpToken];
    		lp.tokenA = _tokenA;
    		lp.tokenB = _tokenB;
    		if(!tokenExistence[_tokenB])
            {
    			tokens.push(_tokenB);
    			tokenExistence[_tokenB] = true;
    		}
    		if(!tokenExistence[_tokenA])
            {
    			tokens.push(_tokenA);
    			tokenExistence[_tokenA] = true;
    		}
        }

        else 
        {
            if(!tokenExistence[_lpToken])
            {
            tokens.push(_lpToken);
            tokenExistence[_lpToken] = true;
            }

    	}
    }


    
    

}