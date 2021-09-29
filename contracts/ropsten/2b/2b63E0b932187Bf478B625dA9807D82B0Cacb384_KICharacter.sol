// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Operator.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract KICharacter is ERC721Enumerable , ERC721Burnable, Operator {
    using SafeMath for uint256; 


    constructor() ERC721("KICharacter","KIC"){
        CharacterRule memory cr;
        charactersRules.push(cr);
        operators[_msgSender()]=true;
        Character memory c;
        characters.push(c);
    } 



    uint256 private DIV= 10**18;

    struct CharacterRule{
        uint256 idRarity;
        string name;
        uint256 baseReward;
        //inner power that  KI expends; +innerPower == -KI expends
        // es un numero que ayuda a calcular la resistencia que tiene para gastar su ki
        // este numero ayuda que el ki del personaje no se gaste tan rapido, (mas raro mas resistencia tiene asi nos e gasta su KI rapido)
        uint256 innerPower;
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

    function getCharacterRule(uint256 _id) public view returns(uint256 idRarity,string memory name,uint256 baseReward,
        uint256 innerPower,uint256 valueBaseKiBurnNewLevel,uint256 kiBurnByBlock) {
       idRarity=charactersRules[_id].idRarity;
       name=charactersRules[_id].name;
       baseReward=charactersRules[_id].baseReward;
       innerPower=charactersRules[_id].innerPower;
       valueBaseKiBurnNewLevel=charactersRules[_id].valueBaseKiBurnNewLevel;
       kiBurnByBlock=charactersRules[_id].kiBurnByBlock;
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
    //valor para subir de nivel y valor para almacenar energia en el personaje
    function getValueBaseKiBurnNewLevel(uint256 _idCharacter) public view returns(uint256 valueBaseKiBurnNewLevel) {
       return charactersRules[characters[_idCharacter].idCharacterRule].valueBaseKiBurnNewLevel;
    }
    
    function getCharacterFull(uint256 _idCharacter) public view returns( uint256 currentLevel,
       uint256 ki,uint256 lastUpKi,string memory rarity,uint256 baseReward,uint256 innerPower,
        uint256 valueBaseKiBurnNewLevel,uint256 kiBurnByBlock) {

      CharacterRule memory _characterRule= charactersRules[characters[_idCharacter].idCharacterRule];
      Character memory _character= characters[_idCharacter];
       return (_character.currentLevel,_character.ki,_character.lastUpKi,raritys[_characterRule.idRarity],_characterRule.baseReward,_characterRule.innerPower,
       _characterRule.valueBaseKiBurnNewLevel,_characterRule.kiBurnByBlock  );
       
       }
       
    function getCharacter(uint256 _id) public view returns(   uint256 idCharacterRule,uint256 currentLevel,uint256 ki,uint256 lastUpKi) {
       idCharacterRule=characters[_id].idCharacterRule;
       currentLevel=characters[_id].currentLevel;
       ki=characters[_id].ki;
       lastUpKi=characters[_id].lastUpKi;
    }

      function getLengthCharacters() public view returns(uint256 ) {
        return characters.length;
    }



    function addRarity(string memory _name ) public onlyOperator {
        raritys.push(_name);
    }
    
    function editRarity(uint256 _index,string memory _name ) public onlyOperator {
        raritys[_index]=_name;
    }

    function editValueKiBurnByTime(uint256 _value) onlyOwner public {
        valueKiBurnByTime=_value;
    }

    function addCharacterRule(uint256 idRarity,string memory name, uint256 baseReward,
        uint256 innerPower,uint256 valueBaseKiBurnNewLevel,uint256 kiBurnByBlock) public onlyOperator {
        require(idRarity < raritys.length);
        charactersRules.push(CharacterRule( idRarity,name, baseReward,
         innerPower,  valueBaseKiBurnNewLevel, kiBurnByBlock));
    }

    function _addCharacter( Character memory _character) internal {
        require(_character.idCharacterRule < charactersRules.length );
        characters.push(_character);
    }



    //dificultad extra para subir de nivel.
    //retorna la cantidad de ki que no se uso.
    function upKi(uint256 idCharacter,uint256 newAmountKi,uint256 dificultEx,bool levelUp) public onlyOperator returns(uint256 ki) {
    uint256 restKi=newAmountKi;
    uint256 lvl=characters[idCharacter].currentLevel;
    uint256 valueBaseKiBurnNewLevel= charactersRules[characters[idCharacter].idCharacterRule].valueBaseKiBurnNewLevel;
       if(levelUp){
           uint256 kiTotal=characters[idCharacter].ki;
         
        while(newAmountKi != 0){
            if(valueBaseKiBurnNewLevel.sub(kiTotal) <= newAmountKi ){
                lvl++;
                valueBaseKiBurnNewLevel= valueBaseKiBurnNewLevel.add(valueBaseKiBurnNewLevel.mul(dificultEx).div(DIV));
                newAmountKi=newAmountKi.sub(valueBaseKiBurnNewLevel.sub(kiTotal));
                kiTotal=0;
            }else{
                kiTotal=newAmountKi;
                newAmountKi=0;
            }
        }
        characters[idCharacter].ki=kiTotal;
        characters[idCharacter].currentLevel=lvl;
       }else{
           if(lvl == 0){lvl=1;}
           if(lvl.mul(valueBaseKiBurnNewLevel) < characters[idCharacter].ki.add(newAmountKi) ){
               //la cantidad de Ki que se puede usar para llenar el limite
               newAmountKi= lvl.mul(valueBaseKiBurnNewLevel).sub(characters[idCharacter].ki);
               //cantidad de ki que sobra porque o sino supera el limite del nivel
               restKi=restKi.sub(newAmountKi);
           }
           //lleno la barra di ki con la cantidad pedidoa
                characters[idCharacter].ki= characters[idCharacter].ki.add(newAmountKi);
       }
       // devuelve la cantidad de KI que se usó.
        return restKi;
    }
//obtener la cantidad de ki que puede almacenar el personaje sin subir de nivel.
    function getLimitKi(uint256 idCharacter) view public returns(uint256) {
        uint256 valueBaseKiBurnNewLevel= charactersRules[characters[idCharacter].idCharacterRule].valueBaseKiBurnNewLevel;
        uint256 lvl=characters[idCharacter].currentLevel;
        if(lvl == 0){
            lvl=1;
        }
        return lvl.mul(valueBaseKiBurnNewLevel);
    }

    function spendKi(uint256 idCharacter,uint256 spend) public onlyOperator  returns(uint256 newKi) {
        if(characters[idCharacter].ki <= spend){
           characters[idCharacter].ki=0; 
           return 0;
        }
        spend= spend.sub((spend.mul(charactersRules[characters[idCharacter].idCharacterRule].innerPower)).div(DIV));
        characters[idCharacter].ki-= characters[idCharacter].ki.sub(spend);
        return characters[idCharacter].ki;
    }

    // crear un token copiando los atributos del otro
    function mintCopy(address _to, uint256 _characterId,uint256 _amount) public onlyOperator {
        require(ownerOf(_characterId) == address(this));
        Character storage _character= characters[_characterId] ;
        mint(_character.idCharacterRule,_to,_amount);
    }

    function mint( uint256 idCharacterRule, address _to,uint256 _amount) public onlyOperator {
        Character memory _character= Character(idCharacterRule,0,0,block.number);

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