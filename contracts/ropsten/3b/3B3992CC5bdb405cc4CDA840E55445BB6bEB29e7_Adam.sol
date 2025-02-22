// 0xf9baf2dce27206500e3145fde4509037db1f6d0ec5e5cfec4605dbc3bdc23f96
/****************************************************************************************************

                                                                88                                
                                                                88                                
                                                                88                                
                                            ,adPPYYba,  ,adPPYb,88 ,adPPYYba, 88,dPYba,,adPYba,   
                                            ""     `Y8 a8"    `Y88 ""     `Y8 88P'   "88"    "8a  
                                            ,adPPPPP88 8b       88 ,adPPPPP88 88      88      88  
                                            88,    ,88 "8a,   ,d88 88,    ,88 88      88      88  
                                            `"8bbdP"Y8  `"8bbdP"Y8 `"8bbdP"Y8 88      88      88


               `..---....`                                                                          
         ```.-.````.--::::----..```                                                                 
   ````.....-:::-----...--.``..--:////-                                                             
.---..---//oyyhhyhhy+.```...```...`..-+/.`                                                          
------::+oyhhhhdhhhdm+..```...-++/-...-:/os+:.                                            ````````.`
----::/+shddddddddhys:---.``..:yhysho/+o/-.-/o+                           `   ``.```````````........
--::/+shddmmmmNms-`   `-:/:-``./hh+yNNNNmdhh+:/o.          ```````    ``````````..`..-://::::--.....
/+osyhddmmmNNmy-        `-::-.--:++smmydmNmmm//+s.  ````..-:/---.```.----.````..:++s+/+oooo+/--.....
yhhdmmmNNNNms-               ``..-:+sdo`+NmdNo.++s` .:/+o++o++oo+..:-sy/.`.....-odmmhssooo++//::----
dmmmmNNNmy/.                     `:/ssy- oNmmm  .-`   ``       `..oyo+-`.:oo::/sddmmmdhdhhhysoo+++++
mNNmdho:.                         :yyoo:  dNdN.                 `-::--+oyhmmddddmmmmmhssyhhyyyyssyyy
mh+-`                             `- ``   -+-+-               -.---+yhd+:odhdmmmmmhs:`    .--:/+osyy
-                                                             .:/oys++ds/++oo+shs/`                 
                                                               ./hs/yy:-:hs:::.                     
                                                               -sd/oy``ydy                          
                                                               .:h-y- `--+                          
                                                               `//-/   ```                          
                                                                                                    
                                                                                                                                                                                                                                                                        
****************************************************************************************************/

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "./lib/BytesLib.sol";

interface IEdenNetwork {
    function slotDelegate(uint8) external view returns(address);
    function slotForeclosed(uint8) external view returns(bool);
    function slotOwner(uint8) external view returns(address);
}

