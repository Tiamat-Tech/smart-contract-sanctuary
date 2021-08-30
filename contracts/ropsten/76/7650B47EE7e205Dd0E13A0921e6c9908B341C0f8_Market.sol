// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./SlotLibrary.sol";
import "./RecordLibrary.sol";

contract WhiteList is Ownable {

    function getWhiteListStatus(address _maker) external view returns (bool) {
        return isWhiteListed[_maker];
    }

    mapping (address => bool) public isWhiteListed;

    function addWhiteList (address _user) public onlyOwner {
        isWhiteListed[_user] = true;
        emit AddedWhiteList(_user);
    }

    function removeWhiteList (address _clearedUser) public onlyOwner {
        isWhiteListed[_clearedUser] = false;
        emit RemovedWhiteList(_clearedUser);
    }

    event AddedWhiteList(address indexed _user);

    event RemovedWhiteList(address indexed _user);

}

contract Farm is ERC1155Receiver,WhiteList{

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SlotLibrary for mapping(address=>SlotLibrary.SlotList);
    using RecordLibrary for mapping(bytes32=>RecordLibrary.RecordList[]);
    
    uint boost = 20;
    IERC20 public omt;
    mapping(address=>SlotLibrary.SlotList) slots;
    mapping(bytes32=>RecordLibrary.RecordList[]) public recordLists;
    
    constructor(IERC20 _omt) {
        omt = _omt;
    }
    
    function getSlot(address _token, uint tokenId) public view returns(SlotLibrary.Slot memory slot) {
       (slot,) = slots.get(_token,tokenId);
    }
    
    function getSlotCount(address _token) public view returns(uint count) {
        count = slots.getSlotCount(_token);
    }
    
    function addSlot(address _token, uint tokenId,uint duration,uint outRate) public onlyOwner {
        SlotLibrary.Slot memory slot = SlotLibrary.Slot({
            tokenId:tokenId,
            duration:duration,
            outRate:outRate
        });
        slots.add(_token,tokenId,slot);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4){
        uint posId = abi.decode(data,(uint));
        router(msg.sender,operator,from,id,value,posId);
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4){
        uint[] memory posIds = abi.decode(data,(uint[]));
        uint size = ids.length;
        require(size==values.length,"error data");
        require(size==posIds.length,"error data");
        for(uint i;i<size;i++) {
            router(msg.sender,operator,from,ids[i],values[i],posIds[i]);
        }
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
    
    function router(address token, address operator, address account, uint256 tokenId, uint256 num, uint256 posId) private {
        require(num==1,"error num");
        if(Address.isContract(operator)){
            require(isWhiteListed[operator],"not in whiteList");
        }
        require(account!=address(0),"forbidden");
        if(tokenId==0) {
            active(token,account);
        }else {
            deposit(token,account,tokenId,posId);
        }
    }
    
    function active(address token,  address account) private returns(uint) {
        return recordLists.active(account, token );
    }

    
    function deposit(address token, address account, uint256 tokenId,uint256 posId) private {
        (SlotLibrary.Slot memory slot,uint id) = slots.get(token,tokenId);
        RecordLibrary.Record memory record = recordLists.get(account,token,id,posId);
        require(record.expiration==0,"activated");
        record.outRate = slot.outRate;
        record.freeze = block.timestamp;
        record.expiration = block.timestamp.add(slot.duration);
        harvest(account,token,posId);
        recordLists.set(account,token,id,posId,record);
    }
    
    function harvest(address account,address token,uint posId) public returns(uint rewards) {
        rewards = recordLists.harvest(account,token,posId,boost);
        safeOmtTransfer(account,rewards);
    }

    function safeOmtTransfer(address account,uint amount) internal {
        uint omtBal = omt.balanceOf(address(this));
        if(amount>omtBal) {
            amount = omtBal;
        }
        omt.safeTransfer(account,amount);
    }
    
    function get(address account,address token,uint _id,uint posId) internal view returns(RecordLibrary.Record storage record) {
        record = recordLists.get(account,token,_id,posId);
    }

    function getRecords(address account,address token,uint posId) internal view returns(RecordLibrary.Record[4] memory records,uint count) {
        (records,count) = recordLists.getRecords(account, token, posId);
    }

    function getCount(address account,address token) internal view returns(uint count) {
        count =  recordLists.getCount(account, token);
    }

}