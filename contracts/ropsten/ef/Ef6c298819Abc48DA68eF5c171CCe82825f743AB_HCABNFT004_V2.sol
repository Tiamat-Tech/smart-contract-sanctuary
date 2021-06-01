// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";

contract HCABNFT004_V2 is
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155HolderUpgradeable
{
    uint256 public MAIN_CONTRACT_ID;
    uint256 public MAIN_CONTRACT_SUPPLY;
    uint256 private NFT_SUPPLY;

    struct NFT {
        string NAME;
        uint256 ID;
        uint256 RATIO;
    }

    NFT public NFT01;
    NFT public NFT02;
    NFT public NFT03;

    string public LEGAL_CONTENT;

    bytes32 public BURNER_ROLE;
    bytes32 public MINTER_ROLE;

    address public contract_owner;

    function initialize() public initializer {
        contract_owner = owner();

        MAIN_CONTRACT_SUPPLY = 64 * (10**6);
        NFT_SUPPLY = 1;

        MAIN_CONTRACT_ID = 1;
        NFT01.ID = 2;
        NFT02.ID = 3;
        NFT03.ID = 4;

        NFT01.RATIO = 33;
        NFT02.RATIO = 33;
        NFT03.RATIO = 34;

        NFT01.NAME = "OBRA DE ARTE 01";
        NFT02.NAME = "OBRA DE ARTE 02";
        NFT03.NAME = "OBRA DE ARTE 03";

        LEGAL_CONTENT = "OBRA DE ARTE 03";

        MINTER_ROLE = keccak256("MINTER_ROLE");
        BURNER_ROLE = keccak256("BURNER_ROLE");

        _setupRole(MINTER_ROLE, contract_owner);
        _setupRole(BURNER_ROLE, contract_owner);
        _setupRole(DEFAULT_ADMIN_ROLE, contract_owner);

        _mint(contract_owner, MAIN_CONTRACT_ID, MAIN_CONTRACT_SUPPLY, "");
        _mint(contract_owner, NFT01.ID, NFT_SUPPLY, "");
        _mint(contract_owner, NFT02.ID, NFT_SUPPLY, "");
        _mint(contract_owner, NFT03.ID, NFT_SUPPLY, "");
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function burn(
        address account,
        uint256 tokenId,
        uint256 amount
    ) public override onlyRole(BURNER_ROLE) {
        _burn(account, tokenId, amount);
    }

    function adminBurnNft(uint256 tokenId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        burnNFT(tokenId);

        if (tokenId == NFT01.ID) {
            _burn(
                contract_owner,
                MAIN_CONTRACT_ID,
                (MAIN_CONTRACT_SUPPLY * NFT01.RATIO) / 100
            );
        } else if (tokenId == NFT02.ID) {
            _burn(
                contract_owner,
                MAIN_CONTRACT_ID,
                (MAIN_CONTRACT_SUPPLY * NFT02.RATIO) / 100
            );
        } else if (tokenId == NFT03.ID) {
            _burn(
                contract_owner,
                MAIN_CONTRACT_ID,
                (MAIN_CONTRACT_SUPPLY * NFT03.RATIO) / 100
            );
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            AccessControlUpgradeable,
            ERC1155Upgradeable,
            ERC1155ReceiverUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function isTokenNFT(uint256 tokenId) internal view {
        bool checkToken = (tokenId >= NFT01.ID) && (tokenId <= NFT03.ID);

        require(
            checkToken,
            string(abi.encodePacked("tokenId is not an NFT ", checkToken))
        );
    }

    function burnNFT(uint256 tokenId) internal {
        isTokenNFT(tokenId);

        uint256 tokenBalance = balanceOf(contract_owner, tokenId);
        bool hasBalance = tokenBalance == NFT_SUPPLY;

        require(hasBalance, "not enough balance for the tokenId");

        _burn(contract_owner, tokenId, NFT_SUPPLY);
    }
}