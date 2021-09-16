// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KICharacter is ERC721Enumerable , ERC721Burnable, Ownable {
    using SafeMath for uint256; 

    constructor() ERC721("KICharacter","KIC"){
        CharacterRule memory cr;
        charactersRules.push(cr);

        Character memory c;
        characters.push(c);
    } 

    uint256 private DIV= 10**18;

    struct CharacterRule{
        uint256 idRarity;

        uint256 baseReward;
        //inner power that  KI expends; +innerPower == -KI expends
        // es un numero que ayuda a calcular la resistencia que tiene para gastar su ki
        // este numero ayuda que el ki del personaje no se gaste tan rapido, (mas raro mas resistencia tiene asi nos e gasta su KI rapido)
        uint256 innerPower;
        // difficult for level up (level)
        //dificultad de aumntar de nivel cuanto mas raro  mas facil sube de nivel (cuanto mas alta la difucltad mas le cuesta subir)
        uint256 dificult;
        // for you can level up and calculate the new level cost  
        uint256 valueBaseKiBurnNewLevel;
        // KI Burn for seconds;
        uint256 kiBurnByBlock;

    }

    struct Character{
        uint256 idCharacterRule;
        //the size array is the level and the amount storage in each index is te KI Burn;
        uint256 currentLevel;
        // amount KI for you can FARM; if KI == 0 you can't FARM
        //KI is spend for the timestamp (time) and the NFT Training
        uint256 ki;
        //timestamp, the last rechargue the KI;
        uint256 lastUpKi;
    }

    string[] private raritys; 
    uint256 private valueKiBurnByTime;    

    CharacterRule[] private charactersRules;
    Character[] private characters;

    function getRaritys(uint256 _index) public view returns(string memory ) {
        return raritys[_index];
    }
    function getLengthRaritys() public view returns(uint256 ) {
        return raritys.length;
    }

    function getValueKiBurnByTime() public view returns(uint256 ) {
       return valueKiBurnByTime;
    }

    function getCharacterRule(uint256 _id) public view returns(CharacterRule memory characterRule) {
       return charactersRules[_id];
    }

    function getLengthCharactersRules() public view returns(uint256 ) {
        return charactersRules.length;
    }
    

    function getBaseReward(uint256 _idCharacter) public view returns(uint256 baseReward) {
       return charactersRules[characters[_idCharacter].idCharacterRule].baseReward;
    }
    function getCurrentKi(uint256 _idCharacter) public view returns(uint256) {
       return characters[_idCharacter].ki;
    }
    function getCurrentLevel(uint256 _idCharacter) public view returns(uint256 currentLevel) {
       return characters[_idCharacter].currentLevel;
    }
     function getCharacterFull(uint256 _idCharacter) public view returns(  uint256 currentLevel,
       uint256 ki,uint256 lastUpKi,string memory rarity,uint256 baseReward,uint256 innerPower,
        uint256 dificult,uint256 valueBaseKiBurnNewLevel,uint256 kiBurnByBlock) {

      CharacterRule memory _characterRule= charactersRules[characters[_idCharacter].idCharacterRule];
      Character memory _character= characters[_idCharacter];
       return (_character.currentLevel,_character.ki,_character.lastUpKi,raritys[_characterRule.idRarity],_characterRule.baseReward,_characterRule.innerPower,
       _characterRule.dificult,_characterRule.valueBaseKiBurnNewLevel,_characterRule.kiBurnByBlock  );
       
       }
       
    function getCharacter(uint256 _id) public view returns(Character memory character) {
       return characters[_id];
    }
      function getLengthCharacters() public view returns(uint256 ) {
        return characters.length;
    }


    function addRarity(string memory _name ) public onlyOwner {
        raritys.push(_name);
    }
    function editRarity(uint256 _index,string memory _name ) public onlyOwner {
        raritys[_index]=_name;
    }

    function editValueKiBurnByTime(uint256 _value) public {
        valueKiBurnByTime=_value;
    }

    function addCharacterRule(CharacterRule memory _characterRule) public onlyOwner {
        require(_characterRule.idRarity < raritys.length);
        charactersRules.push(_characterRule);
    }

    function _addCharacter( Character memory _character) internal {
        require(_character.idCharacterRule < charactersRules.length );
        characters.push(_character);
    }


    // crear un token copiando los atributos del otro
    function mintCopy(address _to, uint256 _characterId,uint256 _amount) public onlyOwner {
        require(ownerOf(_characterId) == address(this));
        Character storage _character= characters[_characterId] ;
        mint(_character,_to,_amount);
    }

    function upKi(uint256 idCharacter) public {
        
    }

    function spendKi(uint256 idCharacter,uint256 spend) public onlyOwner  returns(uint256 newKi) {
        if(characters[idCharacter].ki <= spend){
           characters[idCharacter].ki=0; 
           return 0;
        }
        spend= spend.sub((spend.mul(charactersRules[characters[idCharacter].idCharacterRule].innerPower)).div(DIV));
        characters[idCharacter].ki-= characters[idCharacter].ki.sub(spend);
        return characters[idCharacter].ki;
    }


    function mint( Character memory _character, address _to,uint256 _amount) public onlyOwner {

        require(charactersRules[_character.idCharacterRule].innerPower <= DIV);
        for (uint256 index = 0; index < _amount; index++) {
           uint256 _id=characters.length; 
           _addCharacter(_character);
        //    _beforeTokenTransfer(address(0),_to,_character.id);
           _safeMint(_to,_id);
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