// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "./SafeMath.sol";

contract Feedback {
    using SafeMath for uint256;
    address public immutable owner; //owner won't change. Save some gas.

    struct Feed {
        uint256 rate;
        uint256 id;
        uint createdAt;
        string message;
        string user;
    }

    Feed[] public feeds;

    event OnNewFeed(uint indexed createdAt, string message, string user, uint256 rate);

    //Reduce code size by wrapping modifier inside private
    function _isValidRateData(uint256 rate) private pure {
        require(rate >= 0 && rate <=5, "The rate must be between 0 and 5");
    }

    function _isValidString(string calldata str) private pure {
        require(bytes(str).length > 0, "The string cannot be empty");
    }

    function _isValidIndex(uint256 index) private view {
        require(index >= 0 && index < feeds.length, "This index is outside of the bound of the array");
    }

    function _isValidData(bytes calldata data) private pure {
        require(data.length > 0, "The data cannot be empty");
    }


    modifier validRate(uint256 rate){
        _isValidRateData(rate);
        _;
    }

    modifier validString(string calldata str){
        _isValidString(str);
        _;
    }

    modifier validData(bytes calldata data){
        _isValidData(data);
        _;
    }

    modifier validIndex(uint256 index){
        _isValidIndex(index);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createFeed(uint256 _rate, string calldata _message, string calldata _user) validRate(_rate) validString(_message) validString(_user) external {      
        feeds.push(Feed({
            rate: _rate,
            id: feeds.length,
            createdAt: block.timestamp,
            message: _message,
            user: _user
        }));
        emit OnNewFeed(block.timestamp, _message, _user, _rate); 
    }

    function getFeedCount() public view returns (uint){
        return feeds.length;
    }

    function getFeed(uint256 _index) validIndex(_index) public view returns(uint256 rate, uint256 id, uint createdAt, string memory message, string memory user)
    {
        Feed storage feed = feeds[_index];
        return (
            feed.rate,
            feed.id,
            feed.createdAt,
            feed.message,
            feed.user
        );
    }

    function getAllFeeds() external view returns(Feed[] memory) {
        return feeds;
    }

    function getFeedsCount() external view returns(uint256) {
        return feeds.length;
    }
}