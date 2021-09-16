// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Knowledge is ERC721Enumerable , ERC721Burnable, Ownable {
    using SafeMath for uint256; 
    constructor () ERC721("KiTechnique","KIT")  {
       idToken=1;
    }
    
    uint256 DIV = 10**18;
    
    struct Technique{
        uint256 idRarity;
        string name;
        string description;
        // KI necessary for Farm;
        uint256 burnKi;
        // Charcater Reward*profit / DIV;
        uint256 profit;
        //amount uses before frozen it;
        uint256 amountUses;
        //amount blocks for frozen
        uint256 amountFronzen;
        // the amount block for finish and you can claim;
        uint256 amountFinish;
        // if permanen NFT is 0, only used for temporal NFT
        uint256 deadLine;
    }

    uint256 private idToken;
    //Index Technique => Technique
    Technique[] private techniques;
    // ID Token ==> Index Technique;
    mapping (uint256=>uint256)  private idTechniqueByTokenId;

    string[] private raritys;

    function getDiv() view public returns (uint256) {
        return DIV;
    }
    function getIdToken() view public returns (uint256) {
        return idToken;
    }

    function getRarity(uint256 _index) view public returns (string memory) {
        return raritys[_index];
    }
    function getLengthRaritys() view public returns (uint256) {
        return raritys.length;
    }

    function getIdTechniqueByTokenId(uint256 _idToken) view public returns (uint256) {
        return idTechniqueByTokenId[_idToken];
    }

      function getLengthTechniques() view public returns (uint256) {
        return techniques.length;
    }


    function getTechnique(uint256 id) view public returns ( 
        uint256 idRarity,
        string memory name,
        string memory description,
        uint256 burnKi,
        uint256 profit,
        uint256 amountUses,
        uint256 amountFronzen,
        uint256 amountFinish,
        uint256 deadLine ) {

        idRarity=techniques[id].idRarity;
        name=techniques[id].name;
        description=techniques[id].description;

        burnKi=techniques[id].burnKi;
        profit=techniques[id].profit;
        amountUses=techniques[id].amountUses;
        amountFronzen=techniques[id].amountFronzen;

        amountFinish=techniques[id].amountFinish;
        deadLine=techniques[id].deadLine;
    }

    function getTechniqueProfit(uint256 _id) view public returns (uint256 profit) {
        return techniques[_id].profit;
    }
    
    function getAmountUses(uint256 _id) view public returns (uint256 amountUses) {
        return techniques[_id].amountUses;
    }
    function getAmountFinish(uint256 _id) view public returns (uint256 amountFinish) {
        return techniques[_id].amountFinish;
    }


    


    function addRarity(string memory _name) public onlyOwner{
        bool exist=false;
        
        for (uint256 index = 0; index < raritys.length; index++) {
            if(keccak256(bytes(_name)) == keccak256(bytes(raritys[index]))){
                exist=true;
                break;
            }
        }
        require(!exist);
        raritys.push(_name);
    }

    function _addTechnique(Technique memory _technique) public onlyOwner {
       techniques.push(_technique);
    }

    function mint(address _to,uint256 _idTechnique,uint256 _amount) public onlyOwner{
        require(_idTechnique < techniques.length );
        for (uint256 index = 0; index < _amount; index++) {
            _safeMint(_to,idToken);
            idTechniqueByTokenId[idToken]=_idTechnique;
            idToken++;
        }
    }



    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable,ERC721) {
        super._beforeTokenTransfer(from,to,tokenId);

    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable,ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
        
    }
}