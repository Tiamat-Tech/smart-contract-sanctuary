// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./DARTsERC2981.sol";
// import "hardhat/console.sol";

contract DARTsERC1155 is ERC1155, AccessControl, Pausable, ERC1155Supply, DARTsERC2981Base{
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using Counters for Counters.Counter;
    using Strings for string;

    string internal _uri;
    Counters.Counter private _tokenIds; 

    constructor(string memory _URI) ERC1155(_URI) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        setURI(_URI);        
        setRoyaltyTable();
    }

    function create(
        address[] memory owners,  address[] memory creators,  address[] memory sponsors,
        address[] memory managements, address[] memory thanks,
        uint initSupply, 
        uint formerId,  uint order,
        bytes calldata metadata) external onlyRole(MINTER_ROLE) returns (uint) {
        
        _tokenIds.increment();
        uint newItemId = _tokenIds.current();

        _mint(owners[0], newItemId, initSupply, metadata);

        Rights[newItemId] = Right(
            newItemId,
            formerId,
            owners, creators, sponsors, managements, thanks,
            uri (newItemId),
            order,
            metadata);        
        return newItemId;
    }

    function getItem(uint _tokenId) public view returns (Right memory) {
        return Rights[_tokenId];
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
        _uri = newuri;
    }
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address account, uint id, uint amount, bytes memory data)
    public
    onlyRole(MINTER_ROLE)    {
        _mint(account, id, amount, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint[] memory ids, uint[] memory amounts, bytes memory data)
    internal
    whenNotPaused
    override (ERC1155, ERC1155Supply)   {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function uri(
        uint _id
    ) public view virtual override returns (string memory) {
        require(_exists(_id), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        return string(abi.encodePacked(_uri, Strings.toString(_id), ".json"));
    }

    function _exists(uint _id) internal pure returns (bool) {
        return _id != 0;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155,  AccessControl)
        returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // memory allocation purpose, if ID inputs, output formerID , number of owners, current order returns
    function royaltycount (uint256 tokenId) private view returns (uint, uint, uint){                
        uint royaltytotal = Rights[tokenId].owners.length + 
                            Rights[tokenId].creators.length + 
                            Rights[tokenId].sponsors.length +
                            Rights[tokenId].managements.length +
                            Rights[tokenId].thanks.length ;     
        return (Rights[tokenId].formerId, royaltytotal, Rights[tokenId].order );
    }

    function shareinfoinput (address A, status B, uint C) private pure returns (address, status, uint){
        address AA = A;
        status  BB = B;
        uint  CC = C;
        return (AA, BB, CC);
    }
    
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
    internal
    view
    returns (address[] memory recepient, uint256[] memory royaltyAmount, status[] memory shareflag, 
            uint, uint)    {
        // require(_exists(tokenId), "This is not supported tokenID");

        (uint _formerID , uint _royaltycount, uint _order)= royaltycount(tokenId);
        if (_order == 0){defaultOrder == 0;}
        // require( _formerID != 0, "This is the original contents");

        address[] memory _recepient = new address[](_royaltycount);
        uint256[] memory _royaltyAmount = new uint256[](_royaltycount);
        status[] memory _shareflag = new status[](_royaltycount);        

        uint index = 0;
        Right memory tempright = Rights[tokenId];
        
        uint owneramount = royalty_table[0][defaultOrder];  
        if (tempright.creators.length == 0){
            owneramount += royalty_table[1][defaultOrder]; }
        if(tempright.sponsors.length == 0){
            owneramount += royalty_table[3][defaultOrder];}
        if(tempright.managements.length == 0){
            owneramount += royalty_table[4][defaultOrder];}  
        if(tempright.thanks.length == 0){
        owneramount += royalty_table[5][defaultOrder];}             

        uint i = 0;
        if (tempright.owners.length == 1){
            (_recepient[index], _shareflag[index], _royaltyAmount[index]) = shareinfoinput(tempright.owners[0], status.Owners, owneramount*salePrice/100);
            index++; 
        }else if (tempright.owners.length > 1) {
            uint amount = owneramount*salePrice/(100*(tempright.owners.length));
            for (i = 0; i <= tempright.owners.length; i++){     
                (_recepient[index], _shareflag[index], _royaltyAmount[index]) = shareinfoinput(tempright.owners[i], status.Owners, amount);               
                index++;
            }
        }            

        uint j = 0;                        
        if (tempright.creators.length > 0) {
            uint amount = royalty_table[1][defaultOrder]*salePrice/100/tempright.creators.length;
            for (j = 0; j <= tempright.creators.length; j++){
                (_recepient[index], _shareflag[index], _royaltyAmount[index]) = shareinfoinput(tempright.creators[j], status.Creators, amount);
                index++;
            }
        }
                    
        if (tempright.sponsors.length > 0) {
            uint amount = royalty_table[3][defaultOrder]*salePrice/100/tempright.sponsors.length;
            for (j = 0; j <= tempright.sponsors.length; j++){
                (_recepient[index], _shareflag[index], _royaltyAmount[index]) = shareinfoinput(tempright.sponsors[j], status.Sponsors, amount);
                index++;
            }
        }
                
        if (tempright.managements.length > 0) {
            uint amount = royalty_table[4][defaultOrder]*salePrice/100/tempright.managements.length;
            for (j = 0; j <= tempright.managements.length; j++){
                (_recepient[index], _shareflag[index], _royaltyAmount[index]) = shareinfoinput(tempright.managements[j], status.Managements, amount);
                index++;
            }
        }
                    
        if (tempright.thanks.length > 0) {
            uint amount = royalty_table[5][defaultOrder]*salePrice/100/tempright.thanks.length;
            for (j = 0; j <= tempright.thanks.length; j++){
                (_recepient[index], _shareflag[index], _royaltyAmount[index]) = shareinfoinput(tempright.thanks[j], status.Thanks, amount);
                index++;
            }
        }
        uint price = royalty_table[2][defaultOrder]*salePrice/100;                
        
        return (_recepient, royaltyAmount, _shareflag, _formerID, price);
    }
}