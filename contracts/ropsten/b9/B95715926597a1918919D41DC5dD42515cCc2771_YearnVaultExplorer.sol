// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/yearn/IYRegistry.sol";
import "./interfaces/curve/CurveToken.sol";

import "./interfaces/ENS/IENS.sol";
import "./interfaces/ENS/IENSResolver.sol";

contract YearnVaultExplorer is Ownable {
    bytes32 private node = 0x15e1d52381c87881e27faf6f0123992c93652facf5eb0b6d063d5eef4ed9c32d; // v2.registry.ychad.eth
    IENS private ens = IENS(0x2d3f3713F444c1Ef4E6793B869aEBEd94CA02C03);

    struct TokenInfo {
        address addr;
        uint numVaults;
        string symbol;
        uint decimals;
        uint virtualPrice;
    }

    struct VaultInfo {
        address addr;
        uint totalAssets;
        uint pricePerShare;
        uint decimals;
        string symbol;
        string name;
    }

    function finalize() public onlyOwner {
        selfdestruct(payable(address(msg.sender)));
    }

    function resolveYearnRegistry() public view returns (IYRegistry) {
        IENSResolver resolver = ens.resolver(node);
        return IYRegistry(resolver.addr(node));
    }

    function getNumTokens() public view returns (uint numTokens) {
        IYRegistry registry = resolveYearnRegistry();

        numTokens = registry.numTokens();
    }

    function getDataByTokenIndex(uint tokenIndex, uint numTokens) public view returns (
        TokenInfo[] memory tokens,
        VaultInfo[] memory vaults
    ) {
        IYRegistry registry = resolveYearnRegistry();

        if (numTokens == 0) {
            numTokens = registry.numTokens();
        }

        tokens = new TokenInfo[](numTokens);

        uint totalVaults = 0;
        for (uint i = 0; i < numTokens; ++i) {
            address token = registry.tokens(i + tokenIndex);

            tokens[i] = TokenInfo(registry.tokens(i + tokenIndex), registry.numVaults(token), ERC20(token).symbol(), ERC20(token).decimals(), getVirtualPrice(token));

            totalVaults += tokens[i].numVaults;
        }

        vaults = new VaultInfo[](totalVaults);

        uint k = 0;
        for (uint i = 0; i < numTokens; ++i) {
            uint numVaults = tokens[i].numVaults;

            for (uint j = 0; j < numVaults; ++j) {
                IVault vault = IVault(registry.vaults(tokens[i].addr, j));
                vaults[k] = VaultInfo(
                    address(vault),
                    vault.totalAssets(),
                    vault.pricePerShare(),
                    vault.decimals(),
                    vault.symbol(),
                    vault.name());

                k += 1;
            }
        }
    }

    function getDataByTokenAddress(address[] memory inputTokens) public view returns (
        TokenInfo[] memory tokens,
        VaultInfo[] memory vaults
    ) {
        IYRegistry registry = resolveYearnRegistry();

        uint numTokens = inputTokens.length;
        if (numTokens == 0) {
            numTokens = registry.numTokens();
            inputTokens = new address[](numTokens);

            for (uint i = 0; i < numTokens; ++i) {
                inputTokens[i] = registry.tokens(i);
            }
        }

        uint totalVaults = 0;
        tokens = new TokenInfo[](numTokens);

        for (uint i = 0; i < numTokens; ++i) {
            tokens[i] = TokenInfo(inputTokens[i], registry.numVaults(inputTokens[i]), ERC20(inputTokens[i]).symbol(), ERC20(inputTokens[i]).decimals(), getVirtualPrice(inputTokens[i]));
            totalVaults += tokens[i].numVaults;
        }

        vaults = new VaultInfo[](totalVaults);

        uint k = 0;
        for (uint i = 0; i < numTokens; ++i) {
            uint numVaults = tokens[i].numVaults;

            for (uint j = 0; j < numVaults; ++j) {
                IVault vault = IVault(registry.vaults(tokens[i].addr, j));
                vaults[k] = VaultInfo(
                    address(vault),
                    vault.totalAssets(),
                    vault.pricePerShare(),
                    vault.decimals(),
                    vault.symbol(),
                    vault.name());
                k += 1;
            }
        }
    }

    function getVirtualPrice(address token) internal view returns  (uint) {
        string memory name = CurveToken(token).name();

        if (!stringStartsWith("Curve.fi", name)) {
            return 0;
        }

        try CurveToken(token).get_virtual_price() returns (uint virtualPrice) {
            return virtualPrice;
        } catch (bytes memory) {
            try CurveToken(token).minter() returns (address miner) {
                try CurveToken(miner).get_virtual_price() returns (uint minterVirtualPrice) {
                    return minterVirtualPrice;
                } catch (bytes memory) {
                }
            } catch (bytes memory) {
            }
        }

        return 0;
    }

    function bytesToAddress(bytes memory bs) private pure returns (address result) {
        assembly {
            result := mload(add(bs, 32))
        }
    }

    function bytesToUInt(bytes memory bs) internal pure returns (uint result) {
        assembly {
            result := mload(add(bs, 32))
        }
    }

    function stringStartsWith(string memory what, string memory where) public pure returns (bool result) {
        bytes memory whatBytes = bytes (what);
        bytes memory whereBytes = bytes (where);

        if (whatBytes.length > whereBytes.length) {
            return false;
        }

        if (whereBytes.length == 0) {
            return false;
        }

        uint i = 0;
        uint j = 0;

        for (;i < whatBytes.length;) {
            if (whatBytes[i] != whereBytes[j]) {
                return false;
            }

            i += 1;
            j += 1;
        }

        return true;
    }
}