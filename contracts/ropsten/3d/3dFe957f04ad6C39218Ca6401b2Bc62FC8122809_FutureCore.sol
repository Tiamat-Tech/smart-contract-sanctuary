pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./FutureERC20Token.sol";
import "./DETAILEDIERC20.sol";
// just for development
import "hardhat/console.sol";

library StringsConcat {

    function strConcat(string memory _a, string memory _b) internal pure returns (string memory _concatenatedString) {
        return strConcat(_a, _b, "", "", "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c) internal pure returns (string memory _concatenatedString) {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d) internal pure returns (string memory _concatenatedString) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c, string memory _d, string memory _e) internal pure returns (string memory _concatenatedString) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        uint i = 0;
        for (i = 0; i < _ba.length; i++) {
            babcde[k++] = _ba[i];
        }
        for (i = 0; i < _bb.length; i++) {
            babcde[k++] = _bb[i];
        }
        for (i = 0; i < _bc.length; i++) {
            babcde[k++] = _bc[i];
        }
        for (i = 0; i < _bd.length; i++) {
            babcde[k++] = _bd[i];
        }
        for (i = 0; i < _be.length; i++) {
            babcde[k++] = _be[i];
        }
        return string(babcde);
    }

    function toString(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

}

contract FutureCore is Initializable, OwnableUpgradeable {

    using SafeMath for uint256;    

    struct FutureToken {
        DETAILEDIERC20 tokenContract;
        uint maturityDate;
        FutureERC20Token futureERC20Token;
        uint created;
    }

    uint constant MIN_MATURITY = 86400;
    uint constant MIN_MATURITY_SPREAD = 86400 * 30;
    bool unlocked;
    mapping(address => mapping(uint => FutureToken)) public tokenFutures;  // mapping from token to futures of that token
    mapping(address => FutureToken) public futures;     // mapping from future token address to future token data
    mapping(address => uint) public futuresCount;

    event FutureERC20TokenCreated(uint maturityDate, string name, string symbol, address tokenAddress);

    event FutureERC20Minted(address indexed futuresContract, address indexed user, uint amount);

    modifier lock() {
        require(unlocked == true, 'MonoX:LOCKED');
        unlocked = false;
        _;
        unlocked = true;
    }

    function initialize() public initializer
    {
        __Ownable_init();
        unlocked=true;
    }

    function getTokenFutureByToken(address _token,uint _monthTimestamp) public view returns(FutureToken memory futureToken)
    {
        require(tokenFutures[_token][_monthTimestamp].created!=0, "MonoFutures: indexNotFound");
        futureToken = tokenFutures[_token][_monthTimestamp];
    }

    function createFutureToken(address _tokenToBeDuplicated, uint256 _maturityDate ,uint256 mintAmount) public {
        
        require(_maturityDate > block.timestamp + MIN_MATURITY,"MonoFutures: minMaturityNotSatisfied");

        uint _maturityMapping = _maturityDate / MIN_MATURITY_SPREAD;        

        require( tokenFutures[_tokenToBeDuplicated][_maturityMapping].created==0, "MonoFutures: futuresSpreadNotSatisfied");        

        DETAILEDIERC20 duplicatedTokenContract = DETAILEDIERC20(_tokenToBeDuplicated);
        
        string memory name=StringsConcat.strConcat(duplicatedTokenContract.name()," Future");
        string memory symbol=StringsConcat.strConcat(duplicatedTokenContract.symbol(),"F_",StringsConcat.toString(_maturityDate));

        FutureERC20Token _futureERC20Token = new FutureERC20Token(
            name,
            symbol
        );

        FutureToken memory _futureToken;
        _futureToken.tokenContract = duplicatedTokenContract;
        _futureToken.maturityDate = _maturityDate;
        _futureToken.futureERC20Token = _futureERC20Token;
        _futureToken.created = block.timestamp;

        tokenFutures[_tokenToBeDuplicated][_maturityMapping]=_futureToken;
        futuresCount[_tokenToBeDuplicated]++;

        futures[address(_futureERC20Token)] = _futureToken;

        emit FutureERC20TokenCreated(
            _maturityDate,
            name,
            symbol,
            address(_futureERC20Token)
        );

        if(mintAmount > 0){
            mintFutures(address(_futureERC20Token), mintAmount);
        }

    }

    function mintFutures(address _futureTokenContract, uint _amount) public lock
    {
        uint256 amount = safeERC20TransferFrom(futures[_futureTokenContract].tokenContract, msg.sender, address(this), _amount);
        
        futures[_futureTokenContract].futureERC20Token.mint(msg.sender, amount);
        
        emit FutureERC20Minted(_futureTokenContract,msg.sender,amount);
    }

    function redeemFutures(address _futureTokenContract, uint _amount) external{

        uint maturityDate = futures[_futureTokenContract].maturityDate;
        
        require(maturityDate < block.timestamp,"MonoFutures: maturityDateNotReached");

        futures[_futureTokenContract].futureERC20Token.burn(msg.sender,_amount);

        futures[_futureTokenContract].tokenContract.transfer(msg.sender,_amount);
        
    }


    // function initializeFutureTypesDetails() internal
    // {
    //     createFutureTypeToken(FutureType.MONOF90, 90, "MONOF90", "MONO Future 90");
    //     createFutureTypeToken(FutureType.MONOF180, 180, "MONOF180", "MONO Future 180");
    //     createFutureTypeToken(FutureType.MONOF270, 270, "MONOF270", "MONO Future 270");
    //     createFutureTypeToken(FutureType.MONOF360, 360, "MONOF360", "Mono Future 360");
    //     createFutureTypeToken(FutureType.MONOF450, 450, "MONOF450", "MONO Future 450");
    //     createFutureTypeToken(FutureType.MONOF540, 540, "MONOF540", "MONO Future 540");
    //     createFutureTypeToken(FutureType.MONOF630, 630, "MONOF630", "MONO Future 630");
    //     createFutureTypeToken(FutureType.MONOF720, 720, "MONOF720", "MONO Future 720");
    // }



    function safeERC20TransferFrom(DETAILEDIERC20 _token, address _from, address _to, uint256 _amount) internal returns (uint256) {
        require(_from == address(this) || _to == address(this), "transfer: not good");
        uint256 balanceIn0 = _token.balanceOf(_to);
        _token.transferFrom(
            _from,
            _to,
            _amount
        );
        uint256 balanceIn1 = _token.balanceOf(_to);
        return balanceIn1.sub(balanceIn0);   
    }

}