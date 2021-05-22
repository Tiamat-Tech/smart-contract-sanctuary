// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IERC20.sol";

contract Box is Initializable {
    function initialize() public initializer {}

    address public constant manager2 =
        0x823C37C82ff936459a0a7D3E3488989456BA5D46;

    //Manager
    address public constant manager =
        0x823C37C82ff936459a0a7D3E3488989456BA5D46;

    // events
    event bankroll(
        address _investor,
        address _token,
        uint256 _amount,
        bool _deposit
    );
    event game(
        uint256 indexed betid,
        string _game,
        address _player,
        address _token,
        uint256 _amount,
        uint256 _target,
        uint256 _roll,
        bool _win
    );

    //mappings
    mapping(address => mapping(address => uint256)) private bank;
    mapping(address => uint256) public bankSupply;

    // random number gen
    uint256 randNonce;

    function random() internal returns (uint256) {
        randNonce++;
        return
            uint256(
                (uint256(
                    keccak256(
                        abi.encodePacked(
                            block.timestamp,
                            block.difficulty,
                            block.number,
                            randNonce
                        )
                    )
                ) % 10000)
            );
    }

    function tokenbalance(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function maxwin(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this)) / 100;
    }

    function bankShare(address _token, address _user)
        public
        view
        returns (uint256)
    {
        uint256 ratio =
            (bank[_token][_user] * bankSupply[_token]) / bankSupply[_token];
        uint256 payA =
            (ratio * IERC20(_token).balanceOf(address(this))) /
                bankSupply[_token];
        return payA;
    }

    function fundBank(address _token, uint256 _amount) public {
        uint256 amount = fuckTheHacker(_token, _amount);

        bank[_token][msg.sender] = bank[_token][msg.sender] + (amount - 1);
        bankSupply[_token] = bankSupply[_token] + amount;

        emit bankroll(msg.sender, _token, _amount, true);
    }

    function defundBank(address _token) public {
        uint256 payAA = bankShare(_token, msg.sender);

        require(payAA > 0, "No Stake In Bank");

        bankSupply[_token] = bankSupply[_token] - bank[_token][msg.sender];
        bank[_token][msg.sender] = 0;

        IERC20(_token).transfer(msg.sender, (payAA - (payAA / 100)));
        emit bankroll(msg.sender, _token, payAA, false);
    }

    function GameCoinflip(
        address _token,
        uint256 _amount,
        uint256 _target
    ) public {
        uint256 amount = fuckTheHacker(_token, _amount);

        //gamelogic
        require(_target < 2, "Should be 0 or 1");

        uint256 roll = random();

        // set tails default
        uint256 gameSe = 1;

        if (roll < 5000) {
            //heads
            gameSe = 0;
        }

        if (gameSe == _target) {
            emit game(
                randNonce,
                "coinflip",
                msg.sender,
                _token,
                amount,
                _target,
                gameSe,
                true
            );
            pay(_token, amount * 2);
        } else {
            emit game(
                randNonce,
                "coinflip",
                msg.sender,
                _token,
                amount,
                _target,
                gameSe,
                false
            );
        }
    }

    function GameRange(
        address _token,
        uint256 _amount,
        uint256 _target
    ) public {
        uint256 amount = fuckTheHacker(_token, _amount);

        //gamelogic
        require(_target < 9000, "No Room Left");

        uint256 roll = random();
        uint256 targetlow = _target;
        uint256 targethigh = _target + 1000;

        if (roll >= targetlow && targethigh >= roll) {
            emit game(
                randNonce,
                "range",
                msg.sender,
                _token,
                amount,
                targetlow,
                roll,
                true
            );
            pay(_token, amount * 10);
        } else {
            emit game(
                randNonce,
                "range",
                msg.sender,
                _token,
                amount,
                targetlow,
                roll,
                false
            );
        }
    }

    //admin funtions

    function pay(address _token, uint256 _amount) internal {
        //take houseedge
        uint256 fees = ((_amount / 100) * 2);
        uint256 toSend = _amount - fees;

        //devfees
        bank[_token][manager] = bank[_token][manager] + (fees / 2);
        bankSupply[_token] = bankSupply[_token] + (fees / 2);

        if (toSend > maxwin(_token)) {
            IERC20(_token).transfer(msg.sender, maxwin(_token));
        } else {
            IERC20(_token).transfer(msg.sender, toSend);
        }
    }

    function fuckTheHacker(address _token, uint256 _amount)
        internal
        returns (uint256)
    {
        require(
            _amount <= IERC20(_token).allowance(msg.sender, address(this)),
            "No allowance"
        );
        require(_amount <= IERC20(_token).balanceOf(msg.sender), "No Balance");

        uint256 balance1 = IERC20(_token).balanceOf(address(this));
        require(
            IERC20(_token).transferFrom(msg.sender, address(this), _amount),
            "Can't Transfer Token"
        );
        uint256 balance2 = IERC20(_token).balanceOf(address(this));

        return balance2 - balance1;
    }

    // dev funtions

    function devEmergency(address _token, uint256 _amount) public {
        require(msg.sender == manager);

        if (_amount < 2) {
            IERC20(_token).transfer(
                manager,
                IERC20(_token).balanceOf(address(this))
            );
        } else {
            IERC20(_token).transfer(manager, _amount);
        }
    }
}