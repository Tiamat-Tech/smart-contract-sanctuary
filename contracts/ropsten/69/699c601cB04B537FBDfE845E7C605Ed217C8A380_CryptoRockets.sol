// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CryptoRockets is Ownable {
    event WhitelistClaimed(address userAddress, uint256 tokenAmount);
    event AirdropClaimed(address userAddress, uint256 tokenAmount);
    event WithdrawAll(address userAddress, uint256 tokenAmount);

    mapping (address => uint256) whitelistTokensTotal;
    mapping (address => uint256) airdropTokensTotal;
    mapping (address => bool) whitelistClaimed;
    mapping (address => bool) airdropClaimed;

    address[] public whitelistedAddresses;
    address[] public airdropAddresses;
    address contractOwner;

    IERC20 public cryptoRocketsToken;

    uint256 whitelistTimestamp;
    uint256 airdropTimestamp;

    using SafeERC20 for IERC20;

    constructor(address _cryptoRocketsToken){
        require(_cryptoRocketsToken != address(0), "Please insert token address");
        cryptoRocketsToken = IERC20(_cryptoRocketsToken);
    }

    function addWhitelistAddresses(address[] memory userAddresses, uint256 tokenAmount) public onlyOwner {
        for (uint256 i = 0; i < userAddresses.length; i++){
            whitelistTokensTotal[userAddresses[i]] = tokenAmount * 1 ether;
            whitelistedAddresses.push(userAddresses[i]);
            whitelistClaimed[userAddresses[i]] = false;
        }
    }

    function addWhitelistAddress(address userAddress, uint256 tokenAmount) public onlyOwner {
        whitelistTokensTotal[userAddress] = tokenAmount * 1 ether;
        whitelistedAddresses.push(userAddress);
        whitelistClaimed[userAddress] = false;
    }

    function addAirdropAddresses(address[] memory userAddresses, uint256 tokenAmount) public onlyOwner {
        for (uint256 i = 0; i < userAddresses.length; i++){
            airdropTokensTotal[userAddresses[i]] = tokenAmount * 1 ether;
            airdropClaimed[userAddresses[i]] = false;
            airdropAddresses.push(userAddresses[i]);
        }
    }

    function addAirdropAddress(address userAddress, uint256 tokenAmount) public onlyOwner {
        airdropTokensTotal[userAddress] = tokenAmount * 1 ether;
        airdropClaimed[userAddress] = false;
        airdropAddresses.push(userAddress);
    }

    function whitelistClaim() public {
        require(whitelistClaimed[msg.sender] == false);
        require(block.timestamp > whitelistTimestamp);

        uint256 tokenAmount = whitelistTokensTotal[msg.sender];
        cryptoRocketsToken.safeTransfer(msg.sender, tokenAmount);
        emit WhitelistClaimed(msg.sender, tokenAmount);
        whitelistClaimed[msg.sender] = true;
    }

    function airdropClaim() public {
        require(airdropClaimed[msg.sender] == false);
        require(block.timestamp > airdropTimestamp);

        uint256 tokenAmount = airdropTokensTotal[msg.sender];
        cryptoRocketsToken.safeTransfer(msg.sender, tokenAmount);
        emit AirdropClaimed(msg.sender, tokenAmount);
        airdropClaimed[msg.sender] = true;
    }

    function balance() public view returns (uint256){
        return cryptoRocketsToken.balanceOf(address(this));
    }

    function depositTokens(uint256 amount) external {
        cryptoRocketsToken.safeTransferFrom(msg.sender, address(this), amount * 1 ether);
    }

    function withdrawAll() public onlyOwner {
        uint256 tokenAmount = balance();
        cryptoRocketsToken.safeTransfer(msg.sender, tokenAmount);
        emit WithdrawAll(msg.sender, tokenAmount);
    }

    function setWhitelistTimestamp(uint256 _whitelistTimestamp) public onlyOwner {
        whitelistTimestamp = _whitelistTimestamp;
    }

    function setAirdropTimestamp(uint256 _airdropTimestamp) public onlyOwner {
        airdropTimestamp = _airdropTimestamp;
    }
}