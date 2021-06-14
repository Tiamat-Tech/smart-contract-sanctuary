pragma solidity >=0.4.22 <0.8.0;

import "./CloneFactory.sol";
import "./TokenForClone.sol";

contract TokenFactory is CloneFactory, Ownable {
    TokenForClone[] public tokenAddresses;
    event TokenCreated(TokenForClone newToken);

    address public libraryAddress;
    address private tokenOwner;

    constructor(address _tokenOwner) public {
        tokenOwner = _tokenOwner;
    }

    function setLibraryAddress(address _libraryAddress) external onlyOwner {
        libraryAddress = _libraryAddress;
    }

    function createToken(string memory _name, string memory _symbol, uint8 _decimal, uint256 initialBalance) public {
        TokenForClone newToken = TokenForClone(
            createClone(libraryAddress)
        );

        newToken.initialize(_name, _symbol, _decimal, initialBalance, msg.sender);

        tokenAddresses.push(newToken);
        emit TokenCreated(newToken);
    }

    function getMetaCoins() external view returns (TokenForClone[] memory) {
        return tokenAddresses;
    }
}