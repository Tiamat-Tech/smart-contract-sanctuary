/**
 *Submitted for verification at Etherscan.io on 2022-02-21
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

library SafeMath {
  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    if (a == 0) {
      return 0;
    }
    c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
    c = a + b;
    assert(c >= a);
    return c;
  }
}


contract EvuStaking {
    using SafeMath for uint;
    //Estableces contrato del token para Staking
    IERC20 public stakingToken;
    //Estrutura de variable deposito de staking
    //Amount : monto depositados del usuario
    //initTime ; Fecha de deposito del token
    //endLock: Fecha de debloqueo de token
    //status: Estado de la wallet para ganar o no
    //wrewars: Token Retirado de gancia
    //rewars: Token Ganado
    struct Staking{
        uint amount;
        uint rewards;
        uint initTime;
        uint endLock;
        uint wreward;
        uint lastrewards;
        uint initpcent;
    }
    /////POR CIENTO DEL API %/////////////////
    uint private Percent = 250;
    
    //Establecer porcentaje de ganacias por mes
    //Cada nuemero representa un % y un mes desde la posicion 0

    uint[] private Meses = [2,3,4,6,7,8,9,10,11,12,14,14];
 
    address[] public qwallets;
    mapping(address => bool) private _existe;
    /////Estableces Variables Necesarias/////
    // 14 DIAS, 30 DIAS, 90 DIAS, 180 DIAS, 180 DIAS
    uint private undia = 1 days;
    uint public currentTime = block.timestamp;
    mapping(address => Staking[]) public qTokenStake;
    uint public _totalSupply;
    mapping(address => uint) private _balances;
    ///Declarar owen
    address public owen;
   //VARIABLE DE ESTADO True and False
    bool private active = true;
    
    constructor(address _addresToken,address _addressOwen){
        stakingToken = IERC20(_addresToken);
        owen = _addressOwen;
    }

    ///porcentages por meces
    function getTotalRewards(address _addr, uint _index) public view returns(uint) {
        ///  require(qTokenStake[_addr][_index].amount > 0,"getTotalRewards: No tienes fondos suficientes...");
        //Multiplicar monto  de stake por el porciento del mes =  renta mensual / 30 dias
        ///PROBLEMA SE RECIBE UN DECIMAL POR TANTO NO ES SOLUCION
       // uint _tamount = qTokenStake[_addr][_index].amount.div(100);
        uint _tamount = qTokenStake[_addr][_index].amount;
        uint _result = 0;
        uint endLock = 0;
         _result+=(qTokenStake[_addr][_index].rewards);
         if(qTokenStake[_addr][_index].endLock > qTokenStake[_addr][_index].lastrewards){
           endLock = qTokenStake[_addr][_index].endLock.sub(qTokenStake[_addr][_index].lastrewards);
        
        uint _rewardSec = block.timestamp.sub(qTokenStake[_addr][_index].lastrewards);

        uint qmes = 1;
        if(_rewardSec > 30 days){
            qmes = (_rewardSec / 30 days) +1;
        }
        
        if(_rewardSec > endLock && endLock > 30 days){
            qmes = endLock / 30 days;
        }
        if(_rewardSec < 30 days){
            qmes = 1;
        }
    

        
       // uint tsegundos = _totalSec;
        if(_rewardSec > endLock){
            _rewardSec = endLock;
        }
  
        uint totals;
        uint _c = qTokenStake[_addr][_index].initpcent;
       
         totals = _rewardSec;//gs.sub(_mdias);
        for(uint i = 1; i<=qmes; i++){      
             if(_c >= 11 ){
                _c = 11;
               }
                if(i<2){
                  if(_rewardSec < 30 days){
                    _result  += _rewardSec * getPaymonSec(_tamount,_c);  
                    
                  }else{
                    _result  += 30 days * getPaymonSec(_tamount,_c);  
                    totals -= 30 days;
                  }
                }else{
                    
                    if(totals >= 30 days){
                      _result += 30 days * getPaymonSec(_tamount,_c);  
                      totals -= 30 days;
                    }else{
                      _result += totals * getPaymonSec(_tamount,_c);  
                    }
                }
        
             _c++;
        }

           
           // _result-=qTokenStake[_addr][_index].wreward;
         }
       
            return _result;
        
    } 
    //////////////OPTENER POR CIENTO/////////////////////
    function getPercent(uint _mes) public view returns(uint){
      ///  uint _pg = Percent / 100;
    
       return  Percent * Meses[_mes];
    }
    ////////////Optener Monto pagado por segundo////////////////
    function getPaymonSec(uint _amount,uint _mes) public view returns(uint){ 
       return ((_amount * getPercent(_mes)) / 10000) / 30 days;
    }
    /////////Funcion de aprobacion de deposito//////////////
    //Esto debe hacerse para poder enviar los token al contrato
    /* function aprobar(address _spender, uint256 _value) external {
      stakingToken.approve(_spender,_value); 
    }*/
    /////////Desposito al contrato de Staking//////////////
    function stake(uint _amount,uint _dias) external {
         uint qdias = _dias.mul(undia) + block.timestamp;
         qTokenStake[msg.sender].push(Staking(_amount,0,block.timestamp,qdias,0,block.timestamp,0)); 
        _totalSupply += _amount;
         stakingToken.transferFrom(msg.sender, address(this), _amount);
          if (!_existe[msg.sender]) {
            qwallets.push(msg.sender);
        }
           _existe[msg.sender] = true;
    }
    /////////ReStaking: luego de terminar el tiempo de staking agregarlo de nuevo///////////////
    function restaking(uint _dias,uint _index) public returns(bool){
         require(qTokenStake[msg.sender][_index].amount > 0,"restaking: No tienes fondos suficientes...");
         uint qdias = _dias.mul(undia) + block.timestamp;
         qTokenStake[msg.sender][_index].rewards = getTotalRewards(msg.sender, _index);
         qTokenStake[msg.sender][_index].endLock = qdias;
         qTokenStake[msg.sender][_index].lastrewards = block.timestamp;
         qTokenStake[msg.sender][_index].initpcent = (block.timestamp.sub(qTokenStake[msg.sender][_index].initTime) / 30 days)+1;
         return true;
    }
    //////////Retirar Dinero del Staking//////////////////
    ///recuerda revisar esto
    function unStaking(uint _index) public returns(bool) {
       require(qTokenStake[msg.sender][_index].amount > 0,"unStaking: No tienes fondos suficientes...");
       require(block.timestamp > qTokenStake[msg.sender][_index].endLock,"unStaking lock: fondos bloqueados...");
        _totalSupply -= qTokenStake[msg.sender][_index].amount;
         uint reward2 = getTotalRewards(msg.sender, _index);
         uint totalg = reward2 + qTokenStake[msg.sender][_index].amount;
         stakingToken.transfer(msg.sender,totalg);
         qTokenStake[msg.sender][_index].amount = 0;
         qTokenStake[msg.sender][_index].rewards = 0;
         qTokenStake[msg.sender][_index].initTime = 0;
         qTokenStake[msg.sender][_index].endLock = 0;
         qTokenStake[msg.sender][_index].lastrewards = 0;
        return true;
    }
    ////////Reclamar recompenza ganada por Staking/////////////////////
    function ClaimReward(uint _index) public returns(bool) {
        uint reward = getTotalRewards(msg.sender, _index);
        require(reward > 0,"No tienes recomenpenzas...");
        stakingToken.transfer(msg.sender, reward);
        qTokenStake[msg.sender][_index].wreward += reward;
        qTokenStake[msg.sender][_index].rewards = 0;
        qTokenStake[msg.sender][_index].lastrewards = block.timestamp;
        qTokenStake[msg.sender][_index].initpcent = (block.timestamp.sub(qTokenStake[msg.sender][_index].initTime) / 30 days)+1;
        return true;
    }
    /////////modificador administrador///////////
    modifier AdminOwen(address _admin) {
            require(_admin == owen,"Usted no tiene autorizacion");
        _;
    }
    //////Modificar POR CIENTO ANUAL - SOLO ADMIN////////
   function ShowPercent() public  view returns(uint) {
          return Percent;
    }
 
     //////MODIFICAR POR CIENTO ANUAL - SOLO ADMIN////////
    function UpdatePercentRewards(uint _pcent) public AdminOwen(msg.sender) {
         Percent = _pcent;
        ///////Parsea todas las walllet/////////
        for (uint256 i = 0; i < qwallets.length; i++) {
            address _recipient = qwallets[i];
            uint _cadr = qTokenStake[_recipient].length;
            //////parseas las wallet por usuarios//////////
            for(uint _index = 0; _index < _cadr; _index++){
                uint reward = getTotalRewards(_recipient, _index);
                if(reward > 0){ 
                    qTokenStake[_recipient][_index].rewards += reward;
                    qTokenStake[_recipient][_index].lastrewards = block.timestamp;
                }
            }
        }
    }

    ///////Contar lista de inversion//////
     function getCount(address _addr) public view returns(uint){
        return qTokenStake[_addr].length;
    }

    //////Optenes lista de inversion////////
    function getAccounts(address _addr, uint _index) public view returns(uint,uint,uint,uint,uint,uint){
       return (
              qTokenStake[_addr][_index].amount,
              qTokenStake[_addr][_index].rewards,
              qTokenStake[_addr][_index].initTime,
              qTokenStake[_addr][_index].endLock,
              qTokenStake[_addr][_index].wreward,
              qTokenStake[_addr][_index].lastrewards
              );
    }
    
}
  ////INTERFACE NECESARIA PARA LAS RELAIZACION DE TRANZACIONES EN EL STAKING
  interface IERC20 {
      function totalSupply() external view returns (uint);

      function balanceOf(address account) external view returns (uint);

      function transfer(address recipient, uint amount) external returns (bool);

      function allowance(address owner, address spender) external view returns (uint);

      function approve(address spender, uint amount) external returns (bool);

      function transferFrom(
          address sender,
          address recipient,
          uint amount
      ) external returns (bool);

      event Transfer(address indexed from, address indexed to, uint value);
      event Approval(address indexed owner, address indexed spender, uint value);
  }