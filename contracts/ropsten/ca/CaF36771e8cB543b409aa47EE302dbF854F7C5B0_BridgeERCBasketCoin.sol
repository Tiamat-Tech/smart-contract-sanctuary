// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;


import "./token/IERC20.sol";
import "./security/Pausable.sol"; 
import "./access/Ownable.sol";
import "./utils/SignatureChecker.sol";

contract BridgeERCBasketCoin is  Pausable, Ownable {
    
    using SignatureChecker for address;
    
    address public signerAddress;
    address public devAddress;
    
    IERC20 public token;

    mapping (address => uint256) public userBurnFee;

    uint256 public totalBurnFee;
    
    bytes32 public constant SIGNATURE_PERMIT_TYPEHASH = keccak256("address user,uint256 amount,uint256 deadline,bytes signature");
    
    mapping (bytes => bool) private isSigned;
    
    constructor(address _devAddress,address _signerAddress,address _tokenAddress) {
        devAddress = _devAddress;
        signerAddress = _signerAddress;
        token = IERC20(_tokenAddress);
    }

    /**
     * @dev Triggers stopped state.
     * 
     * Can only be called by the current owner.
     * 
     * Requirements:
     *
     * - The contract must not be paused.
    */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Triggers normal state.
     * 
     * Can only be called by the current owner.
     * 
     * Requirements:
     *
     * - The contract must not be unpaused.
    */
    function unpause() public onlyOwner {
        _unpause();
    }
    /**
        * @dev Decodes params information encoded in the convert params
        * @param params Additional variadic field to include extra params. Expected parameters:
        * - `user` - account of the user
        * - `amount` -  number token to be generate.
        * - `deadline` - sign valid duration.
        * - `slot` - random number
        * - `signature` - param for the permit signature
    */
    function decodeParams(bytes memory params) internal pure returns(address user,uint256 amount,uint256 slot,uint256 deadline,bytes memory signature){
        return abi.decode(params,(address, uint256, uint256, uint256, bytes));
    }

    /**
     * @dev bridge concept it's execute this function
     * 
     * 
     * Requirements:
     *
     * - `params`-encoded bytes 
     *
    */        
    function convert(bytes memory params) public whenNotPaused{
        (address user,uint256 amount,uint256 slot,uint256 deadline,bytes memory signature) = decodeParams(params);
        require(block.timestamp < deadline, "Expired");
        require(!isSigned[signature], "already used");
        bytes32 hash_ = keccak256(abi.encodePacked(
            SIGNATURE_PERMIT_TYPEHASH,
            address(this),
            user,
            amount,
            slot,
            deadline,
            getChainID()
        ));
        require(signVerify(ECDSA.toEthSignedMessageHash(hash_),signature), "Sign Error");
        
        isSigned[signature] = true;
        
        token.transfer(user,amount);
    }

    /** @dev Destroys `amount` tokens from `account`, reducing 
     * the total supply.
     *
     * Can only be called by the current auth people. 
     * Which means, bridge contract and admin only accessible
     *
     * Requirements:
     *
     * - `user` cannot be the zero address.
     * - `amount` number token to be burned
     */       
    function burn(address user,uint256 amount) public {
        address user_ = _msgSender();
        require(user_ == devAddress || user_ == owner(), "Developer or Admin only accessible");
        
        token.burn(user,amount);
        userBurnFee[user] += amount;
        totalBurnFee += amount;
    }
    
    struct burnStore {
        address user;
        uint256 amount;
    }

    /**
     * @dev Transfers ownership of the token contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferTokenOwnerShip(address newOwner) public onlyOwner {
        token.transferOwnership(newOwner);
    }

    /** @dev Destroys `amount` tokens from `mutilple accounts`, reducing 
     * the total supply.
     *
     * Can only be called by the current auth people. 
     * Which means, bridge contract and admin only accessible
     *
     * Requirements:
     *
     * - `user` cannot be the zero address.
     * - `amount` number token to be burned
     * - `Admin should pass multidimensional array`
     */        
    function multiBurn(burnStore[] memory vars) public {
        address user_ = _msgSender();
        require(user_ == devAddress || user_ == owner(), "Developer or Admin only accessible");
        uint256 length = vars.length;
        
        for(uint256 i;i<length;i++){
            token.burn(vars[i].user,vars[i].amount);
            userBurnFee[vars[i].user] += vars[i].amount;
            totalBurnFee += vars[i].amount;
        }
        
    }


    /** @dev return the current network chain id
     */     
    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */        
    function toSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an signature valid or not
     */      
    function signVerify(bytes32 hash,bytes memory signature) public view returns (bool) {
        return signerAddress.isValidSignatureNow(hash,signature);
    }

    /**
     * @dev Update the signer address.
     * 
     * Can only be called by the current owner.
     * 
     * Requirements:
     *
     * - `account` change the signer address.
    */    
    function signerAddressUpdate(address account) public onlyOwner {
        signerAddress = account;
    }

    /**
     * @dev Update the dev address.
     * 
     * Can only be called by the current owner.
     * 
     * Requirements:
     *
     * - `account` change the dev address.
    */       
    function devAddressUpdate(address account) public onlyOwner{
        devAddress = account;
    }

    /**
     * @dev This function is help to recover the unnecessary or stucked bnb funds.
     * 
     * Can only be called by the current owner. 
     *
     * Requirements:
     *
     * - `user` received address.
     * - `amount` number of tokens.
     */     
    function bnbEmergencySafe(address account,uint256 amount) public onlyOwner {
        payable(account).transfer(amount);
    }

    /**
     * @dev This function is help to recover the unnecessary or stucked token funds.
     * 
     * Can only be called by the current owner. 
     *
     * Requirements:
     *
     * - `token` token contract address.
     * - `user` received address.
     * - `amount` number of tokens.
     */      
    function tokenEmergencySafe(address tokenAddr,address account,uint256 amount) public onlyOwner {
        IERC20(tokenAddr).transfer(account,amount);
    }

}