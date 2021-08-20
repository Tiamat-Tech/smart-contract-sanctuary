//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import "./interfaces/ILandPlot.sol";

/// @title Upgradable Minecraft LandPlot NFT
/// @author icpigci
contract LandPlot is ILandPlot, ERC721Upgradeable, OwnableUpgradeable {
    /*** Storage Properties ***/

    mapping(uint256 => int128) public chunk_x; // mapping from tokenId to x chunk coordinate;
    mapping(uint256 => int128) public chunk_z; // mapping from tokenId to z chunk coordinate;
    mapping(int128 => mapping(int128 => uint256)) public override tokenIdOf; // mapping from x to z to tokenId

    bool public override claimable;
    uint256 public override totalSupply;
    uint128 public override worldSize; // the max chunk coordinate of any claimable chunk, e.g. if the size is 10, the user can mint nfts from -9,-9 to 9,9

    // prices for plots based on distance - curve is calculated off chain
    uint256[] public plotPrices;
    uint256[] public plotPriceDistances;

    /*** Contract Logic Starts Here */

    function initialize(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC721_init(_name, _symbol);
        __Ownable_init();

        claimable = false; // purchases are not initially available
        worldSize = 2000; //the world is 4000x4000 chunks, or 64000x64000 blocks
    }

    // Admin Functions

    /// @notice the contract owner can set claimable status
    /// @param _claimable Boolean flag on whether or not people can claim land
    function setClaimable(bool _claimable) external override onlyOwner {
        claimable = _claimable;
    }

    /// @notice the contract owner can set plot prices
    /// @param _prices An array of prices in wei which correspond to a matching distance, eg [10000000000000,1000000,10000,100,...]
    /// @param _distances An array of distances in chunks which correspond to a matching price, eg [10,100,700,800,...]
    function setPlotPrices(
        uint256[] memory _prices,
        uint256[] memory _distances
    ) external override onlyOwner {
        require(_prices.length == _distances.length, "length doesn't match");

        plotPrices = _prices;
        plotPriceDistances = _distances;
    }

    /// @notice the contract owner can set world size
    /// @param _worldSize as an uint128
    function setWorldSize(uint128 _worldSize) external override onlyOwner {
        require(_worldSize > 0, "World limit must be > 0");

        worldSize = _worldSize;
    }

    /// @notice the contract owner may mint any nft for anybody
    /// @param _recv address which will receive the nft
    /// @param _xs array of x chunk coordinate that the nfts will correspond to
    /// @param _zs array of z chunk coordinate that the nfts will correspond to
    function mintMany(
        address _recv,
        int128[] memory _xs,
        int128[] memory _zs
    ) external override onlyOwner {
        require(
            _xs.length == _zs.length,
            "xs and zs coordinate count must match"
        );

        _claimLands(_recv, _xs, _zs);
    }

    /// @notice the contract owner may mint any nft for anybody
    /// @param _recv address which will receive the nft
    /// @param _x x chunk coordinate that the nft will correspond to
    /// @param _z z chunk coordinate that the nft will correspond to
    function mintOne(
        address _recv,
        int128 _x,
        int128 _z
    ) external override onlyOwner {
        _genesisMint(_recv, _x, _z);
    }

    // User Functions

    /// @notice claim chunks
    /// @param _xs array of x chunk coordinates to match with zs
    /// @param _zs array of z chunk coordinates to match with xs
    function claimLands(int128[] memory _xs, int128[] memory _zs)
        external
        payable
        override
    {
        require(claimable, "claiming is currently disabled");
        require(
            _xs.length <= 128,
            "cannot claim more than 128 chunks at a time!"
        );
        require(
            _xs.length == _zs.length,
            "xs and zs array lengths must match!"
        );

        // calculate total cost

        uint256 total_cost = 0;
        for (uint256 i = 0; i < _xs.length; i++) {
            total_cost = total_cost + _calculateLandCost(_xs[i], _zs[i]);
        }
        require(
            msg.value >= total_cost,
            "not enough eth sent to purchase land"
        );

        if (msg.value > total_cost) {
            // transfer remaining eth back

            uint256 remaining = msg.value - total_cost;
            payable(msg.sender).transfer(remaining);
        }

        _claimLands(msg.sender, _xs, _zs);
    }

    /// @notice transfer multiple tokens at once
    /// @param _recv address which will receive the nft
    /// @param _tokenIds array of tokenId
    function multiTransfer(address _recv, uint256[] memory _tokenIds)
        external
        override
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            safeTransferFrom(msg.sender, _recv, _tokenIds[i], "");
        }
    }

    /// @notice get the chunk coordinates of which nft with id tokenId has jusrisdiction over
    /// @param _tokenId id of the nft
    /// @return (int128,int128) corresponding to the chunk with chunk coordinates (x,z);
    function chunkOf(uint256 _tokenId)
        external
        view
        override
        returns (int128, int128)
    {
        require(_tokenId > 0 && _tokenId <= totalSupply, "invalid tokenId");

        return (chunk_x[_tokenId], chunk_z[_tokenId]);
    }

    /// @notice calculate price for the chunk coordinate
    /// @param _x x chunk coordinate of the plot
    /// @param _z z chunk coordinate of the plot
    /// @return price in wei as uin256
    function calculateLandCost(int128 _x, int128 _z)
        external
        view
        override
        returns (uint256)
    {
        return _calculateLandCost(_x, _z);
    }

    // Internal Functions

    /// @notice calculate price of chunk coordinate
    /// @param _x x chunk coordinate of the plot
    /// @param _z z chunk coordinate of the plot
    /// @return price in wei as uin256
    function _calculateLandCost(int128 _x, int128 _z)
        internal
        view
        returns (uint256 price)
    {
        uint128 xA = uint128(_x >= 0 ? _x : -_x);
        uint128 zA = uint128(_z >= 0 ? _z : -_z);
        uint128 min = (xA < zA ? xA : zA);

        price = 0;
        for (uint256 i = 0; i < plotPrices.length; i++) {
            if (min <= plotPriceDistances[i] && price < plotPrices[i]) {
                price = plotPrices[i];
            }
        }
    }

    /// @notice claim chunks
    /// @param _recv address which will receive the nft
    /// @param _xs array of x chunk coordinates to match with zs
    /// @param _zs array of z chunk coordinates to match with xs
    function _claimLands(
        address _recv,
        int128[] memory _xs,
        int128[] memory _zs
    ) internal {
        for (uint256 i = 0; i < _xs.length; i++) {
            _genesisMint(_recv, _xs[i], _zs[i]);
        }
    }

    /// @notice mint nft
    /// @param _recv address which will receive the nft
    /// @param _x x chunk coordinate that the nft will correspond to
    /// @param _z z chunk coordinate that the nft will correspond to
    function _genesisMint(
        address _recv,
        int128 _x,
        int128 _z
    ) internal returns (uint256 tokenId) {
        require(
            tokenIdOf[_x][_z] == 0,
            "attempting to mint already minted land"
        );

        uint128 xA = uint128(_x >= 0 ? _x : -_x);
        uint128 zA = uint128(_z >= 0 ? _z : -_z);
        require(
            (worldSize > xA) && (worldSize > zA),
            "the claim is beyond the specified world size"
        );

        // tokenId starts from 1
        totalSupply = totalSupply + 1;
        _safeMint(_recv, totalSupply);
        chunk_x[totalSupply] = _x;
        chunk_z[totalSupply] = _z;
        tokenIdOf[_x][_z] = totalSupply;

        return totalSupply;
    }
}