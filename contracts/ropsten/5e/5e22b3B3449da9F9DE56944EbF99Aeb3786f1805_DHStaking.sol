// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IShowBiz.sol";

contract DHStaking is Ownable {
    IERC721 _deadHeads = IERC721(0xB2F829b80A0e5a34AdA3c93b4b10fFaFDb21e355);
    IShowBiz _showBiz = IShowBiz(0x9C4849F2f590c63297279270306A2ebf3E22aE2e);
    
    struct StakedToken {
        uint stakedAt;
        uint endsAt;
        uint rewardMultiplier;
        address owner;
    }
    
    mapping(uint => StakedToken) public tokenIdToStakedToken;
    
    event TokenStaked(uint tokenId, address owner, uint endsAt);
    event TokenUnstaked(uint tokenId, address owner);
    
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) external returns(bytes4) {
        require(tokenIdToStakedToken[tokenId].owner == from, "token must be staked over stake method");
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
    
    function stake(uint tokenId, uint months) external {
        require(months >= 1, "invalid minimum period");
        
        uint endsAt = block.timestamp + months * 30 days;
        uint rewardMultiplier = 1 + months / 50; //  TODO: discuss logic
        
        tokenIdToStakedToken[tokenId] = StakedToken({
            stakedAt: block.timestamp,
            endsAt: endsAt,
            rewardMultiplier: rewardMultiplier,
            owner: msg.sender
        });
        
        _deadHeads.safeTransferFrom(msg.sender, address(this), tokenId);
        
        emit TokenStaked(tokenId, msg.sender, endsAt);
    }
    
    function unstake(uint tokenId) external {
        StakedToken storage stakedToken = tokenIdToStakedToken[tokenId];
        require(stakedToken.owner == msg.sender, "caller not owns this token");
        // require(stakedToken.endsAt <= block.timestamp, "staked period did not finish yet");
        
        _deadHeads.safeTransferFrom(address(this), msg.sender, tokenId);
        
        delete tokenIdToStakedToken[tokenId];
        
        emit TokenUnstaked(tokenId, msg.sender);
    }
}