// SPDX-License-Identifier: MIT
pragma solidity ^0.7.2;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./interfaces/ICeroStruct.sol";
import "./services/NameGenerator.sol";
import "./services/Globals.sol";

/// @title This contract generate new NFT tokens within certain parameters and manages the token data.
/// @author Oleksandr Fedorenko
contract CeroToken is ICeroStruct, ERC721("Cero", "Cr"), NameGenerator, Globals {
    /// @notice Contain all tokens structure.
    Cero[] public ceroes;

    /// @notice Contain all addresses that accepted for minting new token.
    mapping(address => uint256) public acceptedToCreateBaseToken;

    /// @notice Fee for each transaction (Wei).
    uint256 public fee = 1000000000000000;

    bool private isFirstCeroCreated = false;

    /// @notice Set toke URI
    /// @param _tokenId Token ID
    /// @param _tokenURI Token metadata
    function setTokenURI(uint256 _tokenId, string memory _tokenURI) external {
        require(ownerOf(_tokenId) == msg.sender, "[ECT-187] - Only token owner can set token description.");
        _setTokenURI(_tokenId, _tokenURI);
    }

    /// @return Token count in contract
    function getTokensCount() external view returns (uint256) {
        return ceroes.length;
    }

    /// @notice When contract deploy, create first Cero for owner. All next ceroes 1 lvl, will be have this token as a parent.
    function generateFirstToken() external onlyOwner {
        require(!isFirstCeroCreated, "[ECT-101] - First token already generated.");

        isFirstCeroCreated = true;
        createToken(msg.sender, 1, 1, 1, 1, 1, 0, 0, false);
    }

    /// @notice Mint new token by params.
    /// @param _tokenOwner new token owner
    /// @param _lvl Level
    /// @param _st Strength parameter
    /// @param _pr Protection parameter
    /// @param _ag Agility parameter
    /// @param _ma Magic  parameter
    /// @param _parent1 Token parent1
    /// @param _parent2 Token parent2
    /// @param _isChild Is cero have child
    function createToken(
        address _tokenOwner,
        uint8 _lvl,
        uint16 _st,
        uint16 _pr,
        uint16 _ag,
        uint16 _ma,
        uint256 _parent1,
        uint256 _parent2,
        bool _isChild
    ) public onlyOwner {
        Cero memory _cero =
            Cero({
                name: NameGenerator.getCeroName(),
                lvl: _lvl,
                strength: _st,
                protection: _pr,
                agility: _ag,
                magic: _ma,
                parent1: _parent1,
                parent2: _parent2,
                isChild: _isChild,
                birthday: uint64(block.timestamp),
                experience: getExperienceCountForLevelUp(_lvl)
            });

        ceroes.push(_cero);
        uint256 newCeroNum = ceroes.length - 1;

        ERC721._mint(_tokenOwner, newCeroNum);
    }

    /// @notice Set token count that can be created from address.
    /// @param _address User address
    /// @param _tokenCount Token count to create
    function setAcceptedToCreateBaseToken(address _address, uint256 _tokenCount) external onlyOwner {
        acceptedToCreateBaseToken[_address] = _tokenCount;
    }

    /// @notice Update token status after child creation
    /// @param _tokenNum Token number
    /// @param _newStatus New status
    function updateTokenChildStatus(uint256 _tokenNum, bool _newStatus) external onlyOwner {
        ceroes[_tokenNum].isChild = _newStatus;
    }

    /// @notice Update token experience after fight
    /// @param _tokenNum Token number
    /// @param _newExperience New experience
    function updateTokenExperience(uint256 _tokenNum, uint256 _newExperience) external onlyOwner {
        ceroes[_tokenNum].experience = _newExperience;
    }

    /// @notice Update token data after level up
    /// @param _tokenNum Token number
    /// @param _st New strength
    /// @param _pr New protection
    /// @param _ag New agility
    /// @param _ma New magic
    /// @param _lvl New level
    function updateTokenAfterLevelUp(
        uint256 _tokenNum,
        uint16 _st,
        uint16 _pr,
        uint16 _ag,
        uint16 _ma,
        uint8 _lvl
    ) external onlyOwner {
        ceroes[_tokenNum].strength = _st;
        ceroes[_tokenNum].protection = _pr;
        ceroes[_tokenNum].agility = _ag;
        ceroes[_tokenNum].magic = _ma;
        ceroes[_tokenNum].lvl = _lvl;
    }

    /// @notice Get token data for calculations
    /// @param _tokenNum Token number
    /// @return Token data
    function getTokenShortDataType1(uint256 _tokenNum)
        public
        view
        returns (
            uint16,
            uint16,
            uint16,
            uint16,
            uint8,
            bool
        )
    {
        return (
            ceroes[_tokenNum].strength,
            ceroes[_tokenNum].protection,
            ceroes[_tokenNum].agility,
            ceroes[_tokenNum].magic,
            ceroes[_tokenNum].lvl,
            ceroes[_tokenNum].isChild
        );
    }

    /// @notice Get token data for calculations
    /// @param _tokenNum Token number
    /// @return _st _pr _ag _ma _lvl _isChild _exp Token data
    function getTokenShortDataType2(uint256 _tokenNum)
        external
        view
        returns (
            uint16 _st,
            uint16 _pr,
            uint16 _ag,
            uint16 _ma,
            uint8 _lvl,
            bool _isChild,
            uint256 _exp
        )
    {
        (_st, _pr, _ag, _ma, _lvl, _isChild) = getTokenShortDataType1(_tokenNum);
        _exp = ceroes[_tokenNum].experience;
    }

    /// @notice Get token data for calculations
    /// @param _tokenNum Token number
    /// @return Token data
    function getTokenShortDataType3(uint256 _tokenNum) public view returns (uint8, bool) {
        return (ceroes[_tokenNum].lvl, ceroes[_tokenNum].isChild);
    }

    /// @notice Return all tokens struct.
    /// @return _ceroes Array of Cero structure
    function getAllTokens() external view returns (Cero[] memory _ceroes) {
        _ceroes = new Cero[](ceroes.length);

        for (uint256 i = 0; i < ceroes.length; i++) {
            _ceroes[i] = ceroes[i];
        }
    }

    /// @notice Return all ceroes by address
    /// @param _owner Tokens owner address
    /// @return _ceroes Array of tokens structure. Only for selected owner
    /// @return _ids Array of tokens IDs. Only for selected owner
    function getTokensByAddress(address _owner) external view returns (Cero[] memory _ceroes, uint256[] memory _ids) {
        uint256 _tokenNum = ERC721.balanceOf(_owner);
        _ceroes = new Cero[](_tokenNum);
        _ids = new uint256[](_tokenNum);

        uint256 _counter = 0;
        for (uint256 i = 0; i < ceroes.length; i++) {
            if (ERC721.ownerOf(i) == _owner) {
                _ceroes[_counter] = ceroes[i];
                _ids[_counter] = i;
                _counter++;
            }
        }
    }
}