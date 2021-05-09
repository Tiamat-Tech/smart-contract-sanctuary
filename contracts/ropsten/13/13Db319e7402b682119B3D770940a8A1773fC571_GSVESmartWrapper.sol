// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
* @dev interface to allow gas tokens to be burned from the wrapper
*/
interface IFreeUpTo {
    function freeUpTo(uint256 value) external returns (uint256 freed);
}

/**
* @dev interface to allow gsve to be burned for upgrades
*/
interface IGSVEToken {
    function burnFrom(address account, uint256 amount) external;
}


/**
* @dev The v1 smart wrapper is the core gas saving feature
* it can interact with other smart contracts
* it burns gas to save on the transaction fee
* only the owner/deployer of the smart contract can interact with it
* only the owner can send tokens from the address (smart contract)
* only the owner can withdraw tokens of any type, and this goes directly to the owner.
*/
contract GSVESmartWrapper {
    using Address for address;
    mapping(address => uint256) public _compatibleGasTokens;
    mapping(address => uint256) public _freeUpValue;
    address public GSVEToken;
    bool public _upgraded;
    bool public _inited;
    address private _owner;

    constructor (address _GSVEToken) public {
        init(msg.sender, _GSVEToken);
    }



    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     * also sets the GSVE token reference
     */
    function init (address initialOwner, address _GSVEToken) public {
        require(_owner == address(0), "This contract is already owned");
        _owner = initialOwner;
        GSVEToken = _GSVEToken;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    /**
    * @dev allow the contract to recieve funds. 
    * This will be needed for dApps that check balances before enabling transaction creation.
    */
    receive() external payable{}

    /**
    * @dev sets the contract as inited
    */
    function setInited() public {
        _inited = true;
    }

    /**
    * @dev function to enable gas tokens.
    * by default the wrapped tokens are added when the wrapper is deployed
    * using efficiency values based on a known token gas rebate that we store on contract.
    * DANGER: adding unvetted gas tokens that aren't supported by the protocol could be bad!
    * costs 5 gsve to add custom gas tokens if done after the wallet is inited
    */
    function addGasToken(address gasToken, uint256 freeUpValue) public onlyOwner{
        if(_inited){
            IGSVEToken(GSVEToken).burnFrom(msg.sender, 5*10**18);
        }
        _compatibleGasTokens[gasToken] = 1;
        _freeUpValue[gasToken] = freeUpValue;
    }

    /**
    * @dev function to 'upgrade the proxy' by enabling unwrapped gas token support
    * the user must burn 10 GSVE to upgrade the proxy.
    */
    function upgradeProxy() public onlyOwner{
        require(_upgraded == false, "GSVE: Wrapper Already Upgraded.");
        IGSVEToken(GSVEToken).burnFrom(msg.sender, 10*10**18);

        // add CHI gas token
        _compatibleGasTokens[0x0000000000004946c0e9F43F4Dee607b0eF1fA1c] = 1;
        _freeUpValue[0x0000000000004946c0e9F43F4Dee607b0eF1fA1c] = 24000;

        // add GST2 gas token
        _compatibleGasTokens[0x0000000000b3F879cb30FE243b4Dfee438691c04] = 1;
        _freeUpValue[0x0000000000b3F879cb30FE243b4Dfee438691c04] = 24000;

        // add GST1 gas token
        _compatibleGasTokens[0x88d60255F917e3eb94eaE199d827DAd837fac4cB] = 1;
        _freeUpValue[0x88d60255F917e3eb94eaE199d827DAd837fac4cB] = 15000;

        _upgraded = true;
    }

    /**
    * @dev checks if the gas token is supported
    */
    function compatibleGasToken(address gasToken) public view returns(uint256){
        return _compatibleGasTokens[gasToken];
    }

    /**
    * @dev GSVE moddifier that burns supported gas tokens around a function that uses gas
    * the function calculates the optimal number of tokens to burn, based on the token specified
    */
    modifier discountGas(address gasToken) {
        if(gasToken != address(0)){
            require(_compatibleGasTokens[gasToken] == 1, "GSVE: incompatible token");
            uint256 gasStart = gasleft();
            _;
            uint256 gasSpent = 21000 + gasStart - gasleft() + 16 * msg.data.length;
            IFreeUpTo(gasToken).freeUpTo((gasSpent + 14000) / _freeUpValue[gasToken]);
        }
        else {
            _;
        }
    }
    
    /**
    * @dev the wrapTransaction function interacts with other smart contracts on the users behalf
    * this wrapper works for any smart contract
    * as long as the dApp/smart contract the wrapper is interacting with has the correct approvals for balances within this wrapper
    * if the function requires a payment, this is handled too and sent from the wrapper balance.
    */
    function wrapTransaction(bytes calldata data, address contractAddress, uint256 value, address gasToken) external discountGas(gasToken) payable onlyOwner{
        if(!contractAddress.isContract()){
            return;
        }

        if(value > 0){
            contractAddress.functionCallWithValue(data, value, "GS: Error forwarding transaction");
        }
        else{
            contractAddress.functionCall(data, "GS: Error forwarding transaction");
        }
    }

    /**
    * @dev function that the user can trigger to withdraw the entire balance of their wrapper back to themselves.
    */
    function withdrawBalance() public onlyOwner{
        owner().call{value: address(this).balance, gas:gasleft()}("");
    }

    /**
    * @dev function that the user can trigger to withdraw an entire token balance from the wrapper to themselves
    */
    function withdrawTokenBalance(address token) public onlyOwner{
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(owner(), balance);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}