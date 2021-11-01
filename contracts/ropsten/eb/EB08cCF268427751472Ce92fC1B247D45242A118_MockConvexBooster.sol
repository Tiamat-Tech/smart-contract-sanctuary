// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "./MockConvexInterfaces.sol";
import "../../libs/IERC20.sol";
import "../../libs/SafeERC20.sol";

interface ITokenMinter {
    function mint(address, uint256) external;

    function burn(address, uint256) external;
}

contract MockConvexBooster {
    using SafeERC20 for IERC20;

    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    PoolInfo[100] public poolInfo;
    mapping(address => bool) public gaugeMap;

    constructor() public {
        /* Curve.fi DAI/USDC/USDT (3Crv) */
    }

    function addPool(
        uint256 _pid,
        address _lpToken,
        address _token,
        address _crvRewards,
        address _stash
    ) public {
        poolInfo[_pid] = PoolInfo({
            lptoken: _lpToken,
            token: _token,
            gauge: address(0),
            crvRewards: _crvRewards,
            stash: _stash,
            shutdown: false
        });
        // poolInfo[9] = PoolInfo({
        //     lptoken: 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490,
        //     token: 0x30D9410ED1D5DA1F6C8391af5338C93ab8d4035C,
        //     gauge: 0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A,
        //     crvRewards: 0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8,
        //     stash: 0x0000000000000000000000000000000000000000,
        //     shutdown: false
        // });
        // /* Curve.fi ETH/stETH (steCRV) */
        // poolInfo[25] = PoolInfo({
        //     lptoken: 0x06325440D014e39736583c165C2963BA99fAf14E,
        //     token: 0x9518c9063eB0262D791f38d8d6Eb0aca33c63ed0,
        //     gauge: 0x182B723a58739a9c974cFDB385ceaDb237453c28,
        //     crvRewards: 0x0A760466E1B4621579a82a39CB56Dda2F4E70f03,
        //     stash: 0x9710fD4e5CA524f1049EbeD8936c07C81b5EAB9f,
        //     shutdown: false
        // });
    }

    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _stake
    ) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        address lptoken = pool.lptoken;
        IERC20(lptoken).safeTransferFrom(msg.sender, address(this), _amount);

        address token = pool.token;

        if (_stake) {
            //mint here and send to rewards on user behalf
            ITokenMinter(token).mint(address(this), _amount);
            address rewardContract = pool.crvRewards;
            IERC20(token).safeApprove(rewardContract, 0);
            IERC20(token).safeApprove(rewardContract, _amount);
            IRewards(rewardContract).stakeFor(msg.sender, _amount);
        } else {
            //add user balance directly
            ITokenMinter(token).mint(msg.sender, _amount);
        }

        return true;
    }

    function _withdraw(
        uint256 _pid,
        uint256 _amount,
        address _from,
        address _to
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        address lptoken = pool.lptoken;
        address token = pool.token;

        ITokenMinter(token).burn(_from,_amount);
        IERC20(lptoken).safeTransfer(_to, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public returns (bool) {
        _withdraw(_pid, _amount, msg.sender, msg.sender);
    }

    function withdrawTo(
        uint256 _pid,
        uint256 _amount,
        address _to
    ) external returns (bool) {
        address rewardContract = poolInfo[_pid].crvRewards;
        require(msg.sender == rewardContract, "!auth");

        _withdraw(_pid, _amount, msg.sender, _to);
        return true;
    }

    // function claimRewards(uint256 _pid, address _gauge)
    //     external
    //     returns (bool)
    // {
    //     return true;
    // }

    // function earmarkRewards(uint256 _pid) external returns (bool) {
    //     return true;
    // }

    // //claim fees from curve distro contract, put in lockers' reward contract
    // function earmarkFees() external returns (bool) {
    //     return true;
    // }

    //callback from reward contract when crv is received.
    // function rewardClaimed(
    //     uint256 _pid,
    //     address _address,
    //     uint256 _amount
    // ) external returns (bool) {
    //     address rewardContract = poolInfo[_pid].crvRewards;

    //     //mint reward tokens
    //     // ITokenMinter(minter).mint(_address, _amount);

    //     return true;
    // }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
}