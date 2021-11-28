///SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract MingingImmu is ERC721 {
    uint tokenId;
    address owner;

    constructor() ERC721("IMMUTABLE TEST","IMT"){
        owner = msg.sender;
    }

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external  {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, bytes memory blueprint) = Minting.split(mintingBlob);
        _safeMint(user, id, blueprint);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmSvGccaCz8D8pjELLJysfgHHqcrx6v8oRXeCMgsQKCroS/";
    }

    modifier onlyOwner(){
        require(msg.sender == owner,"only owner");
        _;
    }

}