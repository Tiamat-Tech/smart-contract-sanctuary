// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721Receiver.sol";
import './IERC1155Receiver.sol';
import "./ERC165.sol";
import './Events.sol';
import './Ownable.sol';

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function totalSupply() external view returns (uint256);
    function exists(uint256 tokenId) external view returns (bool);
    function approve(address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

interface IERC1155 {
    function setApprovalForAll(address operator, bool approved) external;
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount,bytes calldata data) external;
}

interface ISwap {
    function swapErc20(uint256 gratiaId, address inToken, uint256 inAmount, address outToken, uint8 router, address to) external;
    function swapErc721(uint256 gratiaId, address inToken, uint256 inId, address outToken, uint8 router, address to) external;
    function swapErc1155(uint256 gratiaId, address inToken, uint256 inId, uint256 inAmount, address outToken, uint256 outId, uint8 router, address to) 
    external;
}

contract GratiaPack is ERC165, IERC1155Receiver, IERC721Receiver, Context, Events, Ownable {

    struct Token {
        uint8 tokenType; // 1: ERC20, 2: ERC721, 3: ERC1155
        address tokenAddress;
    }

    // Token types
    uint8 private constant TOKEN_TYPE_ERC20 = 1;
    uint8 private constant TOKEN_TYPE_ERC721 = 2;
    uint8 private constant TOKEN_TYPE_ERC1155 = 3;

    uint256 private constant MAX_GRATIA_SUPPLY = 13337;

    // Mapping from gratia ID -> token(erc20) -> balance
    mapping(uint256 => mapping(address => uint256)) private _insideERC20TokenBalances;

    // Mapping from gratia ID -> token(erc1155) -> tokenId -> balance
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) private _insideERC1155TokenBalances;

    // Mapping from gratia ID -> tokens
    mapping(uint256 => Token[]) private _insideTokens;

    // Mapping from gratia ID -> token(erc721 or erc1155) -> ids
    mapping(uint256 => mapping(address => uint256[])) private _insideTokenIds;

    // Mapping from gratia ID -> locked time
    mapping(uint256 => uint256) private _lockedTimestamp;

    IERC721 public _gratia;
    ISwap public _swap;

    modifier onlyGratiaOwner(uint256 gratiaId) {
        require(_gratia.exists(gratiaId), "Gratia does not exist");
        require(_gratia.ownerOf(gratiaId) == msg.sender, "Only owner can call");
        _;
    }
    
    modifier gratiaExists(uint256 gratiaId) {
        require(_gratia.exists(gratiaId), "Gratia does not exist");
        _;
    }

    modifier unlocked(uint256 gratiaId) {
        require(_lockedTimestamp[gratiaId] == 0 || _lockedTimestamp[gratiaId] < block.timestamp, "Gratia is locked");
        _;
    }

    constructor(address gratia) {
        _gratia = IERC721(gratia);
    }

    // View functions

    /**
     * @dev check if token exists inside gratia.
     */
    function existsId(uint256 gratiaId, address token, uint256 id) public view returns (bool) {
        uint256[] memory ids = _insideTokenIds[gratiaId][token];

        for (uint256 i; i < ids.length; i++) {
            if (ids[i] == id) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev check if gratia has been locked.
     */
    function isLocked(uint256 gratiaId) external view gratiaExists(gratiaId) returns (bool locked, uint256 endTime) {
        if (_lockedTimestamp[gratiaId] == 0 || _lockedTimestamp[gratiaId] < block.timestamp) {
            locked = false;
        } else {
            locked = true;
            endTime = _lockedTimestamp[gratiaId];
        }
    }


    /**
     * @dev get token counts inside gratia
     */
    function getInsideTokensCount(uint256 gratiaId) public view gratiaExists(gratiaId) returns (uint256 erc20Len, uint256 erc721Len, uint256 erc1155Len) {
        Token[] memory tokens = _insideTokens[gratiaId];
        for (uint256 i; i < tokens.length; i++) {
            Token memory token = tokens[i];
            if (token.tokenType == TOKEN_TYPE_ERC20) {
                erc20Len += 1;
            }
            if (token.tokenType == TOKEN_TYPE_ERC721) {
                erc721Len += 1;
            }
            if (token.tokenType == TOKEN_TYPE_ERC1155) {
                erc1155Len += 1;
            }
        }
    }

    /**
     * @dev get tokens by gratiaId
     */
    function getTokens(uint256 gratiaId) external view gratiaExists(gratiaId) returns (uint8[] memory tokenTypes, address[] memory tokenAddresses) {
        Token[] memory tokens = _insideTokens[gratiaId];
        
        tokenTypes = new uint8[](tokens.length);
        tokenAddresses = new address[](tokens.length);

        for (uint256 i; i < tokens.length; i++) {
            tokenTypes[i] = tokens[i].tokenType;
            tokenAddresses[i] = tokens[i].tokenAddress;
        }        
    }

    /**
     * @dev get ERC20 token info
     */
    function getERC20Tokens(uint256 gratiaId) public view gratiaExists(gratiaId) returns (address[] memory addresses, uint256[] memory tokenBalances) {
        Token[] memory tokens = _insideTokens[gratiaId];
        (uint256 erc20Len,,) = getInsideTokensCount(gratiaId);
        
        tokenBalances = new uint256[](erc20Len);
        addresses = new address[](erc20Len);
        uint256 j;

        for (uint256 i; i < tokens.length; i++) {
            Token memory token = tokens[i];
            if (token.tokenType == TOKEN_TYPE_ERC20) {
                addresses[j] = token.tokenAddress;
                tokenBalances[j] = _insideERC20TokenBalances[gratiaId][token.tokenAddress];
                j++;
            }
        }        
    }

    /**
     * @dev get ERC721 token info
     */
    function getERC721Tokens(uint256 gratiaId) public view gratiaExists(gratiaId) returns (address[] memory addresses, uint256[] memory tokenBalances) {
        Token[] memory tokens = _insideTokens[gratiaId];
        (,uint256 erc721Len,) = getInsideTokensCount(gratiaId);
        
        tokenBalances = new uint256[](erc721Len);
        addresses = new address[](erc721Len);
        uint256 j;

        for (uint256 i; i < tokens.length; i++) {
            Token memory token = tokens[i];
            if (token.tokenType == TOKEN_TYPE_ERC721) {
                addresses[j] = token.tokenAddress;
                tokenBalances[j] = _insideTokenIds[gratiaId][token.tokenAddress].length;
                j++;
            }
        }
    }

    /**
     * @dev get ERC721 or ERC1155 ids
     */
    function getERC721OrERC1155Ids(uint256 gratiaId, address insideToken) public view gratiaExists(gratiaId) returns (uint256[] memory) {
        return _insideTokenIds[gratiaId][insideToken];
    }

    /**
     * @dev get ERC1155 token addresses info
     */
    function getERC1155Tokens(uint256 gratiaId) public view gratiaExists(gratiaId) returns (address[] memory addresses) {
        Token[] memory tokens = _insideTokens[gratiaId];
        (,,uint256 erc1155Len) = getInsideTokensCount(gratiaId);
        
        addresses = new address[](erc1155Len);
        uint256 j;

        for (uint256 i; i < tokens.length; i++) {
            Token memory token = tokens[i];
            if (token.tokenType == TOKEN_TYPE_ERC1155) {
                addresses[j] = token.tokenAddress;
                j++;
            }
        }
    }

    /**
     * @dev get ERC1155 token balances by ids
     */
    function getERC1155TokenBalances(uint256 gratiaId, address insideToken, uint256[] memory tokenIds) public view gratiaExists(gratiaId) returns (uint256[] memory tokenBalances) {
        tokenBalances = new uint256[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            tokenBalances[i] = _insideERC1155TokenBalances[gratiaId][insideToken][tokenIds[i]];
        }
    }
    

    // Write functions

    function setSwap(address swap) external onlyOwner {
        _swap = ISwap(swap);
    }

    /**
     * @dev lock gratia.
     */
    function lockGratia(uint256 gratiaId, uint256 timeInSeconds) external onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        _lockedTimestamp[gratiaId] = block.timestamp + timeInSeconds;
        
        emit LockedGratia(gratiaId, msg.sender, block.timestamp, block.timestamp + timeInSeconds);
    }

    /**
     * @dev deposit erc20 tokens into gratia.
     */
    function depositErc20IntoGratia(uint256 gratiaId, address[] memory tokens, uint256[] memory amounts) external gratiaExists(gratiaId){
        require(tokens.length > 0 && tokens.length == amounts.length);

        for (uint256 i; i < tokens.length; i++) {
            require(tokens[i] != address(0));
            IERC20 iToken = IERC20(tokens[i]);

            uint256 prevBalance = iToken.balanceOf(address(this));
            iToken.transferFrom(msg.sender, address(this),amounts[i]);
            
            uint256 receivedAmount = iToken.balanceOf(address(this)) - prevBalance;

            _increaseInsideTokenBalance(gratiaId, TOKEN_TYPE_ERC20, tokens[i], receivedAmount);

            emit DepositedErc20IntoGratia(gratiaId, msg.sender, tokens[i], receivedAmount);
            
        }
    }

    /**
     * @dev withdraw erc20 tokens from gratia.
     */
    function withdrawErc20FromGratia(uint256 gratiaId, address[] memory tokens, uint256[] memory amounts, address to) 
    public onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        require(tokens.length > 0 && tokens.length == amounts.length);

        for (uint256 i; i < tokens.length; i++) {
            require(tokens[i] != address(0));
            IERC20 iToken = IERC20(tokens[i]);

            iToken.transfer(to, amounts[i]);

            _decreaseInsideTokenBalance(gratiaId, TOKEN_TYPE_ERC20, tokens[i], amounts[i]);
            
            emit WithdrewErc20FromGratia(gratiaId, msg.sender, tokens[i], amounts[i], to);
        }
    }

    /**
     * @dev send erc20 tokens from my gratia to another gratia.
     */
    function sendErc20(uint256 fromGratiaId, address[] memory tokens, uint256[] memory amounts, uint256 toGratiaId) 
    public onlyGratiaOwner(fromGratiaId) unlocked(fromGratiaId) {
        require(fromGratiaId != toGratiaId);
        require(tokens.length > 0 && tokens.length == amounts.length);

        for (uint256 i; i < tokens.length; i++) {
            require(tokens[i] != address(0));
            require(_gratia.exists(toGratiaId));

            _decreaseInsideTokenBalance(fromGratiaId, TOKEN_TYPE_ERC20, tokens[i], amounts[i]);
            _increaseInsideTokenBalance(toGratiaId, TOKEN_TYPE_ERC20, tokens[i], amounts[i]);

            emit SentErc20(fromGratiaId, msg.sender, tokens[i], amounts[i], toGratiaId);
        }
    }

    /**
     * @dev deposit erc721 tokens into gratia.
     */
    function depositErc721IntoGratia(uint256 gratiaId, address token, uint256[] memory tokenIds) external gratiaExists(gratiaId) {
        require(token != address(0), "Deposit ERC721: Zero address of token");

        for (uint256 i; i < tokenIds.length; i++) {
            require(token != address(this) || (token == address(this) && gratiaId != tokenIds[i]));
            
            IERC721 iToken = IERC721(token);
            
            iToken.safeTransferFrom(msg.sender, address(this), tokenIds[i]);

            _putInsideTokenId(gratiaId, token, tokenIds[i]);

            emit DepositedErc721IntoGratia(gratiaId, msg.sender, token, tokenIds[i]);
        }
        _increaseInsideTokenBalance(gratiaId, TOKEN_TYPE_ERC721, token, tokenIds.length);
    }

    /**
     * @dev withdraw erc721 token from gratia.
     */
    function withdrawErc721FromGratia(uint256 gratiaId, address token, uint256[] memory tokenIds, address to) 
    public onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        require(token != address(0));
        IERC721 iToken = IERC721(token);

        for (uint256 i; i < tokenIds.length; i++) {
            address tokenOwner = iToken.ownerOf(tokenIds[i]);

            require(tokenOwner == address(this));

            iToken.safeTransferFrom(tokenOwner, to, tokenIds[i]);

            _popInsideTokenId(gratiaId, token, tokenIds[i]);

            emit WithdrewErc721FromGratia(gratiaId, msg.sender, token, tokenIds[i], to);
        }
        _decreaseInsideTokenBalance(gratiaId, TOKEN_TYPE_ERC721, token, tokenIds.length);
    }

    /**
     * @dev send erc721 tokens from my gratia to another gratia.
     */
    function sendErc721(uint256 fromGratiaId, address token, uint256[] memory tokenIds, uint256 toGratiaId) 
    public onlyGratiaOwner(fromGratiaId) unlocked(fromGratiaId) {
        require(fromGratiaId != toGratiaId);
        require(token != address(0));
        require(_gratia.exists(toGratiaId));

        for (uint256 i; i < tokenIds.length; i++) {
            _popInsideTokenId(fromGratiaId, token, tokenIds[i]);

            _putInsideTokenId(toGratiaId, token, tokenIds[i]);

            emit SentErc721(fromGratiaId, msg.sender, token, tokenIds[i], toGratiaId);
        }
        _increaseInsideTokenBalance(toGratiaId, TOKEN_TYPE_ERC721, token, tokenIds.length);
        _decreaseInsideTokenBalance(fromGratiaId, TOKEN_TYPE_ERC721, token, tokenIds.length);
    }

    /**
     * @dev deposit erc1155 token into gratia.
     */
    function depositErc1155IntoGratia(uint256 gratiaId, address token, uint256[] memory tokenIds, uint256[] memory amounts) external gratiaExists(gratiaId){
        require(token != address(0));
        IERC1155 iToken = IERC1155(token);

        for (uint256 i; i < tokenIds.length; i++) {
            iToken.safeTransferFrom(msg.sender, address(this), tokenIds[i], amounts[i], bytes(""));

            _putInsideTokenIdForERC1155(gratiaId, token, tokenIds[i]);

            _increaseInsideERC1155TokenBalance(gratiaId, TOKEN_TYPE_ERC1155, token, tokenIds[i], amounts[i]);

            emit DepositedErc1155IntoGratia(gratiaId, msg.sender, token, tokenIds[i], amounts[i]);
        }
    }

    /**
     * @dev withdraw erc1155 token from gratia.
     */
    function withdrawErc1155FromGratia(uint256 gratiaId, address token, uint256[] memory tokenIds, uint256[] memory amounts, address to) 
    public onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        require(token != address(0));
        IERC1155 iToken = IERC1155(token);

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            iToken.safeTransferFrom(address(this), to, tokenId, amount, bytes(""));

            _decreaseInsideERC1155TokenBalance(gratiaId, token, tokenId, amount);

            _popInsideTokenIdForERC1155(gratiaId, token, tokenId);

            _popERC1155FromGratia(gratiaId, token, tokenId);
            
            emit WithdrewErc1155FromGratia(gratiaId, msg.sender, token, tokenId, amount, to);
        }
    }

    /**
     * @dev send erc1155 token from my gratia to another gratia.
     */
    function sendErc1155(uint256 fromGratiaId, address token, uint256[] memory tokenIds, uint256[] memory amounts, uint256 toGratiaId) 
    public onlyGratiaOwner(fromGratiaId) unlocked(fromGratiaId) {
        require(fromGratiaId != toGratiaId);
        require(token != address(0));
        require(_gratia.exists(toGratiaId));

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amounts[i];

            _decreaseInsideERC1155TokenBalance(fromGratiaId, token, tokenId, amount);

            _increaseInsideERC1155TokenBalance(toGratiaId, TOKEN_TYPE_ERC1155, token, tokenId, amount);

            _popInsideTokenIdForERC1155(fromGratiaId, token, tokenId);

            _putInsideTokenIdForERC1155(toGratiaId, token, tokenId);

            _popERC1155FromGratia(fromGratiaId, token, tokenId);
            
            emit SentErc1155(fromGratiaId, msg.sender, token, tokenId, amount, toGratiaId);
        }
    }

    /**
     * @dev withdraw all of inside tokens into specific address.
     */
    function withdrawAll(uint256 gratiaId, address to) external gratiaExists(gratiaId) {
        require(to != address(0));
        
        (address[] memory erc20Addresses, uint256[] memory erc20Balances) = getERC20Tokens(gratiaId);
        
        withdrawErc20FromGratia(gratiaId, erc20Addresses, erc20Balances, to);

        (address[] memory erc721Addresses, ) = getERC721Tokens(gratiaId);
        for (uint256 a; a < erc721Addresses.length; a++) {
            uint256[] memory ids = getERC721OrERC1155Ids(gratiaId, erc721Addresses[a]);
            
            withdrawErc721FromGratia(gratiaId, erc721Addresses[a], ids, to);
        }

        address[] memory erc1155Addresses = getERC1155Tokens(gratiaId);
        for (uint256 a; a < erc1155Addresses.length; a++) {
            uint256[] memory ids = getERC721OrERC1155Ids(gratiaId, erc1155Addresses[a]);
            uint256[] memory tokenBalances = getERC1155TokenBalances(gratiaId, erc1155Addresses[a], ids);
            
            withdrawErc1155FromGratia(gratiaId, erc1155Addresses[a], ids, tokenBalances, to);
        }
    }

    /**
     * @dev send all of inside tokens to specific gratia.
     */
    function sendAll(uint256 fromGratiaId, uint256 toGratiaId) external gratiaExists(fromGratiaId) gratiaExists(toGratiaId) {
        (address[] memory erc20Addresses, uint256[] memory erc20Balances) = getERC20Tokens(fromGratiaId);
        sendErc20(fromGratiaId, erc20Addresses, erc20Balances, toGratiaId);

        (address[] memory erc721Addresses,) = getERC721Tokens(fromGratiaId);
        
        for (uint256 a; a < erc721Addresses.length; a++) {
            uint256[] memory ids = getERC721OrERC1155Ids(fromGratiaId, erc721Addresses[a]);
            
            sendErc721(fromGratiaId, erc721Addresses[a], ids, toGratiaId);
        }

        address[] memory erc1155Addresses = getERC1155Tokens(fromGratiaId);
        for (uint256 a; a < erc1155Addresses.length; a++) {
            uint256[] memory ids = getERC721OrERC1155Ids(fromGratiaId, erc1155Addresses[a]);
            uint256[] memory tokenBalances = getERC1155TokenBalances(fromGratiaId, erc1155Addresses[a], ids);
            
            sendErc1155(fromGratiaId, erc1155Addresses[a], ids, tokenBalances, toGratiaId);
        }
    }
    
    /**
     * @dev external function to increase token balance of gratia
     */
    function increaseInsideTokenBalance(uint256 gratiaId, uint8 tokenType, address token, uint256 amount) external gratiaExists(gratiaId) {
        require(msg.sender != address(0));
        require(msg.sender == address(_gratia));

        _increaseInsideTokenBalance(gratiaId, tokenType, token, amount);
    }

    function swapErc20(uint256 gratiaId, address inToken, uint256 inAmount, address outToken, uint8 router, address to) 
    external onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        require(address(_swap) != address(0));
        require(_insideERC20TokenBalances[gratiaId][inToken] >= inAmount);

        IERC20(inToken).approve(address(_swap), inAmount);

        _swap.swapErc20(gratiaId, inToken, inAmount, outToken, router, to);
        
        emit SwapedErc20(msg.sender, gratiaId, inToken, inAmount, outToken, to);

        _decreaseInsideTokenBalance(gratiaId, TOKEN_TYPE_ERC20, inToken, inAmount);
    }

    function swapErc721(uint256 gratiaId, address inToken, uint256 inId, address outToken, uint8 router, address to) 
    external onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        require(address(_swap) != address(0));
        require(existsId(gratiaId, inToken, inId));
        
        IERC721(inToken).approve(address(_swap), inId);

        _swap.swapErc721(gratiaId, inToken, inId, outToken, router, to);
        
        emit SwapedErc721(msg.sender, gratiaId, inToken, inId, outToken, to);

        _popInsideTokenId(gratiaId, inToken, inId);
    }

    function swapErc1155(uint256 gratiaId, address inToken, uint256 inId, uint256 inAmount, address outToken, uint256 outId, uint8 router, address to) 
    external onlyGratiaOwner(gratiaId) unlocked(gratiaId) {
        require(address(_swap) != address(0));
        require(existsId(gratiaId, inToken, inId));
        require(_insideERC1155TokenBalances[gratiaId][inToken][inId] >= inAmount);

        IERC1155(inToken).setApprovalForAll(address(_swap), true);

        _swap.swapErc1155(gratiaId, inToken, inId, inAmount, outToken, outId, router, to);
        
        emit SwapedErc1155(msg.sender, gratiaId, inToken, inId, inAmount, outToken, outId, to);

        _decreaseInsideERC1155TokenBalance(gratiaId, inToken, inId, inAmount);

        _popInsideTokenIdForERC1155(gratiaId, inToken, inId);

        _popERC1155FromGratia(gratiaId, inToken, inId);
    }

    function _popERC1155FromGratia(uint256 gratiaId, address token, uint256 tokenId) private {
        uint256[] memory ids = _insideTokenIds[gratiaId][token];
        
        if (_insideERC1155TokenBalances[gratiaId][token][tokenId] == 0 && ids.length == 0) {
            
            delete _insideERC1155TokenBalances[gratiaId][token][tokenId];
            delete _insideTokenIds[gratiaId][token];
            
            _popTokenFromGratia(gratiaId, TOKEN_TYPE_ERC1155, token);
        }
    }
    
    /**
     * @dev private function to increase token balance of gratia
     */
    function _increaseInsideTokenBalance(uint256 gratiaId, uint8 tokenType, address token, uint256 amount) private {
        _insideERC20TokenBalances[gratiaId][token] += amount;
        _putTokenIntoGratia(gratiaId, tokenType, token);
    }

    /**
     * @dev private function to increase erc1155 token balance of gratia
     */
    function _increaseInsideERC1155TokenBalance(uint256 gratiaId, uint8 tokenType, address token, uint256 tokenId, uint256 amount) private {
        _insideERC1155TokenBalances[gratiaId][token][tokenId] += amount;
        _putTokenIntoGratia(gratiaId, tokenType, token);
    }

    /**
     * @dev private function to decrease token balance of gratia
     */
    function _decreaseInsideTokenBalance(uint256 gratiaId, uint8 tokenType, address token, uint256 amount) private {
        require(_insideERC20TokenBalances[gratiaId][token] >= amount);
        
        _insideERC20TokenBalances[gratiaId][token] -= amount;
        
        if (_insideERC20TokenBalances[gratiaId][token] == 0) {
            delete _insideERC20TokenBalances[gratiaId][token];
            _popTokenFromGratia(gratiaId, tokenType, token);
        }
    }

    /**
     * @dev private function to decrease erc1155 token balance of gratia
     */
    function _decreaseInsideERC1155TokenBalance(uint256 gratiaId, address token, uint256 tokenId, uint256 amount) private {
        require(_insideERC1155TokenBalances[gratiaId][token][tokenId] >= amount);
        
        _insideERC1155TokenBalances[gratiaId][token][tokenId] -= amount;
    }

    /**
     * @dev private function to put a token id to gratia
     */
    function _putInsideTokenId(uint256 gratiaId, address token, uint256 tokenId) private {
        uint256[] storage ids = _insideTokenIds[gratiaId][token];
        ids.push(tokenId);
    }

    /**
     * @dev private function to put a token id to gratia in ERC1155
     */
    function _putInsideTokenIdForERC1155(uint256 gratiaId, address token, uint256 tokenId) private {
        uint256[] storage ids = _insideTokenIds[gratiaId][token];
        bool isExist;
        
        for (uint256 i; i < ids.length; i++) {
            if (ids[i] == tokenId) {
                isExist = true;
            }
        }
        
        if (!isExist) {
            ids.push(tokenId);
        }
    }

    /**
     * @dev private function to pop a token id from gratia
     */
    function _popInsideTokenId(uint256 gratiaId, address token, uint256 tokenId) private {
        uint256[] storage ids = _insideTokenIds[gratiaId][token];
        
        for (uint256 i; i < ids.length; i++) {
            if (ids[i] == tokenId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
            }
        }

        if (ids.length == 0) {
            delete _insideTokenIds[gratiaId][token];
        }
    }

    /**
     * @dev private function to pop a token id from gratia in ERC1155
     */
    function _popInsideTokenIdForERC1155(uint256 gratiaId, address token, uint256 tokenId) private {
        uint256 tokenBalance = _insideERC1155TokenBalances[gratiaId][token][tokenId];
        
        if (tokenBalance <= 0) {
            delete _insideERC1155TokenBalances[gratiaId][token][tokenId];
            _popInsideTokenId(gratiaId, token, tokenId);
        }
    }

    /**
     * @dev put token(type, address) to gratia
     */
    function _putTokenIntoGratia(uint256 gratiaId, uint8 tokenType, address tokenAddress) private {
        Token[] storage tokens = _insideTokens[gratiaId];
        bool exists = false;
        
        for (uint256 i; i < tokens.length; i++) {
            if (
                tokens[i].tokenType == tokenType &&
                tokens[i].tokenAddress == tokenAddress
            ) {
                exists = true;
                break;
            }
        }

        if (!exists) {
            tokens.push(Token({
                tokenType: tokenType,
                tokenAddress: tokenAddress
            }));
        }
    }

    /**
     * @dev pop token(type, address) from gratia
     */
    function _popTokenFromGratia(uint256 gratiaId, uint8 tokenType, address tokenAddress) private {
        Token[] storage tokens = _insideTokens[gratiaId];
        
        for (uint256 i; i < tokens.length; i++) {
            if (
                tokens[i].tokenType == tokenType &&
                tokens[i].tokenAddress == tokenAddress
            ) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }

        if (tokens.length == 0) {
            delete _insideTokens[gratiaId];
        }
    }
   
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure override returns(bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata) external pure override returns(bytes4) {
        return 0xbc197c81;
    }
}