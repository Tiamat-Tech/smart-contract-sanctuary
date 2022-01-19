// contracts/token/ERC721/spaces/RareSpaceNFTContractFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./RareSpaceNFT.sol";
import "../../../marketplace/IMarketplaceSettings.sol";
import "../../../royalty/creator/IERC721CreatorRoyalty.sol";
import "../../../registry/spaces/ISpaceOperatorRegistry.sol";

contract RareSpaceNFTContractFactory is Ownable {
    IMarketplaceSettings public marketplaceSettings;
    IERC721CreatorRoyalty public royaltyRegistry;
    ISpaceOperatorRegistry public spaceOperatorRegistry;

    address public rareSpaceNFT;

    event RareSpaceNFTContractCreated(
        address indexed _contractAddress,
        address indexed _operator
    );

    constructor(
        address _marketplaceSettings,
        address _royaltyRegistry,
        address _spaceOperatorRegistry
    ) {
        require(_marketplaceSettings != address(0));
        require(_royaltyRegistry != address(0));
        require(_spaceOperatorRegistry != address(0));

        marketplaceSettings = IMarketplaceSettings(_marketplaceSettings);
        royaltyRegistry = IERC721CreatorRoyalty(_royaltyRegistry);
        spaceOperatorRegistry = ISpaceOperatorRegistry(_spaceOperatorRegistry);

        RareSpaceNFT _rareSpaceNFT = new RareSpaceNFT();
        rareSpaceNFT = address(_rareSpaceNFT);
    }

    function setIMarketplaceSettings(address _marketplaceSettings)
        external
        onlyOwner
    {
        require(_marketplaceSettings != address(0));
        marketplaceSettings = IMarketplaceSettings(_marketplaceSettings);
    }

    function setIERC721CreatorRoyalty(address _royaltyRegistry)
        external
        onlyOwner
    {
        require(_royaltyRegistry != address(0));
        royaltyRegistry = IERC721CreatorRoyalty(_royaltyRegistry);
    }

    function setRareSpaceNFT(address _rareSpaceNFT) external onlyOwner {
        require(_rareSpaceNFT != address(0));
        rareSpaceNFT = _rareSpaceNFT;
    }

    function createRareSpaceNFTContract(
        string calldata _name,
        string calldata _symbol
    ) public returns (address) {
        address spaceAddress = Clones.clone(rareSpaceNFT);
        RareSpaceNFT(spaceAddress).init(_name, _symbol, msg.sender);
        emit RareSpaceNFTContractCreated(spaceAddress, msg.sender);

        marketplaceSettings.setERC721ContractPrimarySaleFeePercentage(
            spaceAddress,
            15
        );

        royaltyRegistry.setPercentageForSetERC721ContractRoyalty(
            spaceAddress,
            10
        );

        spaceOperatorRegistry.setOperatorForSpace(msg.sender, spaceAddress);

        spaceOperatorRegistry.setSpaceCommission(msg.sender, 5);

        return spaceAddress;
    }
}