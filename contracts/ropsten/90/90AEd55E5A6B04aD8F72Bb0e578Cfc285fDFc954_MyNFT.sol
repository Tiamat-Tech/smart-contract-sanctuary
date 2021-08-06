// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract MyNFT is Context,AccessControlEnumerable,ERC1155Supply {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory uri_) ERC1155(uri_) {
        
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());

    }
    
  
    struct Relic{
        uint256 mulReferral;
        uint256 mulNFT;
        //time sleep in seconds
        uint256 sleep;
        //time for it is actived in seconds
        uint256 time;
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
    
    function addRelic(
        uint256 idToken,
        uint256 mulReferral,
        uint256 mulNFT,
        uint256 sleep,
        uint256 time,
        uint256 div,
        string memory history,
        string memory rarity) public returns (bool success) {
         require(
            hasRole(MINTER_ROLE, _msgSender()),
            "ERC1155: must have minter role to mint"
        );
        require(!exists(idToken), "ERC1155: The id already exists");

        Relic memory _relic= Relic( mulReferral,mulNFT,sleep,time,div,history,rarity);
        relics[idToken]=_relic;
        quantityPerRarity[rarity].push(idToken);
        return true;
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
        uint256 mulReferral,
        uint256 mulNFT,
        uint256 sleep,
        uint256 time,
        uint256 div,
        string memory history,
        string memory rarity) 
    {
        
        if(!exists(_idToken) || relicInPause(_idToken)){
          return (_idToken,0,0,0,0,10,"","");
        }
         idToken=_idToken;
         mulReferral=relics[_idToken].mulReferral;
         mulNFT=relics[_idToken].mulNFT;
         sleep=relics[_idToken].sleep;
         time=relics[_idToken].time;
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