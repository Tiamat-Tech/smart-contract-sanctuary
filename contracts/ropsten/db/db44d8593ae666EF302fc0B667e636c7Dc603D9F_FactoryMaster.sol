//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/ERC20/ERC20.sol";
// import "../token/ERC721/ERC721.sol";
// import "../token/ERC2917/ERC2917.sol";
import "../token/ERC20/ERC20Burnable.sol";
import "../token/ERC20/ERC20Mintable.sol";
// import "../token/ERC20/ERC20MintableCappable.sol";
import "./ERC20StandardFactory.sol";
import "../token/ERC20/ERC20MintableBurnable.sol";


contract FactoryMaster  {
    ERC20[] public childrenErc20;
    ERC20Burn[] public childrenErc20Burn;
    // ERC721[] public childrenErc721;
    // ERC2917[] public childrenErc2917;
    ERC20Mintable[] public childrenErc20Mint;
    ERC20MintableBurnable[] public childrenErc20MintBurn;
    

    

    uint constant fee_erc20 = 0.00001 ether;
    // uint constant fee_erc721 = 0.4 ether;
    // uint constant fee_erc2917 = 0.5 ether;
   
    event ChildCreatedERC20(address childAddress, string name, string symbol);
    // event ChildCreatedERC721(address childAddress, string name, string symbol);
    // event ChildCreated2917(
    //     address childAddress,
    //     string name,
    //     string symbol,
    //     uint256 _interestsRate
    // );
    event ChildCreatedERC20Burnable(address childAddress, string name, string symbol);
    event ChildCreatedERC20Mintable(address childAddress, string name, string symbol);
    event ChildCreatedERC20MintableBurnable(address childAddress, string name, string symbol);
    



    enum Types {
        none,
        erc20,
        erc20Burn,
        erc20Mintable,
        erc20MintableBurnable
        
    }

    function createChild(Types types,string memory name,string memory symbol) external payable {

        require(types != Types.none, "you must enter the word 1");
        require(keccak256(abi.encodePacked((name))) !=keccak256(abi.encodePacked((""))));
        require(keccak256(abi.encodePacked((symbol))) !=keccak256(abi.encodePacked((""))));

        if (types == Types.erc20) {

            require(msg.value>=fee_erc20,"ERC20:value must be greater than 0.2");

            ERC20 child = new ERC20(name, symbol);
            childrenErc20.push(child);
            emit ChildCreatedERC20(address(child), name, symbol);
            
        }
        if (types == Types.erc20Burn){
            require(msg.value>=fee_erc20,"ERC20:value must be greater than 0.2");

            ERC20Burn child = new ERC20Burn(name, symbol);
            childrenErc20Burn.push(child);
            emit ChildCreatedERC20Burnable(address(child), name, symbol);
        }

          if (types == Types.erc20Mintable){
            require(msg.value>=fee_erc20,"ERC20:value must be greater than 0.2");

            ERC20Mintable child = new ERC20Mintable(name, symbol);
            childrenErc20Mint.push(child);
            emit ChildCreatedERC20Mintable(address(child), name, symbol);
        }

           if (types == Types.erc20MintableBurnable){
            require(msg.value>=fee_erc20,"ERC20:value must be greater than 0.2");

            ERC20MintableBurnable child = new ERC20MintableBurnable(name, symbol);
            childrenErc20MintBurn.push(child);
            emit ChildCreatedERC20MintableBurnable(address(child), name, symbol);
        }


        //  if (types == Types.erc20Standard){
        //     require(msg.value>=fee_erc20,"ERC20:value must be greater than 0.2");

        //     ERC20Standard child = new ERC20Standard(1000);
        //     childrenErc20Standard.push(child);
        //     emit ChildCreatedERC20Standard(address(child),1000, name, symbol);
        // }
        
    }
}