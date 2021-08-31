// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract NFT is Context,AccessControlEnumerable,ERC1155Supply {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory uri_) ERC1155(uri_) {
        
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
    }
    
    string[] private rarityTypes; 

    struct Relic{
        string name;
        uint256 mulReferral;
        uint256 mulNFT;
        uint256 div;

        string history;
        string rarity;
    }   
    //list of relics
    mapping (uint256=>Relic)  private relics;
    //pause a relic in case if it is nesessary
    mapping (uint256=>bool) private relicPause;
    //rarity -> ids
    mapping (string=>uint256[]) private quantityPerRarity;
        
    uint256[] private listIds;

    function addRelic(
        uint256 idToken,
        string memory name,
        uint256 mulReferral,
        uint256 mulNFT,
        uint256 div,
        string memory history,
        string memory rarity) public returns (bool success) {
         require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC1155: must have minter role to add"
        );
        require(relics[idToken].div == 0, "ERC1155: The id already exists");
        require(div > 0,"ERC1155: The div parameter can't be 0");
        
        if(quantityPerRarity[rarity].length == 0){
            rarityTypes.push(rarity);
        }
        listIds.push(idToken);
        Relic memory _relic= Relic( name,mulReferral,mulNFT,div,history,rarity);
        relics[idToken]=_relic;
        quantityPerRarity[rarity].push(idToken);
        return true;
    }

    function changeRarity(string memory oldRarity,string memory newRarity) public {
           require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC1155: must have minter role to change"
        );
        require(quantityPerRarity[oldRarity].length > 0, "ERC1155: The rarity not exists" );
        // require(quantityPerRarity[oldRarity].length > 0);
        uint256 size=quantityPerRarity[oldRarity].length;
        uint256[] memory newIds= new uint256[](size);
        for (uint256 index = 0; index < size; index++) {
            uint256 id=quantityPerRarity[oldRarity][index];
            newIds[index]=id;
            relics[id].rarity=newRarity;
        }
        uint256[] storage _newArray;
        quantityPerRarity[newRarity]=newIds;
        quantityPerRarity[oldRarity]= _newArray;

        for (uint256 i = 0; i < rarityTypes.length; i++) {
            
            if(keccak256(bytes(rarityTypes[i])) == keccak256(bytes(oldRarity))){
               rarityTypes[i] =newRarity;
               break;
            }
        }
    }

    function getListIds () public view returns(uint256[] memory ids) {
        return listIds;
    }

    function changeHistory(uint256 idToken,string memory history) public {
       require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC1155: must have minter role to mint"
        );
       require(relics[idToken].div > 0, "ERC1155: The idToken not exists");
       
       relics[idToken].history=history;

    }

    function getIdsPerRarity(string memory _rarity) public view returns(uint256[] memory ids) {
        return quantityPerRarity[_rarity];
    }

    function getLengthPerRarity(string memory _rarity) public view returns(uint256 length){
        return quantityPerRarity[_rarity].length;
    }


    function setPauseRelic(uint256[] memory _idTokens,bool[] memory _pauses) public {
        require(_idTokens.length == _pauses.length,"ERC1155: _idTokens and _pauses length mismatch");
        require(hasRole(MINTER_ROLE, _msgSender()),"ERC1155: must have minter role to pause");
        
        for (uint256 index = 0; index < _idTokens.length; index++) {
            if(exists(_idTokens[index])){
                relicPause[_idTokens[index]]=_pauses[index];
            }
        }
    }

    function relicInPause(uint256 _idToken) view public returns(bool inPause) {
        return relicPause[_idToken];
    }

    function getRelic(uint256 _idToken) view public 
    returns( 
        uint256 idToken,
        string memory name,
        uint256 mulReferral,
        uint256 mulNFT,
        uint256 div,
        string memory history,
        string memory rarity) 
    {
        
        if(!exists(_idToken) || relicInPause(_idToken)){
          return (_idToken,"",0,0,10,"","");
        }
         idToken=_idToken;
         name=relics[_idToken].name;
         mulReferral=relics[_idToken].mulReferral;
         mulNFT=relics[_idToken].mulNFT;
         div=relics[_idToken].div;
         history =relics[_idToken].history;
         rarity=relics[_idToken].rarity;
    }



      function mint(
        address account,
        uint256 idToken,
        uint256 amount,
        bytes memory data
    ) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC1155: must have minter role to mint"
        );
        require(idToken > 0,"ERC1155: the idToken must to be > 0");
        _mint(account,idToken,amount,data);
    }

     function mintBatch(
        address account,
        uint256[] memory idTokens,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
         require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC1155: must have minter role to mint"
        );

        for (uint256 index = 0; index < idTokens.length; index++) {
            require(idTokens[index] > 0,"ERC1155: the idToken must to be > 0");
        }
        

        _mintBatch(account, idTokens, amounts, data);
    }
    
     function burn(
        address account,
        uint256 id,
        uint256 amount
    ) public virtual  {
          require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _burn(account, id, amount);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        _burnBatch(account, ids, amounts);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerable, ERC1155)
        returns (bool)
    {
        return
            interfaceId == type(ERC1155Supply).interfaceId ||
            super.supportsInterface(interfaceId);
    }
  

    function setURI(string memory newuri)
        public
        virtual
    {
         _setURI(newuri);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }


    
}