contract Adam {

    using BytesLib for bytes;

    IEdenNetwork public constant EdenNetwork = IEdenNetwork(0x9E3382cA57F4404AC7Bf435475EAe37e87D1c453);
    uint public constant UF_UNITS = 1e4;  // Usage-fee units - expect bips
    uint public constant PP_DENOMINATOR = 1e15;  // Profit-prediction denominator - expect kwei

    int public SLOT;
    address public ADMIN;
    uint public USAGE_FEE;
    address[] public TRADERS;
    uint public TRADERS_COUNT;
    mapping(address => bool) public isTrader;
    mapping(address => uint) public userBalance;
    mapping(address => uint) internal traderPointer;

    modifier onlyAdmin {
        require(msg.sender == ADMIN, 'Adam: Only admin');
        _;
    }

    modifier onlyTrader {
        require(isTrader[msg.sender], 'Adam: Only trader');
        _;
    }

    modifier checkProfitability {
        address _trader = msg.sender;
        uint traderBalanceBefore = userBalance[_trader];
        _;
        uint traderBalanceAfter = userBalance[_trader];
        uint expectedProfit = (tx.gasprice - block.basefee) * PP_DENOMINATOR;
        uint expectedTraderBal = expectedProfit + traderBalanceBefore;  // Assumed builtin safemath
        _payForSlotUsage(expectedProfit);
        if (expectedTraderBal > traderBalanceAfter) {
            uint diff = expectedTraderBal - traderBalanceAfter;
            _slashTrader(diff);
        }
    }

    modifier onlyProfitable {
        uint ethBalBefore = address(this).balance;
        _;
        uint ethBalAfter = address(this).balance;
        require(ethBalAfter >= ethBalBefore, 'Adam: Not profitable');
    }

    function _payForSlotUsage(uint _expectedProfit) internal {
        address trader = msg.sender;
        // Fee is not applied on the surplus of profit
        uint fee = USAGE_FEE * _expectedProfit / UF_UNITS;  // Assumed builtin safemath
        userBalance[trader] -= fee;
        userBalance[ADMIN] += fee;
    }

    // TODO: Is slashing really needed? Fail tx instead?
    function _slashTrader(uint _diff) internal {
        address trader = msg.sender;
        uint slashAmount = _diff;
        if (userBalance[trader] < _diff) {
            // Remove trader if they can't pay for slashing
            slashAmount = userBalance[trader];
            _removeTrader(trader);
        }
        userBalance[trader] -= slashAmount;
        userBalance[address(this)] += slashAmount;
    }

    function _qualifiesForAdmin(address _address, uint _slot) internal view returns (bool) {
        return (
            !EdenNetwork.slotForeclosed(uint8(_slot)) 
            && EdenNetwork.slotOwner(uint8(_slot)) == _address 
            && EdenNetwork.slotDelegate(uint8(_slot)) == address(this)
        );
    }

    function _getRevertMsg(bytes memory res) internal pure returns (string memory) {
        // If the res length is less than 68, then the transaction failed silently (without a revert message)
        if (res.length < 68) return 'Call failed for unknown reason';
        bytes memory revertData = res.slice(4, res.length - 4); // Remove the selector which is the first 4 bytes
        return abi.decode(revertData, (string)); // All that remains is the revert string
    }

    function _removeTrader(address _trader) internal {
        isTrader[_trader] = false;
        TRADERS[traderPointer[_trader]] = address(0);
        TRADERS_COUNT --;
    }

    function _execute(
        address _target, 
        bytes memory _data, 
        uint _ethVal
    ) internal returns (bytes memory response) {
        bool succeeded;
        assembly {
            // TODO: make gas left accurate
            succeeded := call(sub(gas(), 5500), _target, _ethVal, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()
            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size) 
        }
        require(succeeded, _getRevertMsg(response));
    }

    function removeTraders(address[] calldata _traders) public onlyAdmin {
        // disperse slashed funds before any trader is removed (against malicious admin)
        disperseSlashed();
        for (uint i; i<_traders.length; i++) {
            _removeTrader(_traders[i]);
        }
    }

    function addTraders(address[] calldata _newTraders) public onlyAdmin {
        // disperse slashed funds before any trader is removed (against malicious admin)
        disperseSlashed();
        for (uint i; i<_newTraders.length; i++) {
            require(_newTraders[i] != address(this), 'Adam: This contract cant be a trader');  // Prevent reentrancy in execute
            isTrader[_newTraders[i]] = true;
            TRADERS.push(_newTraders[i]);
            traderPointer[_newTraders[i]] = TRADERS.length - 1;
            TRADERS_COUNT ++;
        }
    }

    // TODO: Should this be restricted? Think malicious slot owner
    function setUsageFee(uint _fee) public onlyAdmin {
        USAGE_FEE = _fee;
    }

    // Admin can only be slot-owner that delegates this contract
    function setAdmin(address _address, uint _slot) public {
        // Prevent owners of other slots controlling the contract
        require(!_qualifiesForAdmin(ADMIN, uint(SLOT)), 'Adam: Current admin is still qualified');
        require(_qualifiesForAdmin(_address, _slot), 'Adam: Not qualified for admin');
        ADMIN = _address;
        SLOT = int(_slot);
    }

    // If slot-owner changes and doesn't set this contract as delegate
    // Avoid accidental payment of fees to the previous admin
    function resetAdmin() public {
        require(!_qualifiesForAdmin(ADMIN, uint(SLOT)), 'Adam: Current admin is still qualified');
        ADMIN = address(this);  // Fees collected will go back to the traders
        SLOT = -1;
    }

    function depositETH(address _for) public payable {
        userBalance[_for] += msg.value;
    }

    function withdrawETH(uint _amount) public {
        require(userBalance[msg.sender] >= _amount, 'Adam: Insufficient balance');
        userBalance[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function disperseSlashed() public {
        // TODO: Remove the limit?
        // Only disperse if there is more than 0.314 slashed in total
        if (userBalance[address(this)] > 0.314 ether) {
            // Disperse among traders
            uint chunk = userBalance[address(this)] / TRADERS_COUNT;
            userBalance[address(this)] -= chunk * TRADERS_COUNT;  // Account for rounding
            for (uint i=0; i<TRADERS.length; i++) {
                if (TRADERS[i] != address(0)) {
                    userBalance[TRADERS[i]] += chunk;
                }
            }
        }
    }

    function execute(
        address _target, 
        bytes memory _data
        ) external payable onlyTrader onlyProfitable checkProfitability returns (bytes memory response) {
        return _execute(_target, _data, msg.value);
    }

    function execute(
        address _target, 
        bytes memory _data, 
        uint _ethVal
    ) external payable onlyTrader onlyProfitable checkProfitability returns (bytes memory response) {
        return _execute(_target, _data, _ethVal);
    }

}