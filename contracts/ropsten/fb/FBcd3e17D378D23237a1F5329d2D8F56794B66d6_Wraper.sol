// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
 
 

contract Wraper is  AccessControlEnumerable,  ERC20Pausable  {
  
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    IERC20 public IERC20_A;
    IERC20 public IERC20_B;

    modifier acceptedToekns(IERC20 _token){
        require(_token == IERC20_A || _token ==IERC20_B ,"Invalid Token");
        _;
    }
    
constructor(IERC20 _A,IERC20 _B) ERC20("Wraper","C") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
         
        _setupRole(PAUSER_ROLE, _msgSender());
        IERC20_A=_A;
        IERC20_B=_B;
}
 
    function swap(IERC20 _token,uint256 _amount) acceptedToekns(_token) public  {
        require(!paused(), "Wraper: token swap while paused");       
        _token.transferFrom(msg.sender,address(this), _amount);
        _mint(msg.sender,_amount);

    }

    function redeem(IERC20 _token,uint256 _amount) acceptedToekns(_token) public {
        require(!paused(), "Wraper: token redeem while paused");  
        IERC20(address(this)).transferFrom(msg.sender,address(this), _amount);       
        _token.transfer(msg.sender, _amount);         
        _burn(address(this),_amount);

    }
 /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override( ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }

}