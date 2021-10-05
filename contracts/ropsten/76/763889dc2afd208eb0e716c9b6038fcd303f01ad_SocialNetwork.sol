// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISocialNetwork.sol";

contract SocialNetwork is ISocialNetwork, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _postIdCounter;
    mapping(uint256 => Post) public posts;

    modifier requireActivePost(uint256 postID) {
        require(postID < Counters.current(_postIdCounter), "SocialNetwork::requireActivePost: Post does not exist");
        require(posts[postID].owner != address(0), "SocialNetwork::requireActivePost: Post was deleted");
        _;
    }

    function getPost(uint256 postID) requireActivePost(postID) public view override returns (Post memory) {
        return posts[postID];
    }

    function createPost(string memory text) public override {
        require(bytes(text).length > 0, "SocialNetwork::createPost: Cannot create post without text");

        uint256 currentID = Counters.current(_postIdCounter);
        posts[currentID] = Post(block.timestamp, msg.sender, text);

        emit PostCreated(currentID, msg.sender, text);
        Counters.increment(_postIdCounter);
    }

    function deletePost(uint256 postID) requireActivePost(postID) public override {
        require(posts[postID].owner == msg.sender, "SocialNetwork::deletePost: Not the owner of post");

        delete posts[postID];
        emit PostDeleted(postID);
    }

    function sponsorPost(uint256 postID) requireActivePost(postID) public override payable {
        require(posts[postID].owner != msg.sender, "SocialNetwork::sponsorPost: Cannot sponsor your own post");
        require(msg.value > 0, "SocialNetwork::sponsorPost: Sponsor amount must be greater than 0");

        address payable postOwner = payable(posts[postID].owner);

        (bool sent,) = postOwner.call{value : msg.value}("");
        require(sent, "SocialNetwork::sponsorPost: Failed to send Ether to owner");

        emit PostSponsored(postID, msg.value, msg.sender);
    }
}