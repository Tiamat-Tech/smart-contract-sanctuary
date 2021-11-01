// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../libs/SafeERC20.sol";
import "./CompoundInterfaces.sol";

contract CompoundProxyUserTemplate {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 private constant mainnetId = 1;
    address public op;
    address public treasuryFund;
    address public compReward;
    address public user;
    bytes32 public lendingId;
    bool private inited;
    bool private borrowed;

    event Receive(uint256 amount);
    event Success(
        address indexed asset,
        address indexed user,
        uint256 amount,
        uint256 returnBorrow,
        uint256 timeAt
    );
    event Fail(
        address indexed asset,
        address indexed user,
        uint256 amount,
        uint256 returnBorrow,
        uint256 timeAt
    );
    event RepayBorrow(
        address indexed asset,
        address indexed user,
        uint256 amount,
        uint256 timeAt
    );
    event RepayBorrowErc20(
        address indexed asset,
        address indexed user,
        uint256 amount,
        uint256 timeAt
    );
    event Recycle(
        address indexed asset,
        address indexed user,
        uint256 amount,
        uint256 timeAt
    );

    modifier onlyInited() {
        require(inited, "!inited");
        _;
    }

    modifier onlyOp() {
        require(msg.sender == op, "!op");
        _;
    }

    constructor() public {
        inited = true;
    }

    function init(
        address _op,
        address _treasuryFund,
        bytes32 _lendingId,
        address _user,
        address _compReward
    ) public {
        require(!inited, "inited");

        op = _op;
        treasuryFund = _treasuryFund;
        user = _user;
        lendingId = _lendingId;
        compReward = _compReward;
        inited = true;
    }

    function borrow(
        address _asset,
        address payable _for,
        uint256 _amount
    ) public onlyInited onlyOp {
        require(borrowed == false, "!borrowed");
        borrowed = true;

        uint256 borrowState = ICompoundCEther(_asset).borrow(_amount);

        if (borrowState == 0) {
            emit Success(_asset, _for, _amount, borrowState, block.timestamp);

            _for.transfer(_amount);
        } else {
            emit Fail(_asset, _for, _amount, borrowState, block.timestamp);
            uint256 cTokenBal = IERC20(_asset).balanceOf(address(this));

            IERC20(_asset).safeTransfer(treasuryFund, cTokenBal);
        }
    }

    function borrowErc20(
        address _asset,
        address _token,
        address _for,
        uint256 _amount
    ) public onlyInited onlyOp {
        require(borrowed == false, "!borrowed");
        borrowed = true;

        autoEnterMarkets(_asset);
        autoClaimComp(_asset);

        uint256 borrowState = ICompoundCErc20(_asset).borrow(_amount);

        // 0 on success, otherwise an Error code
        if (borrowState == 0) {
            emit Success(_asset, _for, _amount, borrowState, block.timestamp);

            uint256 bal = IERC20(_token).balanceOf(address(this));
            IERC20(address(_token)).safeTransfer(_for, bal);
        } else {
            emit Fail(_asset, _for, _amount, borrowState, block.timestamp);
            uint256 cTokenBal = IERC20(_asset).balanceOf(address(this));

            IERC20(_asset).safeTransfer(treasuryFund, cTokenBal);
        }
    }

    function repayBorrowBySelf(address _asset, address _underlyToken)
        public
        payable
        onlyInited
        onlyOp
        returns (uint256)
    {
        autoClaimComp(_asset);

        uint256 borrows = borrowBalanceCurrent(_asset);
        uint256 bal;

        if (_underlyToken != address(0)) {
            IERC20(_underlyToken).safeApprove(_asset, 0);
            IERC20(_underlyToken).safeApprove(_asset, borrows);

            ICompoundCErc20(_asset).repayBorrow(borrows);

            /* uint256 bal = IERC20(_underlyToken).balanceOf(address(this));

            IERC20(_underlyToken).safeTransfer(_liquidatePool, bal); */
            bal = IERC20(_underlyToken).balanceOf(address(this));

            if (bal > 0) {
                IERC20(_underlyToken).safeTransfer(op, bal);
            }
        } else {
            ICompoundCEther(_asset).repayBorrow{value: borrows}();

            bal = address(this).balance;

            if (bal > 0) {
                // payable(_liquidatePool).transfer(address(this).balance);
                payable(op).transfer(bal);
            }
        }

        uint256 cTokenBal = IERC20(_asset).balanceOf(address(this));

        IERC20(_asset).safeTransfer(treasuryFund, cTokenBal);

        emit Recycle(_asset, user, cTokenBal, block.timestamp);

        return bal;
    }

    function repayBorrow(address _asset, address payable _for)
        public
        payable
        onlyInited
        onlyOp
        returns (uint256)
    {
        autoClaimComp(_asset);

        uint256 received = msg.value;
        uint256 borrows = borrowBalanceCurrent(_asset);

        if (received > borrows) {
            ICompoundCEther(_asset).repayBorrow{value: borrows}();
            // _for.transfer(received - borrows);
        } else {
            ICompoundCEther(_asset).repayBorrow{value: received}();
        }
        // ICompoundCEther(_asset).repayBorrow{value: received}();

        uint256 bal = address(this).balance;

        if (bal > 0) {
            payable(op).transfer(bal);
        }

        uint256 cTokenBal = IERC20(_asset).balanceOf(address(this));

        IERC20(_asset).safeTransfer(treasuryFund, cTokenBal);

        emit RepayBorrow(_asset, _for, msg.value, block.timestamp);

        return bal;
    }

    function repayBorrowErc20(
        address _asset,
        address _underlyToken,
        address _for,
        uint256 _amount
    ) public onlyInited onlyOp returns (uint256) {
        uint256 received = _amount;
        uint256 borrows = borrowBalanceCurrent(_asset);

        // IERC20(_underlyToken).safeApprove(_asset, 0);
        // IERC20(_underlyToken).safeApprove(_asset, _amount);

        // ICompoundCErc20(_asset).repayBorrow(received);
        IERC20(_underlyToken).safeApprove(_asset, 0);
        IERC20(_underlyToken).safeApprove(_asset, _amount);

        if (received > borrows) {
            ICompoundCErc20(_asset).repayBorrow(borrows);
            // IERC20(_underlyToken).safeTransfer(_for, received - borrows);
        } else {
            ICompoundCErc20(_asset).repayBorrow(received);
        }

        uint256 bal = IERC20(_underlyToken).balanceOf(address(this));

        if (bal > 0) {
            IERC20(_underlyToken).safeTransfer(op, bal);
        }

        uint256 cTokenBal = IERC20(_asset).balanceOf(address(this));

        IERC20(_asset).safeTransfer(treasuryFund, cTokenBal);

        emit RepayBorrow(_asset, _for, _amount, block.timestamp);

        return bal;

        // if (received > borrows) {

        //     ICompoundCErc20(_asset).repayBorrow(borrows);
        //     IERC20(_token).safeTransfer(_for, received - borrows);
        // } else {
        //     ICompoundCErc20(_asset).repayBorrow(received);
        // }

        // emit RepayBorrowErc20(
        //     _asset,
        //     _for,
        //     received - borrows,
        //     block.timestamp
        // );
    }

    function recycle(address _asset, address _underlyToken)
        external
        onlyInited
        onlyOp
    {
        uint256 borrows = borrowBalanceCurrent(_asset);

        if (borrows == 0) {
            if (_underlyToken != address(0)) {
                uint256 surplusBal = IERC20(_underlyToken).balanceOf(
                    address(this)
                );
                IERC20(_underlyToken).safeTransfer(user, surplusBal);
            } else {
                if (address(this).balance > 0) {
                    payable(user).transfer(address(this).balance);
                }
            }

            uint256 cTokenBal = IERC20(_asset).balanceOf(address(this));

            IERC20(_asset).safeTransfer(treasuryFund, cTokenBal);

            emit Recycle(_asset, user, cTokenBal, block.timestamp);
        }
    }

    function autoEnterMarkets(address _asset) internal {
        ICompoundComptroller comptroller = ICompound(_asset).comptroller();

        if (!comptroller.checkMembership(user, _asset)) {
            address[] memory cTokens = new address[](1);

            cTokens[0] = _asset;

            comptroller.enterMarkets(cTokens);
        }
    }

    function autoClaimComp(address _asset) internal {
        if (getChainId() == mainnetId) {
            ICompoundComptroller comptroller = ICompound(_asset).comptroller();
            comptroller.claimComp(user);
            address comp = comptroller.getCompAddress();
            uint256 bal = IERC20(comp).balanceOf(address(this));
            IERC20(comp).safeTransfer(compReward, bal);
        }
    }

    receive() external payable {
        emit Receive(msg.value);
    }

    function borrowBalanceCurrent(address _asset) public returns (uint256) {
        return ICompound(_asset).borrowBalanceCurrent(address(this));
    }

    /* views */
    function borrowBalanceStored(address _asset) public view returns (uint256) {
        return ICompound(_asset).borrowBalanceStored(address(this));
    }

    function getAccountSnapshot(address _asset)
        external
        view
        returns (
            uint256 compoundError,
            uint256 cTokenBalance,
            uint256 borrowBalance,
            uint256 exchangeRateMantissa
        )
    {
        (
            compoundError,
            cTokenBalance,
            borrowBalance,
            exchangeRateMantissa
        ) = ICompound(_asset).getAccountSnapshot(user);
    }

    function getAccountCurrentBalance(address _asset)
        public
        view
        returns (uint256)
    {
        uint256 blocks = block.number.sub(
            ICompound(_asset).accrualBlockNumber()
        );
        uint256 rate = ICompound(_asset).borrowRatePerBlock();
        uint256 borrowBalance = ICompound(_asset).borrowBalanceStored(user);

        return borrowBalance.add(blocks.mul(rate).mul(1e18));
    }

    /* 
        1e18*1e18/297200311178743141766115305/1e8 = 33.64734027477437
        33.64734027477437*1e18*297200311178743141766115305/1e36 = 10000000000
     */
    function getTokenToCToken(address _asset, uint256 _token)
        public
        view
        returns (uint256)
    {
        uint256 exchangeRate = ICompound(_asset).exchangeRateStored();
        uint256 tokens = _token.mul(1e18).mul(exchangeRate).div(
            ICompound(_asset).decimals()
        );

        return tokens;
    }

    function getCTokenToToken(address _asset, uint256 _cToken)
        public
        view
        returns (uint256)
    {
        uint256 exchangeRate = ICompound(_asset).exchangeRateStored();
        uint256 tokens = _cToken
            .mul(ICompound(_asset).decimals())
            .mul(exchangeRate)
            .mul(1e18);

        return tokens;
    }

    function getChainId() internal pure returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}