pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./BlackholePrevention.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MirandusVOX is
    ERC721,
    ERC1155Holder,
    Ownable,
    BlackholePrevention,
    ReentrancyGuard
{
    using Address for address;
    using SafeMath for uint256;

    uint256 public tokenId;
    address public erc1155Token;
    uint256 balance;
    uint256 public erc1155TokenId;
    uint256 private _totalSupply = 8888;
    bool public isPause;

    constructor(
        address _erc1155Token,
        uint256 _erc1155TokenId,
        bool _isPause
    ) ERC721("Token", "tok") {
        erc1155Token = _erc1155Token;
        erc1155TokenId = 146321417776003539289251081195660330926080;
        isPause = _isPause;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC1155Receiver)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function getBalance() public view returns (uint256 _balance) {
        _balance = IERC1155(erc1155Token).balanceOf(
            address(this),
            erc1155TokenId
        );
    }

    function getTokenLeft() public view returns (uint256) {
        return _totalSupply - tokenId;
    }

    function setTokenERC1155(address _erc1155Token) public onlyOwner {
        erc1155Token = _erc1155Token;
    }

    function setTotalSupply(uint256 __totalSupply) public onlyOwner {
        _totalSupply = __totalSupply;
    }

    function setIsPause(bool _isPause) public onlyOwner {
        isPause = _isPause;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        require(tokenId < _totalSupply, "over limit supply");
        require(value <= _totalSupply - tokenId, "over limit value");
        require(isPause, "!isPause");
        uint256 balanceAter = IERC1155(erc1155Token).balanceOf(
            address(this),
            erc1155TokenId
        );
        if (balance + value == balanceAter) {
            for (uint256 i = 0; i < value; i++) {
                _safeMint(from, tokenId);
                tokenId++;
            }
        }
        balance = IERC1155(erc1155Token).balanceOf(
            address(this),
            erc1155TokenId
        );
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] memory id,
        uint256[] memory value,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        require(tokenId < _totalSupply, "over limit supply");
        require(isPause, "!isPause");
        uint256 totalValue;
        uint256 balanceAter = IERC1155(erc1155Token).balanceOf(
            address(this),
            erc1155TokenId
        );
        for (uint256 i = 0; i < id.length; i++) {
            if (id[i] == erc1155TokenId) {
                totalValue += value[i];
            }
        }
        require(totalValue <= _totalSupply - tokenId, "over limit value");
        if (balance + totalValue == balanceAter) {
            for (uint256 i = 0; i < totalValue; i++) {
                _safeMint(from, tokenId);
                tokenId++;
            }
        }
        balance = IERC1155(erc1155Token).balanceOf(
            address(this),
            erc1155TokenId
        );
        return this.onERC1155BatchReceived.selector;
    }
  
    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        onlyOwner
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual onlyOwner {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 _tokenId
    ) external virtual onlyOwner {
        _withdrawERC721(receiver, tokenAddress, _tokenId);
    }

    function withdrawERC1155(
        address token,
        address _to,
        uint256 _erc1155TokenId,
        uint256 _amount,
        bytes memory data
    ) external virtual onlyOwner {
        _withdrawERC1155(token, _to, _erc1155TokenId, _amount, data);
    }
}