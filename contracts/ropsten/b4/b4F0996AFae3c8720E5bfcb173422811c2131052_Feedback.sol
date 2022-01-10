// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "./SafeMath.sol";

contract Feedback {
    using SafeMath for uint256;
    address public immutable owner; //owner won't change. Save some gas.

    struct Response {
        uint createdAt;
        string message;
    }

    struct Feed {
        uint256 rate;
        uint256 id;
        uint createdAt;
        string message;
        string user;
        Response response;
    }

    Feed[] public feeds;

    event OnNewFeed(uint indexed createdAt, uint indexed _rate, string indexed _user, string _message);
    event OnNewResponse(uint indexed createdAt, uint indexed index);

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

    modifier onlyOwner(){
        require(msg.sender == owner, "Only the owner can reply.");
        _;
    }

    modifier validRate(uint256 rate){
        _isValidRateData(rate);
        _;
    }

    modifier validString(string calldata str){
        _isValidString(str);
        _;
    }

    modifier validIndex(uint256 index){
        _isValidIndex(index);
        _;
    }

    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner");
        owner = _owner;
    }

    function createFeed(uint _rate, string calldata _message, string calldata _user) validRate(_rate) validString(_message) validString(_user) external {      
        
        Response memory res = Response({
        createdAt: block.timestamp,
                message: ""});
        Feed memory feed = Feed({
            rate: _rate,
            id: feeds.length,
            createdAt: block.timestamp,
            message: _message,
            user: _user,
            response:res
        });
        feeds.push(feed);
        emit OnNewFeed(block.timestamp, _rate, _user, _message); 
    }

    function createResponse(uint _index, string calldata _message) onlyOwner validIndex(_index) external {
        Feed storage feed = feeds[_index];
        feed.response = Response({
            createdAt: block.timestamp,
            message: _message
        });
        emit OnNewResponse(block.timestamp, _index); 
    }

    function getFeed(uint256 _index) validIndex(_index) public view returns(uint256 rate, uint256 id, uint createdAt, string memory message, string memory user, Response memory response)
    {
        Feed storage feed = feeds[_index];
        return (
            feed.rate,
            feed.id,
            feed.createdAt,
            feed.message,
            feed.user,
            feed.response
        );
    }

    function getAllFeeds() external view returns(Feed[] memory) {
        return feeds;
    }

    function getFeedsCount() external view returns(uint256) {
        return feeds.length;
    }
}