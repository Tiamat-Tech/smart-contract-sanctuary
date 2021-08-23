//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../implements/0x02/CIPStaking.sol";
import "../../inheritances/code/CHCCollect.sol";
import "../../inheritances/spec/CHSLite.sol";

contract TestKovan is CIPStaking, CHCCollect, CHSLite {
    function address_bond() public pure override returns (address) {
        return 0x28003e9C3583BA8e31Ce0042DBb85b8a7a4543E5;
    }

    function address_want() public pure override returns (address) {
        return 0xae12f6016A3A64afC12CE5F23203FA6b9ce0f1Dd;
    }

    function address_call() public pure override returns (address) {
        return 0xfd17C3c5Ee35E907eB7C9A01C5A168f985b7F026;
    }

    function address_coll() public pure override returns (address) {
        return 0x8bb96D1D27fCe63ED2791655D1188a885c392Db3;
    }

    function address_collar() public pure override returns (address) {
        return 0xBEc25Ed2BCEBB414413cb7767D106C6a7e413131;
    }

    function expiry_time() public pure override returns (uint256) {
        return 1624809600;
    }
}

contract CollarUSDTUSDC is CIPStaking, CHCCollect, CHSLite {
    function address_bond() public pure override returns (address) {
        return 0x08f5F253fb2080660e9a4E3882Ef4458daCd52b0;
    }

    function address_want() public pure override returns (address) {
        return 0x67C9a0830d922C80A96408EEdF606c528836880C;
    }

    function address_call() public pure override returns (address) {
        return 0x9D8FEb661AFc92b83c45fC21836C114164beB285;
    }

    function address_coll() public pure override returns (address) {
        return 0x25a722fbd8c4080937CAD2A4DFa2eeeA29539231;
    }

    function address_collar() public pure override returns (address) {
        return 0xe405bD3C4876D1Ea0af92BaCF5831c9FCbDD78aE;
    }

    function expiry_time() public pure override returns (uint256) {
        return 1633017600;
    }
}

contract CollarUSDCUSDT is CIPStaking, CHCCollect, CHSLite {
    function address_bond() public pure override returns (address) {
        return 0x67C9a0830d922C80A96408EEdF606c528836880C;
    }

    function address_want() public pure override returns (address) {
        return 0x08f5F253fb2080660e9a4E3882Ef4458daCd52b0;
    }

    function address_call() public pure override returns (address) {
        return 0x404Ced902eE6d630db51969433ea7DD2EE3524B8;
    }

    function address_coll() public pure override returns (address) {
        return 0x61E04744eD53E1Ae61A9325A5Eba31AEA24eca4D;
    }

    function address_collar() public pure override returns (address) {
        return 0xe405bD3C4876D1Ea0af92BaCF5831c9FCbDD78aE;
    }

    function expiry_time() public pure override returns (uint256) {
        return 1633017600;
    }
}



contract CollarUSDTUSDC_V2 is CIPStaking, CHCCollect, CHSLite {
    function address_bond() public pure override returns (address) {
        return 0x08f5F253fb2080660e9a4E3882Ef4458daCd52b0;
    }

    function address_want() public pure override returns (address) {
        return 0x67C9a0830d922C80A96408EEdF606c528836880C;
    }

    function address_call() public pure override returns (address) {
        return 0xEA84958BAC11f7665e339599595c425A81E894d6;
    }

    function address_coll() public pure override returns (address) {
        return 0x38C4A0d539F8e9AFA5EFBD46aAA6b31013480c00;
    }

    function address_collar() public pure override returns (address) {
        return 0xe405bD3C4876D1Ea0af92BaCF5831c9FCbDD78aE;
    }

    function expiry_time() public pure override returns (uint256) {
        return 1640966400;
    }
}

contract CollaryzkUSCUSDC is CIPStaking, CHCCollect, CHSLite {
    function address_bond() public pure override returns (address) {
        return 0xF3d7FdB3395CeAba7856A273178f009389C6582d;
    }

    function address_want() public pure override returns (address) {
        return 0x67C9a0830d922C80A96408EEdF606c528836880C;
    }

    function address_call() public pure override returns (address) {
        return 0x255E37fD5747F7fFF87B6BBb72F3A803F3556aB5;
    }

    function address_coll() public pure override returns (address) {
        return 0xF9176bFDe0fDF7D8B9B57e668Fbd8E2cee3072E5;
    }

    function address_collar() public pure override returns (address) {
        return 0xe405bD3C4876D1Ea0af92BaCF5831c9FCbDD78aE;
    }

    function expiry_time() public pure override returns (uint256) {
        return 1633017600;
    }

    function norm_bond_max(uint256 n) public view override returns (uint256) {
        return (n + 99) / 100;
    }

    function norm_bond_min(uint256 n) public view override returns (uint256) {
        return n / 100;
    }
}