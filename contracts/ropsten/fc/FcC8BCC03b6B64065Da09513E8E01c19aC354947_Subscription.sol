pragma solidity ^0.8.0;

import "./access/Ownable.sol";

interface IERC20 {
    function transferFrom(address sender, address receiptent, uint256 amount) external;
    function balanceOf(address account) external view returns(uint256);
}

contract Subscription is Ownable{

    IERC20 public watt;

    struct review {
        address sender;
        string text;
    }

    struct scription {
        address receiver;
        address sender;
        string text;
    }

    uint256 public wattAmount = 1 ether;

    mapping(address => review[]) private script;

    scription[] private wholeScript;

    constructor(IERC20 _watt) public {
        watt = _watt;
    }

    function subscribe(address _creator, string memory _subscription) external {
        require(watt.balanceOf(_msgSender()) >= wattAmount, "Insufficient Watt amount");
        
        watt.transferFrom(_msgSender(), address(this), wattAmount);
        script[_creator].push(review({
            sender : _msgSender(),
            text : _subscription
        }));

        wholeScript.push(scription({
            receiver : _creator,
            sender : _msgSender(),
            text : _subscription
        }));
    }
    
    function getLastSubscription(address user) external view returns(review memory){
        
        review memory last;
        uint256 length = script[user].length;
        
        if(length > 0) last = script[user][length - 1];
        return last;
    }

    function getAllReviews(address _user) external view returns(review[] memory){
        return script[_user];
    }

}