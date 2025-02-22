// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IERC721EnumInitMint {
    function mint(address to, uint id) external;
    function totalSupply() external view returns (uint256);
}

contract OpenSale is Ownable
{
    address public mintingContract;
    uint public price;
    uint public maxTokens;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor() {
    }

    function setMintingContract(address mintingContract_) public onlyOwner{
        mintingContract = mintingContract_;
    }

    function setPrice(uint price_) public onlyOwner {
        price = price_;
    }

    function setMaxTokens(uint maxTokens_) public onlyOwner {
        maxTokens = maxTokens_;
    }

    function mint(uint amount) public payable {
        require(msg.value >= price * amount, "Sent value is not enough");
        uint mintIdx = IERC721EnumInitMint(mintingContract).totalSupply();
        require(amount + mintIdx <= maxTokens, "Too many tokens");
        for(uint i = 0; i < amount; i++) {
            mintIdx += 1;
            IERC721EnumInitMint(mintingContract).mint(msg.sender, mintIdx);
        }
    }

    function adminMint(uint amount, address to) public onlyOwner {

        uint mintIdx = IERC721EnumInitMint(mintingContract).totalSupply();
        for(uint i = 0; i < amount; i++) {
            mintIdx += 1;
            IERC721EnumInitMint(mintingContract).mint(to, mintIdx);
        }
    }

    function release(address payable _recv, uint _amount) public onlyOwner {
        Address.sendValue(_recv, _amount);
    }
}