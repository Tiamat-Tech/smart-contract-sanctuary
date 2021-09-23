// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface ICheckerboard {
    function buyPieceByCoin(uint coinNum, address buyer) external returns (uint);
}

contract Checkerboard is ERC721, ICheckerboard{

    struct PieceOnBoard {
        uint level;
        uint tokenId;
    }

    uint public maxLimit = 100;
    PieceOnBoard[1000][1000] public piecesOnBoard;
    address public owner;
    

    event HasPlayChess(uint across, uint down, address ownerAddr, uint tokenId, uint level);
    event HasMovePiece(uint fromAcross, uint fromDown, uint toAcross, uint toDown, address toOwnerAddr, uint toTokenId, uint toLevel);
    event UnlockPiece(uint across, uint down, address ownerAddr, uint tokenId, uint level);
    event UpdatePieceLevel(uint across, uint down, uint level);
    event BuyPieces(address buyer, uint tokenId, uint level);
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setMaxLimit(uint _maxLimit) public onlyOwner {
        maxLimit = _maxLimit;
    }

    function playChess(uint _across, uint _down, uint _tokenId) public onlyOwner {
        require(
            _across < maxLimit && _down < maxLimit,
            "Exceeding the length of the board"
        );

        require(
            piecesOnBoard[_across][_down].level == 0,
            "Exceeding the length of the board"
        );

        piecesOnBoard[_across][_down] = PieceOnBoard({
            level:_getTokenLevel(_tokenId),
            tokenId:_tokenId
        });

        _lockPiece(_tokenId);
        
        emit HasPlayChess(_across, _down, ownerOf(_tokenId), _tokenId, _getTokenLevel(_tokenId));
    }

    function movePiece(uint _fromAcross, uint _fromDown, uint _toAcross, uint _toDown) public onlyOwner {
        require(
            _toAcross < maxLimit && _toDown < maxLimit,
            "Exceeding the length of the board"
        );

        require(
            _fromAcross != _toAcross || _fromDown != _toDown,
            "Movement does not comply with the rules"
        );

        PieceOnBoard storage fromPieceOnBoard = piecesOnBoard[_fromAcross][_fromDown];
        PieceOnBoard storage toPieceOnBoard = piecesOnBoard[_toAcross][_toDown];

        require(
            ownerOf(fromPieceOnBoard.tokenId) == msg.sender,
            "The current position is not your pawn"
        );

        require(
            ownerOf(toPieceOnBoard.tokenId)  != msg.sender,
            "You can't eat your own pawn"
        );
        
        require (
            toPieceOnBoard.level < fromPieceOnBoard.level,
            "Can't eat high level piece"
        );


        if(toPieceOnBoard.level != 0) {
            _setTokenLevel(toPieceOnBoard.tokenId, toPieceOnBoard.level - 1);
            _setTokenLevel(fromPieceOnBoard.tokenId, fromPieceOnBoard.level + 1);

            _unlockPiece(toPieceOnBoard.tokenId);
            emit UnlockPiece(_toAcross, _toDown, ownerOf(toPieceOnBoard.tokenId), toPieceOnBoard.tokenId, _getTokenLevel(toPieceOnBoard.tokenId));

            toPieceOnBoard.level = _getTokenLevel(fromPieceOnBoard.tokenId);
            toPieceOnBoard.tokenId = fromPieceOnBoard.tokenId;
        } else {
            toPieceOnBoard.level = fromPieceOnBoard.level;
            toPieceOnBoard.tokenId = fromPieceOnBoard.tokenId;
        }

        BlankingPosition(_fromAcross, _fromDown);

        emit HasMovePiece(_fromAcross, _fromDown, _toAcross, _toDown, ownerOf(toPieceOnBoard.tokenId), toPieceOnBoard.tokenId, _getTokenLevel(toPieceOnBoard.tokenId));
    }


    function unlockPieceByPosition(uint _across, uint _down) public onlyOwner {
        require(
            _across < maxLimit && _down < maxLimit,
            "Exceeding the length of the board"
        );

        PieceOnBoard storage piece = piecesOnBoard[_across][_down];
        _unlockPiece(piece.tokenId);
        BlankingPosition(_across, _down);
        emit UnlockPiece(_across, _down, ownerOf(piece.tokenId), piece.tokenId, _getTokenLevel(piece.tokenId));
    }   

    function updatePieceByPosition(uint _across, uint _down) public onlyOwner {
        require(
            _across < maxLimit && _down < maxLimit,
            "Exceeding the length of the board"
        );
        
        PieceOnBoard storage piece = piecesOnBoard[_across][_down];
        _setTokenLevel(piece.tokenId, piece.level + 1);
        piece.level = _getTokenLevel(piece.tokenId);
        emit UpdatePieceLevel(_across, _down, piece.level);
    }

    function BlankingPosition(uint _across, uint _down) internal {
        piecesOnBoard[_across][_down] = (PieceOnBoard({
        level:0,
        tokenId:0
        }));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////

    mapping(uint => bool) _tokenLocks;
    mapping(uint => uint) _tokenLevels;
    mapping(address => uint[]) public _allTokens;
    string _jsonURIPrefix;
    uint _ratio;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    using Strings for uint256;

    address public allowInvoker;

    constructor() ERC721("Numbre", "NBR") {
        _ratio = 1;
        owner = msg.sender;
    }

    function setAllowInvoker(address newInvoker) public onlyOwner{
        allowInvoker = newInvoker;
    }

    function buyPieceByCoin(uint coinNum, address buyer) public override returns (uint256) {
        require(msg.sender == allowInvoker, 'call method access deny');
        uint level = coinNum / _ratio;
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(buyer, newTokenId);
        _tokenLocks[newTokenId] = false;
        _tokenLevels[newTokenId] = level;
        _allTokens[buyer].push(newTokenId);
        
        emit BuyPieces(buyer, newTokenId, level);
        return newTokenId;
    }

    //lock a piece
    function _lockPiece(uint tokenId) internal virtual{
        require(_tokenLocks[tokenId] == false, 'this token is already in locked status');
        _tokenLocks[tokenId] = true;
    }

    //unlock a piece
    function _unlockPiece(uint tokenId) internal virtual{
        require(_tokenLocks[tokenId] == true, 'this token is already in unlocked status');
        _tokenLocks[tokenId] = false;
    }

    //get token level
    function _getTokenLevel(uint tokenId) internal view virtual returns (uint){
        require(_exists(tokenId), 'tokenId not existed');
        return _tokenLevels[tokenId];
    }

    //set token level
    function _setTokenLevel(uint tokenId, uint level) internal virtual {
        require(_exists(tokenId), 'tokenId not existed');
        _tokenLevels[tokenId] = level;
    }

    function _getTokenId() public view returns (string memory) {
        string memory tokenIds;
        for(uint i = 0; i < _allTokens[msg.sender].length; i++) {
            if(i == 0) {
                 tokenIds = _allTokens[msg.sender][i].toString();
            } else {
                tokenIds = string(abi.encodePacked(tokenIds, ',', _allTokens[msg.sender][i].toString()));
            }
        }
        return tokenIds;
    }
    
    function _getTokenIdWithAddress(address tokenOwner) public view returns (string memory) {
        string memory tokenIds;
        for(uint i = 0; i < _allTokens[tokenOwner].length; i++) {
            if(i == 0) {
                 tokenIds = _allTokens[tokenOwner][i].toString();
            } else {
                tokenIds = string(abi.encodePacked(tokenIds, ',', _allTokens[tokenOwner][i].toString()));
            }
        }
        return tokenIds;
    }

    //override tokenURI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");
        // return string(abi.encodePacked(_baseURI(),tokenId.toString(), '.json'));
        // string memory level = _getTokenLevel(tokenId).toString();
        // level.length
        
        string[10] memory parts;
        parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 300 300">';
        parts[1] = '<rect width="100%" height="100%" fill="#010101" />';
 		parts[2] = '<style>.title {stroke:white; fill:none; stroke-width:1.2;font-weight: bold; font-family: Verdana, sans-serif; font-size: 47px; text-anchor:start;}</style>';
    	parts[3] = '<text x="14" y="50" class="title" >Numbre</text>';
	    parts[4] = '<style>.base { fill: #ffffff; font-family: Verdana, sans-serif; font-weight: bold; font-size: 20px; font-weight: bold; dominant-baseline:middle; text-anchor:start;}</style>';
	    parts[5] = '<path d="M 90 60 90 160" style="stroke: gray; fill: none;"/>';
	    parts[6] = '<text x="14" y="80"  class="base"> Level</text>';
        parts[7] = '<text x="100" y="80" class="base">';
        parts[8] = _getTokenLevel(tokenId).toString();
        parts[9] = '</text></svg>';
        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5],parts[6], parts[7], parts[8], parts[9]));
        string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "NBR #', tokenId.toString(), '", "description": "this is NBR", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
        output = string(abi.encodePacked('data:application/json;base64,', json));
        return output;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _jsonURIPrefix;
    }

    function setBaseURI(string memory uri) public onlyOwner{
        _jsonURIPrefix = uri;
    }

    //override _beforeTokenTransfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override{
        require(_tokenLocks[tokenId] == false, 'transfer failed. this token is in locked status');
    }

}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}