// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./KICharacter.sol";

import "./Knowledge.sol";

import "./KiToken.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TrainingFarm is Ownable {
    using SafeMath for uint256; 

    constructor(KICharacter _KICharacter,Knowledge  _knowledgeContract,KiToken  _kiTokenContract){
        characterContract=_KICharacter;
        knowledgeContract=_knowledgeContract;
        kiTokenContract=_kiTokenContract;
    }

    KICharacter characterContract;
    Knowledge knowledgeContract;
    KiToken kiTokenContract;

    address devAddress;
    // cost for Defrost the technique;
    uint256 payDefrost;

    //LVL => Amount Characters
    mapping (uint256=>uint256) private countCharacterByLevel;
    
    // LVL most  higth   
    uint256 private HIGHEST_LEVEL;
    // Level with most Characters
    uint256 private LEVEL_WITH_MORE_CHARACTERS;



    struct CharacterPool{
        uint256[] idTechniques;
        uint256 numberBlock;
    }

    struct InfoTechnique{
        uint256 startFrozen;
        uint256 startFarm;
        uint256 countUses;
    }
    //idCharacter
    mapping (uint256=>CharacterPool) characterPool;
    //id Techniques => count uses
    mapping (uint256=>InfoTechnique) infoTechniques;
    //idCharacter => owner
    mapping (uint256=>address) ownerCharacter;
    //idTechnique => owner
    mapping (uint256=>address) ownerTechnique;
    //id Technique => id character
    mapping (address=>uint256[]) ownerOfCharacters;
    mapping (uint256=>uint256) characterByTechniques;
    
    function addPool( 
        uint256 idCharacter,
        uint256[] memory idTechniques) public returns(uint256 success) {
        CharacterPool memory cPool;
        uint256 bNumber=block.number;
        success=0;

        if(ownerCharacter[idCharacter] == address(0) ){
            characterContract.transferFrom(_msgSender(),address(this),idCharacter);
            ownerCharacter[idCharacter]=_msgSender();
            ownerOfCharacters[_msgSender()].push(idCharacter);
            uint256 lvl=characterContract.getCurrentLevel(idCharacter);
            countCharacterByLevel[lvl]++;
            if((countCharacterByLevel[LEVEL_WITH_MORE_CHARACTERS] < countCharacterByLevel[lvl])){
                LEVEL_WITH_MORE_CHARACTERS=lvl;
            }
        }

        if((idTechniques.length > 0)){
            uint256 amountUses=0;
            cPool.idTechniques= new uint256[](idTechniques.length);
            for (uint256 index = 0; index < idTechniques.length; index++) {
                knowledgeContract.transferFrom(_msgSender(),address(this),idTechniques[index]);
                cPool.idTechniques[index]=(idTechniques[index]);
                characterByTechniques[idCharacter]=idTechniques[index];
                ownerTechnique[idTechniques[index]]=_msgSender(); 
                amountUses=knowledgeContract.getAmountUses(idTechniques[index]);
                success++;
                if(amountUses > infoTechniques[idTechniques[index]].countUses){
                    infoTechniques[idTechniques[index]].startFarm=bNumber;
                }                           
            }
        }
        //hacer un metodo que calcule si tiene recompensa y actualice los atributos del pool llamarlo aca
        cPool.numberBlock=bNumber;
        characterPool[idCharacter]=(cPool);

        return success;
    }

    function withdrawPool(uint256 idCharacter,uint256[] memory idTechniques) public {
        claimPool(idCharacter);
        emergencyWithdraw(idCharacter, idTechniques);            
    }

    //withdraw NFT without reward
    function emergencyWithdraw(uint256 idCharacter,uint256[] memory idTechniques) public {
        
         if(idCharacter > 0){
             require(ownerCharacter[idCharacter] == _msgSender());
            _blankValuePool(idCharacter);

            ownerCharacter[idCharacter]=address(0);
            characterContract.transferFrom(address(this),_msgSender(),idCharacter);

            for (uint256 j = 0; j < ownerOfCharacters[_msgSender()].length; j++) {
                if(ownerOfCharacters[_msgSender()][j] == idCharacter){
                    ownerOfCharacters[_msgSender()][j]=ownerOfCharacters[_msgSender()][ ownerOfCharacters[_msgSender()].length-1];
                    ownerOfCharacters[_msgSender()].pop();
                    break;
                }
            }
            idTechniques= new uint256[](characterPool[idCharacter].idTechniques.length);
             for (uint256 j = 0; j < idTechniques.length; j++) {
                 idTechniques[j]=characterPool[idCharacter].idTechniques[j];
            }            
        }

            for (uint256 index = 0; index < idTechniques.length; index++) {
                if(_msgSender() == ownerTechnique[idTechniques[index]]){
                    knowledgeContract.transferFrom(address(this),_msgSender(),idTechniques[index]);
                    ownerTechnique[idTechniques[index]]=address(0);

                    for (uint256 j = 0; j < characterPool[characterByTechniques[idTechniques[index]]].idTechniques.length; j++) {
                        if(characterPool[characterByTechniques[idTechniques[index]]].idTechniques[j] == idTechniques[index]){
                            characterPool[characterByTechniques[idTechniques[index]]].idTechniques[j]=characterPool[characterByTechniques[idTechniques[index]]].idTechniques[characterPool[characterByTechniques[idTechniques[index]]].idTechniques.length -1];
                            characterPool[characterByTechniques[idTechniques[index]]].idTechniques.pop();
                        }
                    }
                    characterByTechniques[idTechniques[index]]=0;
                }
            }
    }
    //antes de quitar un personaje 
    function _blankValuePool(uint256 idCharacter) internal{
        if(ownerCharacter[idCharacter] != address(0)){
            uint256 lvl=characterContract.getCurrentLevel(idCharacter);
            uint256 countMaxCharacter=0;
            uint256 lvlMaxCharacter=0;

            countCharacterByLevel[lvl]--;
            
        
            //encuentro el nuevo nivel de piso 
           for (uint256 index = 0; index <= HIGHEST_LEVEL; index++) {
               if(countCharacterByLevel[index] > countMaxCharacter){
                   countMaxCharacter=countCharacterByLevel[index];
                   lvlMaxCharacter=index;
               }
           }
            LEVEL_WITH_MORE_CHARACTERS=lvlMaxCharacter;

            //asigno el nuevo nivel maximo
            if((HIGHEST_LEVEL <= lvl) ){
                while((countCharacterByLevel[lvl] == 0)&&(lvl > 0 )){
                    lvl--;
                }
                HIGHEST_LEVEL=lvl;
            }
            
        }
       
    }


    function claimPool(uint256 idCharacter) public returns(uint256){
        //si dejo comentado cualquier puede reclamar pero el token siempre recibe el dueño del NFT
        // require(ownerCharacter[idCharacter] == _msgSender());

        (uint256 reward,uint256 kiRest,uint256[] memory usesTechnique) = pendingReward(idCharacter);

        kiTokenContract.mint(ownerCharacter[idCharacter],reward);
        //solo quema el KI si es menor al nivel mas algo o si el nivel mas alto tiene mas de 10 NFT Character.
        if((characterContract.getCurrentLevel(idCharacter)< HIGHEST_LEVEL ) || ( countCharacterByLevel[HIGHEST_LEVEL] > 10)){
             characterContract.spendKi(idCharacter,kiRest);
        }
        
        uint256 blockNumber=block.number;
        uint256 amountFinish=0;
        for (uint256 index = 0; index < usesTechnique.length; index++) {

            if(usesTechnique[index]>0){
                uint256 idTech=characterPool[idCharacter].idTechniques[index];
                uint256 amountUses=knowledgeContract.getAmountUses(idTech);

                if(amountUses <= infoTechniques[idTech].countUses.add(usesTechnique[index])){
                    infoTechniques[idTech].countUses=amountUses;
                    infoTechniques[idTech].startFrozen=blockNumber;

                }else{
                    amountFinish=knowledgeContract.getAmountFinish(idTech);
                    infoTechniques[idTech].countUses=infoTechniques[idTech].countUses.add(usesTechnique[index]);
                    //new block started equals the amount for farm finish  multiplicate the amount repeat.
                    infoTechniques[idTech].startFarm=infoTechniques[idTech].startFarm.add(usesTechnique[index].mul(amountFinish));
                }
                
                
            }
        }
        return reward;
    }




    //quitar el quemado de  KI por BLocque, no tiene el ca clulo se complica
    //auxRepeat the amount repeat the NFT Technical by  INDEX;
    function pendingReward(uint256 idCharacter) view public returns (uint256 reward,uint256 kiRest,uint256[] memory auxRepeat) {
        uint256 lengthTech=characterPool[idCharacter].idTechniques.length;
        //use to the code finish

        if(lengthTech == 0){
            return  (0,0,auxRepeat);
        }   
         uint256 kiNow= kiCurrent(idCharacter);
        
        if(kiNow == 0){
            return  (0,0,auxRepeat);
        }
        
        uint256 __id=idCharacter;
        (uint256 currentLevel,
        ,,,uint256 baseReward,,,)=characterContract.getCharacterFull(__id);
        
        uint256[] memory profitArray = new uint256[](lengthTech);
        uint256[] memory repeatArray =new uint256[](lengthTech);
        uint256[] memory burnKiArray=new uint256[](lengthTech);
        uint256 kiResta=kiNow;
        uint256 totalRepeat=0;

        for (uint256 index = 0; index < lengthTech; index++) {
            (uint256 startFrozen,uint256 amountUses)=isFronzen(characterPool[__id].idTechniques[index]);
            // if((infoTechniques[characterPool[__id].idTechniques[index]].startFrozen.add(knowledgeContract.getAmountFronzen(characterPool[__id].idTechniques[index])) >= bNumber )){
            if((startFrozen > 0 ) && (startFrozen <= infoTechniques[characterPool[__id].idTechniques[index]].startFarm )){
            profitArray[index]=0;repeatArray[index]=0;burnKiArray[index]=0;
            }else{
            //nuevo
            repeatArray[index]=amountUses;
            //farmeó antes de congelarse.
            (profitArray[index],/*repeatArray[index],*/burnKiArray[index])=profitByTechnique(characterPool[__id].idTechniques[index]);             
             if((kiNow < burnKiArray[index])||(profitArray[index] == 0)){
                profitArray[index]=0;repeatArray[index]=0;burnKiArray[index]=0;
             }else{
                kiNow=kiNow.sub(burnKiArray[index]);
                totalRepeat=totalRepeat.add(repeatArray[index]);
             }
            }
          
          
           
        }
        uint256 reward2=0;
        kiNow=kiResta;
        //controlar si anda
        //calcula la cantidad exacta de recompensa que se optiene gastando KI
        auxRepeat= new uint256[](repeatArray.length);
        while((kiNow>0) && (totalRepeat>0)){
            for (uint256 index = 0; index < profitArray.length; index++) {
                if((repeatArray[index] > 0)&&(kiNow >= burnKiArray[index] )){
                    reward2= reward2.add(baseReward.mul(profitArray[index]));
                    kiNow= kiNow.sub(burnKiArray[index]);
                    repeatArray[index]--;
                    auxRepeat[index]++;
                    totalRepeat--;
                }
                
            }
        }

        reward2=reward2.div(knowledgeContract.getDiv());
        if(currentLevel < LEVEL_WITH_MORE_CHARACTERS){
            reward2= reward2.div(2);
        }
    return (reward2,kiResta.sub(kiNow),auxRepeat);
    }
    //reward= 
    function profitByTechnique(uint256 idTechnique/*,uint256 startFrozen*/) view public returns (uint256 profit,/*uint256 repeat,*/uint256 burnKi) {
    
        // uint256 currentBlock=block.number;
        // uint256 _amountUsesTechniques=0;

           (,
            ,
            ,
            uint256 _burnKi,
            uint256 _profit,
            /*uint256 amountUses*/,
            ,
            /*uint256 amountFinish*/,)= knowledgeContract.getTechnique(idTechnique);
            
            // if(amountUses <=  infoTechniques[idTechnique].countUses){
            //     return (0,0,0);
            // }
            // uint256 id=idTechnique;
            // uint256 count=currentBlock.sub(infoTechniques[id].startFarm);
            // //primero se farmeo y despues se congelo (tiene que pagar para descongelar)
            // if((startFrozen >= infoTechniques[idTechnique].startFarm) || ( startFrozen==0)){
            //     count= startFrozen.sub(infoTechniques[idTechnique].startFarm);                    
            // }else{
            //     //quiso farmear pero la tecnica esta congelada.
            //     return  (0,0,0);
            // }

            // while(count >= amountFinish ){
            //     count-=amountFinish;
            //     _amountUsesTechniques++;
            // }
        return (_profit,/*_amountUsesTechniques,*/_burnKi);
    }

    function kiCurrent(uint256 idCharacter) view public returns (uint256 ki) {
         ki=characterContract.getCurrentKi(idCharacter);
        return ki;
    }

    function upKi(uint256 idCharacter,uint256 amount,bool levelUp) public  returns(uint256 newAmountKi){
        require(ownerCharacter[idCharacter] == _msgSender());
        claimPool(idCharacter);
        //dificultad para subir de nivel segun las distancias que hay en la piramide calcular
        // es usado para calcular le porcentaje que hay que sumasr al costo total para subir de nivel.
        uint256 dificultEx=0;
       uint256 lvl=characterContract.getCurrentLevel(idCharacter);
       uint256 value=characterContract.getValueBaseKiBurnNewLevel(idCharacter);
       uint256 medLvl=HIGHEST_LEVEL.div(2);
       if(lvl>medLvl){ 
            if(HIGHEST_LEVEL.sub(lvl) == 0){
                dificultEx=value.mul(20).div(100);
            }else{
                dificultEx= value.mul(10).div(100);
            }
       }
       newAmountKi= characterContract.upKi(idCharacter,amount,dificultEx,levelUp);
       //se quema solo la cantidad que se usó.
       kiTokenContract.burnFrom(_msgSender(),newAmountKi);
        
    }

    //
    function isFronzen(uint256 idTechnique) public view returns(uint256 startFrozen,uint256 uses) {
        if(infoTechniques[idTechnique].startFrozen > 0){
            return (infoTechniques[idTechnique].startFrozen ,infoTechniques[idTechnique].countUses);
        }
        
        uses=infoTechniques[idTechnique].countUses;
        uint256 amountFinish=knowledgeContract.getAmountFinish(idTechnique);
        uint256 amountUses=knowledgeContract.getAmountUses(idTechnique);
        startFrozen=0;
        uint256 farmCurrent = block.number.sub(infoTechniques[idTechnique].startFarm);
        while((uses < amountUses) && (farmCurrent > 0)){
            if(farmCurrent >= amountFinish ){
                farmCurrent=farmCurrent.sub(amountFinish);
                //acumula la cantidad de bloques que se recorrieron.
                startFrozen=startFrozen.add(amountFinish);
            }else{
                farmCurrent=0;
            }
            uses=uses.add(1);
        }
        //el start comienza en un momento cuando se farmeaba y nuca se retiró cuando se congeló.
        //se supero la cantidad de usos que podia teener la tecnica
        if((uses >= amountUses)){
            //se obtiene exactamente el numero de bloque que empezo el startFrozen;
            startFrozen=startFrozen.add(infoTechniques[idTechnique].startFarm);
        }else{
            startFrozen=0;
        }
        return (startFrozen,uses);
    }

        function reduceFrozen(uint256 payment,uint256 idTechnique) public {
            require(payment == payDefrost);
            require(infoTechniques[idTechnique].startFrozen > 0);
            infoTechniques[idTechnique].startFrozen=  0;
            infoTechniques[idTechnique].countUses=0;
            infoTechniques[idTechnique].startFarm=  block.number;
            kiTokenContract.transferFrom(_msgSender(),devAddress,payment);
    }
}