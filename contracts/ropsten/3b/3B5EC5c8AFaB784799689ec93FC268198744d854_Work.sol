pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "../library/IterableWork.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}
interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}
interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

contract Work is AccessControlEnumerable{

    using SafeMath for uint256;
    using Address for address;

    struct workAgreement{
        uint256 id;
        bool active;

        address worker;
        address user;

        uint256 price;
        uint256 fee;
        uint256 total;
        uint256 dateOfProposal;

        bool sendForApproval;
        bool disputed;
        // bool paymentInTimerr;
    }
    
    bytes32 public constant MOD_ROLE = keccak256("MOD_ROLE");

    constructor()
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MOD_ROLE,msg.sender);
    }

    uint256 workCount = 0;
    
    uint256 baseFee = 100;
    address feeAddress = 0x9de9e24a23657cc6B65b355D9f419c36Da196fDc;
    // workAgreement public sentinel = workAgreement(0,false,address(0),address(0),0,block.timestamp,false,false);

    mapping(address => uint256) public Users; //TimeStamp of registrement;
    mapping(address => bool) public isRegisteredAsFreelancers;
    mapping(address => bool) public isRegistered;
    mapping(address => bool) public isBanned;
    mapping(address => bool) public isVerified;

    mapping(address => bool) public isTimerrChoice;

    mapping(address => uint256[]) public pendingContract;
    mapping(address => uint256[]) public contractOf;
    mapping(address => uint256[]) public historyOf;

    mapping(uint256 => workAgreement) public contractByID;

    address public TimerrChoice;
    address public TimerrToken;
    address public BUSD;
    IUniswapV2Router02 public uniswapV2Router;

    bool autoVerify = true;

    // mapping(address => bool) public mods;
    // mapping(uint => address) public supportedCurrency;

    event JobProposal(address user,address worker,uint256 price,uint256 _id, bytes16 orderID);
    event JobAccepted(uint256 timestamp,address user,address worker, uint256 _id);
    event JobRefused(uint256 timestamp,address user,address worker, uint256 _id);
    event JobCanceled(uint256 timestamp,address user,address worker, uint256 _id);

    event _deliveryAccepted(uint256 _id);
    event _deliveryRefused(uint256 _id);

    event EventRegister(address user);
    event EventWorkComplete();

    event EvenDispute(address _emmitedBy, uint256 _id);
    event Banned();

    //___Array Helper's___

    //@dev get index of the contract in the list of the mapping pendingContract.
    function getPendingContractIndexByID(address _user,uint256 _id) public view returns (uint){
        for(uint i = 0; i <= pendingContract[_user].length - 1; i++){
            if(pendingContract[_user][i] == _id)
            {
                return i;
            }
        }
        revert("Id not found");
    }

    //@dev get index of the contract in the list of the mapping contractOf.
    function getContractIndexByID(address _user,uint256 _id) public view returns (uint){
        for(uint i = 0; i <= contractOf[_user].length - 1; i++){
            if(contractOf[_user][i] == _id)
            {
                return i;
            }
        }
        revert("Id not found");
    }
    //remove an index from the arr
    function remove(uint256[] storage _arr, uint256 _index) internal {
        require(_index < _arr.length, "index out of bound");

        for (uint i = _index; i < _arr.length - 1; i++){
            _arr[i] = _arr[i + 1];
        }
        _arr.pop();
    }

    function swapBUSDforTimerr(uint256 busdAmount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = TimerrToken;

        // make the swap
        uniswapV2Router.swapExactETHForTokens {value: busdAmount} (
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    //____________
    //Add an address to the mod list
    function addToMods(address _toAdd) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        _setupRole(MOD_ROLE, _toAdd);
    }
    //Allow a user to register
    function Register() external {
        require(!isRegistered[msg.sender], "Already registered");
        // workAgreement[] storage tmp;

        Users[msg.sender] = block.timestamp;
        emit EventRegister(msg.sender);
    }

    //Allow a User to register as a Freelancer
    function RegisterAsFreeLancer() external {
        require(Users[msg.sender] != 0, "Not registered");
        require(!isRegisteredAsFreelancers[msg.sender], "Already Registered");
        // if(user != msg.sender) require(hasRole(DEFAULT_ADMIN_ROLE,msg.sender));
        if(autoVerify)
        {
            isVerified[msg.sender] = true;
        }

        isRegisteredAsFreelancers[msg.sender] = true;
    }

    function askForServicesBUSD(address _worker,uint256 _total, bytes16 orderID) public{
        require(Users[msg.sender] != 0, "You're not registered");
        require(isRegisteredAsFreelancers[_worker], "Worker is not a Freelancer");
        require(isVerified[_worker], "Worker has not been verified");
        // require(_price == msg.value, "Price and Value send are different");
        uint256 fee = (_total*(baseFee))/1000;
        uint256 price = _total.sub(fee);

        workAgreement memory newWork = workAgreement(workCount,false,_worker,msg.sender,price,fee,_total,block.timestamp,false,false);

        ERC20 paymentToken = ERC20(BUSD);
        paymentToken.transferFrom(msg.sender,address(this),_total*paymentToken.decimals());
        paymentToken.transfer(feeAddress,fee*paymentToken.decimals());


        pendingContract[msg.sender].push(workCount);
        pendingContract[_worker].push(workCount);

        contractByID[workCount] = newWork;

        workCount++;

        emit JobProposal(msg.sender, _worker ,_total ,newWork.id, orderID);
    }

    function testOrder() public {
        emit JobProposal(address(0), address(0), 0, 0, bytes16("Heyyy"));
    }

    //Acccept the job offer, put the pending contract

    function acceptJob(uint256 _id) external {
        require(isRegisteredAsFreelancers[msg.sender], "Worker is not a Freelancer");
        require(contractByID[_id].worker == msg.sender,"The work agreement is not yours");

        workAgreement memory current = contractByID[_id];
        current.active == true;
        uint256 indexW = getPendingContractIndexByID(msg.sender, _id);
        uint256 indexU = getPendingContractIndexByID(current.user, _id);

        contractOf[msg.sender].push(_id);
        contractOf[current.user].push(_id);

        remove(pendingContract[msg.sender],indexW);
        remove(pendingContract[current.user],indexU);

        emit JobAccepted(block.timestamp,current.user,msg.sender,_id);
    }

    //@dev Refuse the job offer and the contract refund the User. Delete the whole WorkAggreement.

    function refuseJob(uint256 _id) external{
        require(isRegisteredAsFreelancers[msg.sender], "Worker is not a Freelancer");
        require(contractByID[_id].worker == msg.sender,"The work agreement is not yours");

        workAgreement storage current = contractByID[_id];

        uint256 indexW = getPendingContractIndexByID(msg.sender, _id);
        uint256 indexU = getPendingContractIndexByID(current.user, _id);

        // ERC20(current.paymentToken).transferFrom(address(this),current.user,current.price*ERC20(current.paymentToken).decimals());
        payable(current.user).transfer(current.price);
        remove(pendingContract[msg.sender],indexW);
        remove(pendingContract[current.user],indexU);

        emit JobRefused(block.timestamp,current.user,msg.sender,_id);
    }

    function cancelJob(uint256 _id) external {
        require(Users[msg.sender] != 0, "Worker is not a Freelancer");
        require(contractByID[_id].user == msg.sender,"Not your Work");
        require(!contractByID[_id].active, "Already Active");

        workAgreement storage current = contractByID[_id];

        uint256 indexW = getPendingContractIndexByID(msg.sender, _id);
        uint256 indexU = getPendingContractIndexByID(current.user, _id);

        payable(current.user).transfer(current.price);
        remove(pendingContract[msg.sender],indexW);
        remove(pendingContract[current.user],indexU);

        emit JobCanceled(block.timestamp,current.user,msg.sender,_id);
    }

    //@dev Used by the Worker when is job is supposed to be finished

    function jobDelivered(uint256 _id) public {
        require(contractByID[_id].worker == msg.sender, "Not your Work");

        contractByID[_id].sendForApproval = true;
    }

    //@dev Send money to the Worker, place everything in the History.
    function deliveryAccepted(uint256 _id) public{
        require(contractByID[_id].user == msg.sender, "Timerr : Not your contract");
        require(contractByID[_id].sendForApproval, "Timerr : Not send for Approval yet");

        // payable(contractByID[_id].worker).transfer(contractByID[_id].price);
        ERC20 paymentToken = ERC20(BUSD);
        paymentToken.transfer(contractByID[_id].worker,contractByID[_id].price*paymentToken.decimals());

        uint256 indexW = getContractIndexByID(contractByID[_id].worker, _id);
        uint256 indexU = getContractIndexByID(contractByID[_id].user, _id);

        historyOf[contractByID[_id].worker].push(_id);
        historyOf[contractByID[_id].user].push(_id);

        remove(contractOf[msg.sender],indexU);
        remove(contractOf[contractByID[_id].worker],indexW);

        emit _deliveryAccepted(_id);
    }

    //@dev Send money to the Worker, place everything in the History.
    function deliveryRefused(uint256 _id) public{
        require(contractByID[_id].user == msg.sender, "Timerr : Not your contract");
        require(contractByID[_id].sendForApproval, "Timerr : Not send for Approval");

        contractByID[_id].sendForApproval = false;

        emit _deliveryRefused(_id);
    }

    //@dev Allow User or Worker to create a Dispute whenever they want.
    function dispute(uint256 _id) public{
        require(contractByID[_id].worker == msg.sender || contractByID[_id].user == msg.sender, "Timerr : You can't start a dispute on a Work Contract that isn't yours");

        contractByID[_id].disputed = true;

        emit EvenDispute(msg.sender,_id);
    }

    //@ allow an admin to settle the dispute.
    function handleDispute(uint256 _id, address _winner) external {
        require(hasRole(MOD_ROLE, msg.sender), "Not a Mod");

        payable(_winner).transfer(contractByID[_id].price);

        uint256 indexW = getContractIndexByID(contractByID[_id].worker, _id);
        uint256 indexU = getContractIndexByID(contractByID[_id].user, _id);

        historyOf[contractByID[_id].worker].push(_id);
        historyOf[contractByID[_id].user].push(_id);

        remove(contractOf[msg.sender],indexW);
        remove(contractOf[contractByID[_id].user],indexU);
    }

    function ban(address _user) external {
        require(hasRole(MOD_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not a Mod");

        isBanned[_user] = true;
    }

    function verify(address _user) external {
        require(hasRole(MOD_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not a Mod");

        isVerified[_user] = true;
    }

    function setAutoVerify(bool _value) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");

        autoVerify = _value;
    }
    function setTimerrChoiceAddress(address _nftaddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        TimerrChoice = _nftaddress;
    }
    function setBUSD(address _newAddress) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        BUSD = _newAddress;
    }
    function setTimerr(address _newAddress) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        TimerrToken = _newAddress;
    }
    function setRouter(address _newAddress) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        uniswapV2Router = IUniswapV2Router02(_newAddress);
    }
    function setFee(uint256 _fee) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        baseFee = _fee;
    }
    function setFeeAddress(address _feeAddress) external{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Not Admin");
        feeAddress = _feeAddress;
    }

}