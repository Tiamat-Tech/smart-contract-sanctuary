// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/presets/ERC1155PresetMinterPauser.sol";

contract NftFactory is ERC1155PresetMinterPauser {

    address public factoryManager;
    bool public factoryManagerSet = false;
   
    uint public nextMomentID;
    mapping(uint => string) public momentID_to_URI;
    mapping(string => uint) public URI_to_momentID;
    mapping(uint => bool) public minted;

    constructor() ERC1155PresetMinterPauser("Contract wide metadata URI") {
        // init nextMomentID
        nextMomentID = 1;        
    }

    modifier OnlyFactoryManager(address _caller) {

        require(_caller == factoryManager, "Only the factor manager can call the factory");

        _;
    }

    function setFactoryManager(address _newManager) public {
        require(!factoryManagerSet || msg.sender == factoryManager, "Only the current manager can set new manager.");
        factoryManager = _newManager;
        grantRole(MINTER_ROLE, _newManager);
        // Grant DEFAULT_ADMIN_ROLE to DAO account
    }

    function assignMomentID(string memory _URI) internal OnlyFactoryManager(msg.sender) returns (uint _id) {
        require(URI_to_momentID[_URI] == 0, "Cannot double mint the same URI.");

        _id = nextMomentID;
        momentID_to_URI[_id] = _URI;
        URI_to_momentID[_URI] = _id;

        nextMomentID += 1;
    }

    function mintMoment(
        string calldata _URI,
        uint _amount
    ) external OnlyFactoryManager(msg.sender) returns (uint _id) {

        _id = assignMomentID(_URI);
        _mint(factoryManager, _id, _amount, "");
    }

    function increaseMomentSupply(uint _momentID, uint _amount) external OnlyFactoryManager(msg.sender) {

        require(minted[_momentID], "Can increase supply only of already minted moments. Mint new moments using mintMoment.");
        _mint(factoryManager, _momentID, _amount, "");
    }

    function transferPack(
        address _from, 
        address _to, 
        uint[] calldata _ids
    ) external OnlyFactoryManager(msg.sender) {
        
        uint[] memory amounts = new uint[](_ids.length);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        safeBatchTransferFrom(_from, _to, _ids, amounts, "");
    }

    function transferSingleMoment(
        address _from, 
        address _to, 
        uint _id
    ) external OnlyFactoryManager(msg.sender) {
        safeTransferFrom(_from, _to, _id, 1, "");
    }
}