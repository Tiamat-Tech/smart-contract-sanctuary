//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./AbstractAccessControl.sol";
import "../interfaces/Club.sol";
import "../interfaces/DSO.sol";
import "../interfaces/User.sol";

import "hardhat/console.sol";

contract DSOFactory is
    ERC721URIStorage,
    AbstractAccessControl,
    Ownable,
    Pausable
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    DSO[] private dsos;

    // tracks offline ownership of DSOs
    mapping(uint256 => address) private dsoToOwner;
    // userDSOCount is needed for getDSOsByUser as we need an array with static size to iterate through
    mapping(uint256 => uint256) private userDSOCount;
    // clubDSOCount is needed for getDSOsByClub as we need an array with static size to iterate through
    mapping(uint256 => uint256) private clubDSOCount;

    bytes32 public constant CREATOR_ROLE = keccak256("CREATORS");

    event NewDSO(address creator, uint256 tokenId);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        grantCreatorRole(msg.sender);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev This function needs to be overriden as it's declared in ERC721 and AccessControl.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice create a dso with an incremental id.
     */
    function createDSO(
        uint64 startDate,
        uint64 endDate,
        uint32 row,
        uint32 column,
        string memory section,
        string memory tokenURI
    ) public isWhitelistedCreator(msg.sender) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        dsos.push(DSO(newItemId, startDate, endDate, row, column, section));
        emit NewDSO(msg.sender, newItemId);
    }

    /**
     * @notice allows owner to grant creator role
     * @param creator the creator address from whom you want to grant the role.
     */
    function grantCreatorRole(address creator) public onlyAdmin(msg.sender) {
        _setupRole(CREATOR_ROLE, creator);
    }

    /**
     * @notice allows owner to revoke creator role
     * @dev msg.sender needs have default ADMIN role. It's set in the constructor.
     * @param revokedCreator the creator address from whom you want to revoke the role.
     */
    function revokeCreatorRole(address revokedCreator)
        public
        onlyAdmin(msg.sender)
    {
        revokeRole(CREATOR_ROLE, revokedCreator);
    }

    /**
     * @dev Require whitelisted creator when requiresWhitelistedCreator is true.
     */
    modifier isWhitelistedCreator(address creator) {
        require(
            hasRole(CREATOR_ROLE, creator),
            "DSOFactory: creator is not whitelisted."
        );
        _;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        super.transferFrom(from, to, tokenId);
        dsoToOwner[tokenId] = to;
    }

    function getDSOsByOwner(address owner)
        external
        view
        returns (DSO[] memory)
    {
        DSO[] memory result = new DSO[](ERC721.balanceOf(owner));
        uint256 counter = 0;
        for (uint256 i = 0; i < dsos.length; i++) {
            if (ERC721.ownerOf(dsos[i].id) == owner) {
                result[counter] = dsos[i];
                counter++;
            }
        }
        return result;
    }

    function getAllDSOs() external view returns (DSO[] memory) {
        return dsos;
    }

    function getDSOById(uint256 dsoId) external view returns (DSO memory) {
        DSO memory result;
        for (uint256 i = 0; i < dsos.length; i++) {
            if (dsos[i].id == dsoId) {
                result = dsos[i];
            }
        }
        return result;
    }
}