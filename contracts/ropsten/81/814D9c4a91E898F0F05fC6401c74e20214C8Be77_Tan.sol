// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "base64-sol/base64.sol";

import "./CodeCheck.sol";
import "./State.sol";
import "./VRFD20.sol";

/// @title Tactical Tangrams main Tan contract
/// @author tacticaltangrams.io
/// @notice Tracks all Tan operations for tacticaltangrams.io. This makes this contract the OpenSea Tan collection.
contract Tan is
    ERC721,
    State,
    Ownable,
    VRFD20 {

    event TanMinted(uint counter);

    /// @notice Deployment constructor
    /// @param _name ERC721 name of token
    /// @param _symbol ERC721 symbol of token
    /// @param _openPremintAtDeployment opens premint directly at contract deployment
    constructor(
        string memory _name,
        string memory _symbol,
        bool _openPremintAtDeployment,
        address _vrfCoordinator,
        uint _chainlinkFee)

        ERC721(
            _name,
            _symbol
        )

        // VRF over Chainlink
        VRFD20(
            _vrfCoordinator,                                                    // Rinkeby VRF coordinator
            0x01BE23585060835E02B77ef475b0Cc51aA1e0709,                         // LINK token
            0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311, // Key Hash
            _chainlinkFee                                                       // 0.1 LINK fee
        )
    {
        if (_openPremintAtDeployment) {
            changeState(
                StateType.DEPLOYED,
                StateType.PREMINT);
        }
    }

/*
    function mintOG(uint numTans, string memory code) external
        inState(StateType.PREMINT)
        limitTans(numTans, MAX_TANS_OG)
        oneMint(msg.sender)
    {
        require(
            codeCheckContract.checkCodeOG(msg.sender, code),
            "Invalid code"
        );

        mintLocal(numTans);
    }

    function mintWL(uint numTans, string memory code) external payable
        inState(StateType.PREMINT)
        limitTans(numTans, MAX_TANS_WL)
        oneMint(msg.sender)
        forPrice(numTans, PRICE_WL, msg.value)
    {
        require(
            codeCheckContract.checkCodeWL(msg.sender, code),
            "Invalid code"
        );

        mintLocal(numTans);
    }
*/


    function mint(uint numTans) external payable
        inState(StateType.MINT)
        limitTans(numTans, MAX_TANS_PUBLIC)
        forPrice(numTans, PRICE_PUBLIC, msg.value)
    {
        for (uint mintedTan = 0; mintedTan < numTans; mintedTan++) {
            _mint(msg.sender, ++mintCounter);
        }
    }
    

    /// @notice Set new state
    /// @dev Use this for non-automatic state changes (e.g. open premint, close generation)
    /// @param _to New state to change to
    function setState(StateType _to) external
        onlyOwner()
    {
        changeState(state, _to);
    }

    /// @notice Change to premint stage
    /// @dev This is only allowed by the contract owner, either by means of deployment or later execution of setState
    function changeStatePremint() internal virtual override
        onlyOwner()
        inState(StateType.DEPLOYED)
    {
    }

    /// @notice Change to mint stage; this is an implicit action when "mint" is called when shouldPublicMintBeOpen == true
    /// @dev Can also be called over "setState"
    function changeStateMint() internal virtual override
        inState(StateType.PREMINT)
    {
    }

    /// @notice Change to mint closed stage and request the random seed for generation 1
    function changeStateMintClosed() internal virtual override
        inState(StateType.MINT)
    {
        requestGenerationSeed(1);
    }

    function processGenerationSeedReceived(uint generation) internal virtual override
    {

    }

    modifier limitTans(uint numTans, uint maxTans) {
        require(
            numTans >= 1 &&
            numTans <= maxTans &&
            mintCounter + numTans <= MAX_MINT,
            "Invalid number of tans or no more tans left"
        );
        _;
    }

    modifier oneMint(address _address) {
        require(
            balanceOf(_address) == 0,
            "Only one premint allowed"
        );
        _;
    }

    modifier forPrice(uint numTans, uint unitPrice, uint ethSent) {
        require(
            numTans * unitPrice == ethSent,
            "Wrong value sent"
        );
        _;
    }

    // mint
    uint private mintCounter             = 0;

    uint constant public MAX_MINT        = 15554;
    uint constant public MAX_TANS_OG     = 7;
    uint constant public MAX_TANS_WL     = 7;
    uint constant public MAX_TANS_PUBLIC = 14;

    uint constant public PRICE_WL        = 2 * 1e16;
    uint constant public PRICE_PUBLIC    = 3 * 1e16;


    uint[4] public mintShares = [
        450,
        300,
        125,
        125
    ];

    uint[4] public openMintShares;

    function Test() external payable {

    }
}