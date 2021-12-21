// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MalevichToken.sol"; 

contract TriggerNFTContract is ERC721, Ownable {
    using Counters for Counters.Counter;

    struct Trigger {
        bool isQuizzeCompleted;
        uint256 tokenPrice;
        uint256 [] tokens;
    }

    MalevichToken rewardToken;
    Counters.Counter private _tokenIds;
    Counters.Counter private _triggerIds;
    mapping(uint256 => Trigger) private _triggers;
    mapping(uint256 => bytes32) private _words;
    mapping(uint256 => bool) private rewardPaid;

    uint256 public rewardPerToken;

    event CreateTrigger(uint256 triggerId, uint256 tokenAmount, uint256 tokenPrice);
    event EditTrigger(uint256 triggerId, uint256 tokenAmount, uint256 tokenPrice);
    event BuyToken(uint256 tokenId, address purchaser);

    constructor(address tokenAddress, uint256 _rewardPerToken) ERC721("TriggerNFTContract", "TNFT") {
        require(tokenAddress != address(0), "TriggerNFTContract: address must not be empty");
        rewardToken = MalevichToken(tokenAddress);
        rewardPerToken = _rewardPerToken;
    }

    function getRewardPerToken() public view returns (uint256) {
        return rewardPerToken;
    }
    function setRewardPerToken(uint256 _rewardPerToken) public onlyOwner {
        rewardPerToken = _rewardPerToken;
    }

    function mintToken(bytes32 _tokenWord) public onlyOwner returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(address(this), newItemId);
        setTokenWord(newItemId, _tokenWord);

        return newItemId;
    }

    function tokenWord(uint256 tokenId) public view onlyOwner returns (bytes32) {
        require(_exists(tokenId), "TriggerNFTContract: word query for nonexistent token");
        return _words[tokenId];
    }

    function setTokenWord(uint256 tokenId, bytes32 _tokenWord) public onlyOwner {
        require(_exists(tokenId), "TriggerNFTContract: word query for nonexistent token");
        _words[tokenId] = _tokenWord;
    }
    

    function createTrigger(uint256[] memory _tokens, uint256 _tokenPrice) public onlyOwner returns (uint256) {
        _checkTokens(_tokens);

        _triggerIds.increment();
        uint256 newTriggerId = _triggerIds.current();

        _triggers[newTriggerId].tokenPrice = _tokenPrice;
        _triggers[newTriggerId].tokens = _tokens;

        emit CreateTrigger(newTriggerId, _tokens.length, _tokenPrice); 
        
        return newTriggerId;
    }

    function editTrigger(uint256 _triggerId, uint256[] memory _tokens, uint256 _tokenPrice) public onlyOwner {
        require(_triggerId <= _triggerIds.current(), "TriggerNFTContract: trigger query for nonexistent token");
        _checkTokens(_tokens);
        
        _triggers[_triggerId].tokenPrice = _tokenPrice;
        _triggers[_triggerId].tokens = _tokens;

        emit EditTrigger(_triggerId, _tokens.length, _tokenPrice); 
    }

    function isTriggerCompleted(uint256 triggerId) public view returns (bool) {
        require(triggerId <= _triggerIds.current(), "TriggerNFTContract: trigger query for nonexistent token");
        return _triggers[triggerId].isQuizzeCompleted;
    }

    function setTriggerQuizzeComplete(uint256 triggerId) public onlyOwner {
        require(triggerId <= _triggerIds.current(), "TriggerNFTContract: trigger query for nonexistent token");
        _triggers[triggerId].isQuizzeCompleted = true;
    }

    function buyToken(uint256 tokenId) public returns (bool) {
        require(ownerOf(tokenId) == address(this), "TriggerNFTContract: token was sold");
        (uint256 triggerId, bool  ok) = triggerByToken(tokenId); 
        if (!ok) return false;
        
        rewardToken.transferFrom(_msgSender(), address(this), _triggers[triggerId].tokenPrice);
        _transfer(address(this), _msgSender(), tokenId);

        emit BuyToken(tokenId, _msgSender()); 
        return ok;  
    }

    function triggerByToken(uint256 tokenId) public view returns (uint256, bool) {
        require(_exists(tokenId), "TriggerNFTContract: tokenId query for nonexistent token");
        for (uint256 triggerCounter = 0; triggerCounter <= _triggerIds.current(); triggerCounter++){
            for (uint256 tokenCounter = 0; tokenCounter < _triggers[triggerCounter].tokens.length; tokenCounter++){
                if (_triggers[triggerCounter].tokens[tokenCounter] == tokenId) return (triggerCounter, true);
            }
        }
        return (0, false);
    }

    function getTokenPrice(uint256 tokenId) public view returns (uint256){
        (uint256 triggerId, bool  ok) = triggerByToken(tokenId); 
        require (ok, "TriggerNFTContract: token is not associated with any trigger");
        return _triggers[triggerId].tokenPrice;
    }
    
    function isRewardPaid(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "TriggerNFTContract: invalid token ID");
        return rewardPaid[tokenId];
    }
    
    function withdrawReward(uint256 tokenId) public {
        require (_msgSender() == ownerOf(tokenId), "TriggerNFTContract: is not own");
        require (!isRewardPaid(tokenId), "TriggerNFTContract: reward was received");

        (uint256 triggerId, bool  ok) = triggerByToken(tokenId); 
        require (ok, "TriggerNFTContract: token is not associated with any trigger");
        require (isTriggerCompleted(triggerId), "TriggerNFTContract: trigger not completed");

        rewardToken.mint(_msgSender(), rewardPerToken);
        rewardPaid[tokenId] = true;
    }
    function _checkTokens(uint256[] memory _tokens) private view {
        for (uint256 counter = 0; counter < _tokens.length; counter++){
            require(_exists(_tokens[counter]), "TriggerNFTContract: invalid token ID");
        }
    }

    function withdrawMalevich(address recipient, uint256 amount) public onlyOwner {
        rewardToken.transfer(recipient, amount);
    }

}