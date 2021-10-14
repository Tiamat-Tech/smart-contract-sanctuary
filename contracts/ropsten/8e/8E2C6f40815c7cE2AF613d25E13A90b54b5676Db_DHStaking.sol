// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "base64-sol/base64.sol";
import "./IShowBiz.sol";

contract DHStaking is ERC721, ERC721URIStorage, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    
    uint public stakeReward = 1 ether;
    
    IERC721 _deadHeads = IERC721(0xB2F829b80A0e5a34AdA3c93b4b10fFaFDb21e355);
    IShowBiz _showBiz = IShowBiz(0x9C4849F2f590c63297279270306A2ebf3E22aE2e);
    
    struct StakedToken {
        uint stakedAt;
        uint endsAt;
        uint rewardMultiplier;
        uint months;
        address owner;
    }
    
    mapping(uint => StakedToken) public tokenIdToStakedToken;
    mapping(address => EnumerableSet.UintSet) addressToStakedTokensSet;
    mapping(uint => uint) public tokenIdToClaimedRewards;
    
    string public baseImageURI;
    
    event Stake(uint tokenId, address owner, uint endsAt);
    event Unstake(uint tokenId, address owner);
    event ClaimTokenRewards(uint tokenId, address owner, uint rewards);
    
    constructor() ERC721("Staked DeadHeads", "sDEAD") {}
    
    function onERC721Received(address, address from, uint256 tokenId, bytes calldata) external returns(bytes4) {
        require(tokenIdToStakedToken[tokenId].owner == from, "token must be staked over stake method");
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
    
    function stake(uint tokenId, uint months) external {
        require(months >= 1, "invalid minimum period");
        
        uint endsAt = block.timestamp + months * 28 days;
        uint rewardMultiplier = 100 + (months-1) * 2; //  TODO: discuss logic
        
        tokenIdToStakedToken[tokenId] = StakedToken({
            stakedAt: block.timestamp - 7 days + 15, // TODO: remove -30 days
            endsAt: endsAt,
            rewardMultiplier: rewardMultiplier,
            months: months,
            owner: msg.sender
        });
        
        tokenIdToClaimedRewards[tokenId] = 0;
        
        _deadHeads.safeTransferFrom(msg.sender, address(this), tokenId);
        
        addressToStakedTokensSet[msg.sender].add(tokenId);
        
        _mint(msg.sender, tokenId);
        
        emit Stake(tokenId, msg.sender, endsAt);
    }
    
    function unclaimedRewards(uint tokenId) public view returns (uint) {
        StakedToken storage stakedToken = tokenIdToStakedToken[tokenId];
        require(stakedToken.owner != address(0), "cannot query an unstaked token");
        
        uint rewardLimit = (stakedToken.endsAt - stakedToken.stakedAt) / 7 days;
        uint rewardsUntilNow = (block.timestamp - stakedToken.stakedAt) / 7 days;
        return (rewardsUntilNow > rewardLimit ? rewardLimit : rewardsUntilNow)
            * stakeReward * stakedToken.rewardMultiplier / 100 / 4 - tokenIdToClaimedRewards[tokenId];
    }
    
    function claimTokenRewards(uint tokenId) public {
        require(tokenIdToStakedToken[tokenId].owner == msg.sender, "caller did not stake this token");
        
        uint _unclaimedRewards = unclaimedRewards(tokenId);
        
        if (_unclaimedRewards > 0) {
            _showBiz.mint(msg.sender, _unclaimedRewards);
            tokenIdToClaimedRewards[tokenId] += _unclaimedRewards;
            
            emit ClaimTokenRewards(tokenId, msg.sender, _unclaimedRewards);
        }
    }
    
    function claimRewards() public {
        EnumerableSet.UintSet storage stakedTokens = addressToStakedTokensSet[msg.sender];
        uint totalStakedTokens = stakedTokens.length();
        
        require(totalStakedTokens > 0, "caller does not have any staked token");
        
        for (uint i = 0; i < totalStakedTokens; i++) {
            claimTokenRewards(stakedTokens.at(i));
        }
    }
    
    function unstake(uint tokenId) external {
        StakedToken storage stakedToken = tokenIdToStakedToken[tokenId];
        require(stakedToken.owner == msg.sender, "caller not owns this token");
        // require(block.timestamp > stakedToken.endsAt, "staked period did not finish yet");
        
        claimRewards();
        
        _deadHeads.safeTransferFrom(address(this), msg.sender, tokenId);
        
        delete tokenIdToStakedToken[tokenId];
        addressToStakedTokensSet[msg.sender].remove(tokenId);
        
        _burn(tokenId);
        
        emit Unstake(tokenId, msg.sender);
    }
    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        StakedToken storage stakedToken = tokenIdToStakedToken[tokenId];
        return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{',
                                    '"name":"Staked DeadHead #',tokenId,'",', 
                                    '"description":"Staked DeadHeads. This asset cannot be transfered until release. This stake rewards $SHOW.",', 
                                    '"attributes":[',
                                        '{',
                                            '"trait_type": "DeadHeads Id",',
                                            '"value": "#', tokenId, '"',
                                        '},',
                                        '{',
                                            '"trait_type": "Staked At",',
                                            '"value": "', stakedToken.stakedAt, '"',
                                        '},',
                                        '{',
                                            '"trait_type": "Stake Period",',
                                            '"value": "', stakedToken.months, ' months"',
                                        '},',
                                        '{',
                                            '"trait_type": "Release At",',
                                            '"value": "', stakedToken.endsAt, '"',
                                        '}',
                                    '],',
                                    '"image":"', baseImageURI, tokenId, '"',
                                '}'
                            )
                        )
                    )
                )
            );
    }

    function setImageBaseURI(string memory baseURI) public onlyOwner {
        baseImageURI = baseURI;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256) internal virtual override {
        require(to == address(0) || from == address(0));
    }
    
    function approve(address, uint256) public virtual override {
        revert();
    }
    
    function setApprovalForAll(address, bool) public virtual override {
        revert();   
    }
}