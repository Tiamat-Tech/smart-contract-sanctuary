// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

import '../abstracts/Pausable.sol';
import '../abstracts/ExternallyCallable.sol';

import '../interfaces/IStakeToken.sol';
import '../interfaces/IVCAuction.sol';
import '../interfaces/IStakeManager.sol';

contract StakeToken is
    IStakeToken,
    Manageable,
    Migrateable,
    ExternallyCallable,
    Pausable,
    ERC721EnumerableUpgradeable
{
    using AddressUpgradeable for address;

    /** Structs / Vars ------------------------------------------------------------------- */
    struct Contracts {
        IVCAuction vcAuction;
        IStakeManager stakeManager;
    }

    Contracts internal contracts;

    /** Functions ------------------------------------------------------------------------ */

    /** @dev mint
        Description: Mint NFT stake
        @param staker {address}
        @param id {uint256} - Corresponds to stake ID 
     */
    function mint(address staker, uint256 id) external override onlyExternalCaller {
        _safeMint(staker, id);
    }

    // /** burn
    //     Description: Mint NFT stake
    //     @param staker {address}
    //     @param id {uint256} - Corresponds to stake ID
    //  */
    // function burn(address staker, uint256 id) external override onlyExternalCaller {
    //     require(ownerOf(id) == staker, 'Not owner of stake.');
    //     _burn(id);
    // }

    /** @dev is owner of
        Descritpion: Checks if address is owner of nft
        @param account { address }
        @param tokenId { uint256 }
     */
    function isOwnerOf(address account, uint256 tokenId) external view override returns (bool) {
        if (_exists(tokenId)) {
            return (ownerOf(tokenId) == account);
        }
        return false;
    }

    /** @dev name */
    function name() public view virtual override returns (string memory) {
        return 'Axion Stake NFT';
    }

    /** @dev Transfer from
        Description: Transfers an NFT from a v3 stake to another staker
            Rebalances the users VC balance of shares as well as changes owner of stake
        @param from {address}
        @param to {address}
        @param tokenId {uint256}
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) onlyMigrator pausable {
        // require(false, 'STAKE TOKEN: transfer is disabled.');
        require(!to.isContract(), 'STAKE TOKEN: transfer to contract is not supported.');
        super.transferFrom(from, to, tokenId);

        StakeData1e18 memory stake = contracts.stakeManager.getStake(tokenId);
        require(
            stake.status != StakeStatus.Withdrawn,
            'TOKEN: Stake is withdrawn and can not be transferred'
        );

        contracts.vcAuction.transferSharesAndRebalance(from, to, stake.shares);
    }

    function approve(address to, uint256 tokenId)
        public
        virtual
        override(ERC721Upgradeable, IERC721Upgradeable)
        pausable
    {
        // require(false, 'STAKE TOKEN: approve is disabled.');

        super.approve(to, tokenId);
    }

    /** Getters ------------------------------------------------------------------------ */
    /** @dev Get STake IDS of
        Description: Get NFT of user
        @param  account {address}

        @return {uint256[]}
     */
    function getStakeIdsOf(address account) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(account);
        uint256[] memory stakeIds = new uint256[](balance);

        for (uint8 i = 0; i < balance; i++) {
            stakeIds[i] = tokenOfOwnerByIndex(account, i);
        }

        return stakeIds;
    }

    /** @dev supportsInterface
        Description: Abstract function for IERC721
        @param interfaceId bytes4
        
        @return {bool}
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC721EnumerableUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /** Initialize ------------------------------------------------------------------------ */

    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _minter,
        address _burner,
        address _vcAuction,
        address _stakeManager
    ) public onlyMigrator {
        _setupRole(EXTERNAL_CALLER_ROLE, _minter);
        _setupRole(EXTERNAL_CALLER_ROLE, _burner);

        contracts.vcAuction = IVCAuction(_vcAuction);
        contracts.stakeManager = IStakeManager(_stakeManager);
    }
}