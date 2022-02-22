// SPDX-License-Identifier: Unlisenced
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


pragma solidity ^0.8.0;

interface Target {
    function devMint(uint256) external;
}

contract Interaction is IERC721Receiver
{
    function getCount() external{
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);
        Target(0xFE402d0Ab1A72ef1977e6Af7ADA7adC1eDB023D0).devMint(5);

    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4)
    {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}