// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.6.12;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Yokai Mask Names Contract for https://yokai.money
 */
contract NFTNames is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    // Dev address
    address payable public devAddr;

    // Cost of changing the name of a mask
    uint256 public nameChangePrice = 100 * (10 ** 18);

    // Mapping from token ID to mask name
    mapping (uint256 => string) private maskName;

    // Mapping if certain name string has already been reserved
    mapping (string => bool) private nameReserved;

    // Name change token address
    address public nctAddress = 0x83303170c654863Dc266aF70B5f5A8528140d092;

    // Yokai Masks contract address
    address public masksAddress = 0x3eec0a1d71Fb6283A3802323100874C605184EF6;

    // Events
    event NameChange (uint256 indexed _maskIndex, string _newName);

    /**
     * @dev Contract constructor
     */
    constructor() public {
        devAddr = msg.sender;
    }

    /**
     * @dev Returns name of the mask at index.
     */
    function maskNameByIndex(uint256 _index) public view returns (string memory) {
        return maskName[_index];
    }

    /**
     * @dev Returns if the name has been reserved.
     */
    function isNameReserved(string memory _nameString) public view returns (bool) {
        return nameReserved[toLower(_nameString)];
    }

    /**
     * @dev Changes the name for a mask's tokenId
     */
    function changeName(uint256 _tokenId, string memory _newName) public nonReentrant {
        address owner = IERC721(masksAddress).ownerOf(_tokenId);

        require(_msgSender() == owner, "Not owner");
        require(validateName(_newName) == true, "Invalid name");
        require(sha256(bytes(_newName)) != sha256(bytes(maskName[_tokenId])), "Same name");
        require(isNameReserved(_newName) == false, "Name reserved");

        IERC20(nctAddress).transferFrom(msg.sender, devAddr, nameChangePrice);

        // If already named, remove old name reservation
        if (bytes(maskName[_tokenId]).length > 0) {
            toggleReserveName(maskName[_tokenId], false);
        }

        toggleReserveName(_newName, true);
        maskName[_tokenId] = _newName;

        emit NameChange(_tokenId, _newName);
    }

    /**
     * @dev Reserves the mask name if isReserve is set to true, removes the reservation if set to false
     */
    function toggleReserveName(string memory _str, bool _isReserve) internal {
        nameReserved[toLower(_str)] = _isReserve;
    }

    /**
     * @dev Update dev address by the previous dev
     */
    function setDev(address payable _devAddr) external onlyOwner {
        devAddr = _devAddr;
    }

    /**
     * @dev View the dev address
     */
    function devAddress() external view returns (address) {
        return devAddr;
    }

    /**
     * @dev Changes the name change token address
     */
    function setNctAddress(address _token) external onlyOwner {
        nctAddress = _token;
    }

    /**
     * @dev Changes the price for changing the name of a mask
     */
    function setNameChangePrice(uint256 _price) external onlyOwner {
        nameChangePrice = _price;
    }

    /**
     * @dev Check if the name string is valid (alphanumeric and spaces without leading or trailing space)
     */
    function validateName(string memory str) public pure returns (bool) {
        bytes memory b = bytes(str);
        if(b.length < 1) return false;
        if(b.length > 25) return false; // Cannot be longer than 25 characters
        if(b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for(uint i; i<b.length; i++){
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continuous spaces

            if(
                !(char >= 0x30 && char <= 0x39) && // 9-0
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A) && // a-z
                !(char == 0x20) // Space
            )
                return false;

            lastChar = char;
        }

        return true;
    }

    /**
     * @dev Converts the string to lowercase
     */
    function toLower(string memory str) public pure returns (string memory){
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}