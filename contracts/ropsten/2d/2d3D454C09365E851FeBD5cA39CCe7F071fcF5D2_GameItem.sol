pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract GameItem is ERC1155{

    constructor()ERC1155("http://localhost:8000"){

    }

    function mint(address account,
        uint256 id,
        uint256 amount,
        bytes memory data) public {
            _mint(account,id,amount,"");
    }

     function supportsInterface(bytes4 interfaceID) public view override returns (bool) {
      return  interfaceID == 0x01ffc9a7 ||    // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
              interfaceID == 0x4e2312e0;      // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
  }

}