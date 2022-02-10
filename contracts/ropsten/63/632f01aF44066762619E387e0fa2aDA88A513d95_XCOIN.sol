//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";
import "contracts/erc721connector.sol";

contract XCOIN is ERC20("XCOIN", "XCO") {
    // Set Total Supply

    address private _connectNFT;

    constructor () {
        console.log("---Deploying COINX");
        // _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function connectNFT(address addr) public {
        console.log("---Setting Address");
        _connectNFT = addr;
    }

    function getholder() public view returns (address[] memory output) {
        XNFT nft = XNFT(_connectNFT);
        output = nft.holder();
        return output;
    }

    function mintToAll() public {
        console.log("---Mint To All");
        address[] memory userList = getholder();
        for (uint256 i=0;i<userList.length;i++){
            console.log("---Mint To ",userList[i]);
            _mint(userList[i], 1000000 * 10 ** decimals());
        }
    }
}