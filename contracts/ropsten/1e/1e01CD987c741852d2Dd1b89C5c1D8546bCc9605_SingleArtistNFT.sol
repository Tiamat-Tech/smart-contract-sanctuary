// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./../libraries/Administrated.sol";
import "erc721a/contracts/ERC721A.sol";
import "./../marketplace/ISplitterContract.sol";

/// @dev we will bring in the openzeppelin ERC721 NFT functionality
contract SingleArtistNFT is Administrated, ERC721A {
    /**
     * @notice Runs once when the contract is deployed
     * @param _name - NFT token name
     * @param _symbol - NFT token symbol
     * @param _admin - address of the admin
     * @param _splitter - address of the Splitter contract
     * @param _artist - Arrdess of artist
     * @param _primaryDistRecipients - List of primary addresses for distribution
     * @param _primaryDistShares - List of primary percentages for distribution
     * @param _secondaryDistRecipients - List of secondary addresses for distribution
     * @param _secondaryDistShares - List of secondary percentages for distribution
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _admin,
        address _splitter,
        address _artist,
        address[] memory _primaryDistRecipients,
        uint256[] memory _primaryDistShares,
        address[] memory _secondaryDistRecipients,
        uint256[] memory _secondaryDistShares
    ) ERC721A(_name, _symbol) {
        require(_admin != address(0), "zero_addr");
        require(_splitter != address(0), "zero_addr");
        require(_artist != address(0), "zero_addr");
        require(
            _primaryDistRecipients.length == _primaryDistShares.length,
            "diff_length"
        );
        require(
            _secondaryDistRecipients.length == _secondaryDistShares.length,
            "diff_length"
        );
        changeAdmin(_admin);
        ISplitterContract(_splitter).setPrimaryDistribution(
            _artist,
            _primaryDistRecipients,
            _primaryDistShares
        );
        ISplitterContract(_splitter).setSecondaryDistribution(
            _artist,
            _secondaryDistRecipients,
            _secondaryDistShares
        );
    }

    function mint(uint256 _quantity) external onlyAdmin {
        require(_quantity > 0, "zero_amount");
        _safeMint(admin(), _quantity);
    }

    function mintTo(address _receiver, uint256 _quantity) external onlyAdmin {
        require(_quantity > 0, "zero_amount");
        _safeMint(_receiver, _quantity);
    }
}