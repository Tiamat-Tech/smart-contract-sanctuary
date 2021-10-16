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
    
    struct storeParams {
        address user;
        uint256 amount;
        uint256 deadline;
        bytes signature; 
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    function convert(storeParams memory vars) public whenNotPaused{
        require(block.timestamp < vars.deadline, "Expired");
        require(!isSigned[vars.signature], "already used");
        bytes32 hash_ = keccak256(abi.encodePacked(
            SIGNATURE_PERMIT_TYPEHASH,
            address(this),
            vars.user,
            vars.amount,
            vars.deadline,
            getChainID()
        ));
        require(signVerify(ECDSA.toEthSignedMessageHash(hash_),vars.signature), "Sign Error");
        
        isSigned[vars.signature] = true;
        
        token.transfer(vars.user,vars.amount);
    }
    
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

    function transferTokenOwnerShip(address newOwner) public onlyOwner {
        token.transferOwnership(newOwner);
    }
    
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
    
    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
      
    function toSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
    
    function signVerify(bytes32 hash,bytes memory signature) public view returns (bool) {
        return signerAddress.isValidSignatureNow(hash,signature);
    }
    
    function signerAddressUpdate(address account) public onlyOwner {
        signerAddress = account;
    }
    
    function devAddressUpdate(address account) public onlyOwner{
        devAddress = account;
    }
    
    function bnbEmergencySafe(address account,uint256 amount) public onlyOwner {
        payable(account).transfer(amount);
    }
    
    function tokenEmergencySafe(address tokenAddr,address account,uint256 amount) public onlyOwner {
        IERC20(tokenAddr).transfer(account,amount);
    }

}