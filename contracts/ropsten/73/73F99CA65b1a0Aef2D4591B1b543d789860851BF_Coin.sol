// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IMintable.sol";

// Make sure the contract is ERC721 compatible!
contract Coin is ERC20, Ownable, IMintable {
    address public imx;
    uint256 public quantum = 1;

    // constructor which gets called on contract's deployment
    constructor(
        // name of your Coin (eg. "Faucet")
        string memory _name,
        // symbol of your Coin (reg. "FCT")
        string memory _symbol,
        // IMX's Smart Contract address for whitelisting purposes
        address _imx
    ) ERC20(_name, _symbol) {
        imx = _imx;
    }

    function setIMXAddress(address _imx) external onlyOwner {
        imx = _imx;
    }

    function setQuantum(uint256 _quantum) external onlyOwner {
        quantum = _quantum;
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        super._mint(_to, _amount * 1000000000000000000);
    }

    function mintFor(
        // address of the receiving user's wallet (must be IMX registered)
        address _to,
        // number of tokens that are getting mint
        uint256 _amount,
        // ignored
        bytes calldata mintingBlob
    ) external override {
        // whitelisting the IMX Smart Contract address
        // this makes sure that you don't accidentally call the function, which could result in clashing token IDs
        require(msg.sender == imx, "401");
        super._mint(_to, _amount * quantum);
    }
}