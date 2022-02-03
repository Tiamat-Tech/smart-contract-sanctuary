pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Pausable.sol";
import "./IBlackList.sol";
import "./EIP2612.sol";
import "./EIP3009.sol";

contract BITL is
    Ownable,
    ERC20,
    EIP3009,
    Pausable,
    EIP2612
{
    IBlackList bl;

    constructor(address _blackList, address _pauser) ERC20("Bitanica Lari", "BITL") {
        bl = IBlackList(_blackList);
        pauser = _pauser;
    }

    function transfer(address _recipient, uint256 _amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(
            !bl.isBlackListed(address(this), msg.sender) &&
                !bl.isBlackListed(address(this), _recipient),
            "Sender or recipient on blacklist"
        );

        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override 
        whenNotPaused
      returns (bool) {
        require(
            !bl.isBlackListed(address(this), _from) &&
                !bl.isBlackListed(address(this), _to),
            "Sender or recipient on blacklist"
        );

        transferFrom(_from, _to, _amount);
    }

    function mint(address _recipient, uint256 _amount) public onlyOwner whenNotPaused {
        require(
            !bl.isBlackListed(address(this), _recipient),
            "Recipient on the blacklist"
        );
        _mint(_recipient, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyOwner whenNotPaused {
        _burn(_account, _amount);
    }

    /*
     * @notice Increase the allowance by a given increment
     * @param spender   Spender's address
     * @param increment Amount of increase in allowance
     * @return True if successful
     */
    function increaseAllowance(address _spender, uint256 _increment)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(bl.isBlackListed(address(this), _spender) && bl.isBlackListed(address(this), msg.sender), "Sender or owner in blacklist");
        // whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender)
        super.increaseAllowance(_spender, _increment);
        return true;
    }

    /*
     * @notice Decrease the allowance by a given decrement
     * @param spender   Spender's address
     * @param decrement Amount of decrease in allowance
     * @return True if successful
     */
    function decreaseAllowance(address _spender, uint256 _decrement)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(bl.isBlackListed(address(this), _spender) && bl.isBlackListed(address(this), msg.sender), "Sender or owner in blacklist");
        //  whenNotPaused notBlacklisted(msg.sender) notBlacklisted(spender)
        super.decreaseAllowance(_spender, _decrement);
        return true;
    }

    function transferPermit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _transferWithAuthorization(
            _owner,
            _spender,
            _value,
            _validAfter,
            _validBefore,
            _nonce,
            v,
            r,
            s
        );
    }

    function approvePermit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 v, bytes32 r, bytes32 s) external {
        require(bl.isBlackListed(address(this), _owner) && bl.isBlackListed(address(this), _spender), "Spender or owner in blacklist");
        _permit(_owner, _spender, _value, _deadline, v, r, s);
    }
}