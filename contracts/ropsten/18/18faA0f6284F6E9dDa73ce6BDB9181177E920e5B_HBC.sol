pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HBC is ERC1155, Ownable {

    constructor() ERC1155("ipfs://bafybeia5ruqxf66eshacp3m3r4j7wx7vd6arxjps7qmza5roohba6ptuei/metadata/") {}

    function mintAndTransfer(address buyerAddress, uint256 tokenID) public
    {
        address _owner = owner();
        _mint(_owner, tokenID, 1, "");
        _safeTransferFrom(_owner, buyerAddress, tokenID, 1, "");
    }

    function uri(uint256 _tokenID) override public view returns (string memory) {
    
       string memory hexstringtokenID;
         hexstringtokenID = uint2hexstr(_tokenID);
    
        return string(
            abi.encodePacked(
                super.uri(_tokenID),
                hexstringtokenID,
                ".json"
            )
        );
    }  

    function uint2hexstr(uint256 i) private pure returns (string memory) {
        if (i == 0) return "0";
        uint j = i;
        uint length;
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        uint mask = 15;
        bytes memory bstr = new bytes(length);
        uint k = length;
        while (i != 0) {
            uint curr = (i & mask);
            bstr[--k] = curr > 9 ?
                bytes1(uint8(55 + curr)) :
                bytes1(uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }
        return string(bstr);
    } 
}