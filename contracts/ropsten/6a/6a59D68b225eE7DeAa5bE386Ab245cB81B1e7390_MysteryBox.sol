// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./UintArrayLib.sol";

contract MysteryBox is ERC1155, AccessControl {
    using Counters for Counters.Counter;
    using UintArrayLib for uint256[];

    string public constant name = "PlanetSandbox Mystery Box";

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIds;

    // box id => token uri
    mapping(uint256 => string) private _tokenUri;
    // box id => reward address
    mapping(uint256 => address) private _rewardAddresses;
    // box id => reward ids
    mapping(uint256 => uint256[]) private _rewards;
    // reward address => reward id => box id
    mapping(address => mapping(uint256 => uint256)) private _rewardToBoxId;
    // box id => timestamp
    mapping(uint256 => uint256) private _unboxDays;

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Error: Admin role required");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Error: Minter role required");
        _;
    }

    constructor(address multiSigAccount) ERC1155("") {
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, multiSigAccount);
    }

    function mint(
        address to,
        uint256 amount,
        string memory tokenUri,
        bytes memory data,
        uint256 unboxDay,
        address rewardAddress
    ) external onlyMinter returns (uint256) {
        require(to != address(0), "Error: Mint to the zero address");
        require(unboxDay > block.timestamp, "Error: Unbox day must be future date");

        _tokenIds.increment();

        uint256 newBoxId = _tokenIds.current();

        _mint(to, newBoxId, amount, data);
        _tokenUri[newBoxId] = tokenUri;

        _rewardAddresses[newBoxId] = rewardAddress;

        _unboxDays[newBoxId] = unboxDay;

        return newBoxId;
    }

    function setUnboxDay(uint256 boxId, uint256 unboxDay) external onlyMinter {
        require(unboxDay > block.timestamp, "Error: Unbox day must be future date");
        _unboxDays[boxId] = unboxDay;
    }

    function addRewards(uint256 boxId, uint256[] memory rewardIds) external onlyMinter {
        require(boxId <= _tokenIds.current(), "Error: No box id");

        address rewardAddress = _rewardAddresses[boxId];

        for (uint256 i = 0; i < rewardIds.length; i++) {
            IERC721(rewardAddress).transferFrom(_msgSender(), address(this), rewardIds[i]);

            _rewards[boxId].push(rewardIds[i]);
            _rewardToBoxId[rewardAddress][rewardIds[i]] = boxId;
        }
    }

    function addRewards(
        uint256 boxId,
        uint256 rewardIdStart,
        uint256 rewardIdEnd
    ) external onlyMinter {
        require(boxId <= _tokenIds.current(), "Error: No box id");

        address rewardAddress = _rewardAddresses[boxId];

        for (uint256 rewardId = rewardIdStart; rewardId <= rewardIdEnd; rewardId++) {
            IERC721(rewardAddress).transferFrom(_msgSender(), address(this), rewardId);

            _rewards[boxId].push(rewardId);
            _rewardToBoxId[rewardAddress][rewardId] = boxId;
        }
    }

    function getRewards(uint256 boxId) external view returns (address rewardAddress, uint256[] memory ids) {
        require(boxId <= _tokenIds.current(), "Error: No box id");

        return (_rewardAddresses[boxId], _rewards[boxId]);
    }

    function burn(uint256 id, uint256 amount) external {
        _burn(_msgSender(), id, amount);
    }

    function openBox(uint256 boxId) external returns (uint256) {
        require(balanceOf(_msgSender(), boxId) > 0, "Error: No box");
        require(_unboxDays[boxId] <= block.timestamp, "Error: The unboxing date hasn't come yet");

        uint256 rewardIndex = uint256(blockhash(block.number + block.timestamp)) % _rewards[boxId].length;
        _rewards[boxId].shuffle();

        uint256 rewardId = _rewards[boxId][rewardIndex];

        IERC721(_rewardAddresses[boxId]).transferFrom(address(this), _msgSender(), rewardId);

        _rewards[boxId].removeAt(rewardIndex);

        _burn(_msgSender(), boxId, 1);

        return rewardId;
    }

    function uri(uint256 id) public view override returns (string memory) {
        return _tokenUri[id];
    }

    function currentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function withdrawERC20(address token) external onlyAdmin {
        require(IERC20(token).transfer(_msgSender(), IERC20(token).balanceOf(address(this))), "Transfer failed");
    }

    function withdrawERC721(address token, uint256[] memory ids) external onlyAdmin {
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721(token).transferFrom(address(this), _msgSender(), ids[i]);

            uint256 boxId = _rewardToBoxId[token][ids[i]];

            _rewards[boxId].remove(ids[i]);
            delete _rewardToBoxId[token][ids[i]];
        }
    }

    function withdrawERC1155(
        address token,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyAdmin {
        IERC1155(token).safeBatchTransferFrom(address(this), _msgSender(), ids, amounts, data);
    }
}