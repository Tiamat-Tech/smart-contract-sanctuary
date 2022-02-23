// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./../libraries/Administrated.sol";
import "./SingleArtistNFT.sol";
import "./MultipleArtistsNFT.sol";

/**
 * @dev NFT factory contract. We are useing it to deploy new NFT collections.
 */
contract NFTFactory is Administrated {
    /// @notice Splitter contract address
    address public splitter;

    /// @dev Emits new token address for a single artist NFT
    event CreatedSingle(
        address indexed token,
        string indexed name,
        string indexed symbol
    );

    /// @dev Emits new token address for a single artist NFT
    event CreatedMultiple(
        address indexed token,
        string indexed name,
        string indexed symbol
    );

    /// @dev Emits when splitter contract address changed
    event SplitterChanged(
        address indexed oldAddress,
        address indexed newAddress
    );

    /**
     * @dev Contract constructor
     * @param _splitter - Address of the splitter contract
     */
    constructor(address _splitter) {
        require(_splitter != address(0), "zero address");
        splitter = _splitter;
    }

    /**
     * @notice Change splitter address
     * @param _splitter - Address of the splitter contract
     */
    function setSplitterContract(address _splitter) external onlyOwner {
        require(_splitter != address(0), "zero address");
        require(_splitter != splitter, "same address");
        splitter = _splitter;
    }

    /**
     * @notice Deploy new NFT contract for single artist
     * @param _name - Name of the NFT
     * @param _symbol - Symbol of the NFT
     * @param _artist - Arrdess of artist
     * @param _privaryDistRecipients - List of primary addresses for distribution
     * @param _primaryDistShares - List of primary percentages for distribution
     * @param _secondaryDistRecipients - List of secondary addresses for distribution
     * @param _secondaryDistShares - List of secondary percentages for distribution
     */
    function createForSingleArtist(
        string memory _name,
        string memory _symbol,
        address _artist,
        address[] memory _privaryDistRecipients,
        uint256[] memory _primaryDistShares,
        address[] memory _secondaryDistRecipients,
        uint256[] memory _secondaryDistShares
    ) external onlyAdmin {
        SingleArtistNFT _newNFT = new SingleArtistNFT(
            _name,
            _symbol,
            admin(),
            splitter,
            _artist,
            _privaryDistRecipients,
            _primaryDistShares,
            _secondaryDistRecipients,
            _secondaryDistShares
        );
        emit CreatedSingle(address(_newNFT), _name, _symbol);
    }

    /**
     * @notice Deploy new NFT contract for single artist
     * @param _name - Name of the NFT
     * @param _symbol - Symbol of the NFT
     * @param _artist - Arrdess of artist
     * @param _privaryDistRecipients - List of primary addresses for distribution
     * @param _primaryDistShares - List of primary percentages for distribution
     * @param _secondaryDistRecipients - List of secondary addresses for distribution
     * @param _secondaryDistShares - List of secondary percentages for distribution
     */
    function createForMultipleArtist(
        string memory _name,
        string memory _symbol,
        address _artist,
        address[] memory _privaryDistRecipients,
        uint256[] memory _primaryDistShares,
        address[] memory _secondaryDistRecipients,
        uint256[] memory _secondaryDistShares
    )
        external
        onlyAdmin
    {
        MultipleArtistsNFT _new = new MultipleArtistsNFT(
            _name,
            _symbol,
            admin(),
            splitter,
            _artist,
            _privaryDistRecipients,
            _primaryDistShares,
            _secondaryDistRecipients,
            _secondaryDistShares
        );
        emit CreatedMultiple(address(_new), _name, _symbol);
    }
}