pragma solidity 0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlackList is Ownable {
    mapping(address => bool) public blackListed;
    event BlackListAdded(address indexed user);
    event BlackListRemoved(address indexed user);

    /**
     * Add contract addresses to the blacklist
     */

    function addToBlackList(address _user) public onlyOwner {
        require(!blackListed[_user], "already blackListed");
        blackListed[_user] = true;
        emit BlackListAdded(_user);
    }

    function addAddressesToBlackList(address[] memory _userAddresses) public onlyOwner {
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            addToBlackList(_userAddresses[i]);
        }
    }

    function checkBlackList(address _user) public view returns (bool) {
        return blackListed[_user];
    }

    /**
     * Remove a contract addresses from the blacklist
     */

    function removeFromBlackList(address _user) external onlyOwner {
        require(blackListed[_user], "user not in blacklist");
        blackListed[_user] = false;
        emit BlackListRemoved(_user);
    }
}