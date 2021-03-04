/**
 *Submitted for verification at Etherscan.io on 2021-03-04
*/

pragma solidity ^0.6.0;

contract Ownable {
    
     address private _owner;
      constructor() public {
        _owner = msg.sender;
        //emit OwnershipTransferred(address(0), _owner);
    }
    
    function owner() public view returns (address) {
        return _owner;
    }
    
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }
}

contract AssetTracker is Ownable
{
    event AssetCreate(string serialNumber, string assetName, string assetOwnerName);
    event AssetTransfer(string serialNumber, string assetName, string assetOwnerName, string newAssetOwnerName);
    
    
    enum AssetState { 
      Occupied,
      Aution
    }
    
    struct Asset {
        string ownerName;
        string ownerID;
        string name;
        string description;
        AssetState state;
        bool initialized;
    }
    mapping(string => Asset) assetRecord;
    
    function createAsset(string calldata _ownerName, string calldata _ownerID,string calldata assetName, string calldata assetDescription, AssetState _state, string calldata serialNumber) external onlyOwner
    {
        require(!assetRecord[serialNumber].initialized,'Serial number already exist');
        assetRecord[serialNumber] = Asset(_ownerName,_ownerID,assetName,assetDescription,_state,true);
        emit AssetCreate(serialNumber,assetName,_ownerName);
    }
    
    function transferAsset(string calldata _ownerName, string calldata _ownerID, string calldata serialNumber) external onlyOwner
    {
        require(assetRecord[serialNumber].initialized,'No record found with serial number');
        string memory oldOwnerName = assetRecord[serialNumber].ownerName;
        assetRecord[serialNumber].ownerName = _ownerName;

        assetRecord[serialNumber].ownerID = _ownerID;
       
        emit AssetTransfer(serialNumber,assetRecord[serialNumber].name,oldOwnerName,_ownerName);
    }
}