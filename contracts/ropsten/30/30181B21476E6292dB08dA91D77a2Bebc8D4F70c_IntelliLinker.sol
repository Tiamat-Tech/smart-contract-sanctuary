// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../interfaces/ERC721Spec.sol";
import "./IntelligentNFTv2.sol";

/**
 * @title Intelligent Token Linker (iNFT Linker)
 *
 * @notice iNFT Linker is a helper smart contract responsible for managing iNFTs.
 *      It creates and destroys iNFTs, determines iNFT creation price and destruction fee.
 *
 * @dev Known limitations (to be resolved in the future releases):
 *      - doesn't check AI Personality / target NFT compatibility: any personality
 *        can be linked to any NFT (NFT contract must be whitelisted)
 *      - doesn't support unlinking + linking in a single transaction
 *      - doesn't support AI Personality smart contract upgrades: in case when new
 *        AI Personality contract is deployed, new iNFT Linker should also be deployed
 *
 * @author Basil Gorin
 */
contract IntelliLinker is AccessControl {
	/**
	 * @dev iNFT Linker locks/unlocks ALI tokens defined by `aliContract` to mint/burn iNFT
	 */
	address public immutable aliContract;

	/**
	 * @dev iNFT Linker locks/unlocks AI Personality defined by `personalityContract` to mint/burn iNFT
	 */
	address public immutable personalityContract;

	/**
	 * @dev iNFT Linker mints/burns iNFTs defined by `iNftContract`
	 */
	address public immutable iNftContract;

	/**
	 * @dev iNFTs may get created with the ALI tokens bound to them,
	 *      linking fee may get charged when creating an iNFT
	 *
	 * @dev Linking price, how much ALI tokens is charged upon iNFT creation;
	 *      `linkPrice - linkFee` is locked within the iNFT created
	 */
	uint96 public linkPrice = 2_000 ether; // we use "ether" suffix instead of "e18"

	/**
	 * @dev iNFTs may get created with the ALI tokens bound to them,
	 *      linking fee may get charged when creating an iNFT
	 *
	 * @dev Linking fee, how much ALI tokens is sent into treasury `feeDestination`
	 *      upon iNFT creation
	 *
	 * @dev Both `linkFee` and `feeDestination` must be set for the fee to be charged;
	 *      both `linkFee` and `feeDestination` can be either set or unset
	 */
	uint96 public linkFee;

	/**
	 * @dev iNFTs may get created with the ALI tokens bound to them,
	 *      linking fee may get charged when creating an iNFT
	 *
	 * @dev Treasury `feeDestination` is an address to send linking fee to upon iNFT creation
	 *
	 * @dev Both `linkFee` and `feeDestination` must be set for the fee to be charged;
	 *      both `linkFee` and `feeDestination` can be either set or unset
	 */
	address public feeDestination;

	/**
	/**
	 * @dev Next iNFT ID to mint; initially this is the first "free" ID which can be minted;
	 *      at any point in time this should point to a free, mintable ID for iNFT
	 *
	 * @dev iNFT ID space up to 0xFFFF_FFFF (uint32 max) is reserved for the sales
	 */
	uint256 public nextId = 0x1_0000_0000;

	/**
	 * @dev Target NFT Contracts allowed iNFT to be linked to;
	 *      is not taken into account if FEATURE_ALLOW_ANY_NFT_CONTRACT is enabled
	 */
	mapping(address => bool) public whitelistedTargetContracts;

	/**
	 * @notice Allows linker to link (mint) iNFT bound to any target NFT contract,
	 *      independently whether it was previously whitelisted or not
	 * @dev Feature FEATURE_ALLOW_ANY_NFT_CONTRACT allows linking (minting) iNFTs
	 *      bound to any target NFT contract, without a check if it's whitelisted in
	 *      `whitelistedTargetContracts` or not
	 */
	uint32 public constant FEATURE_ALLOW_ANY_NFT_CONTRACT = 0x0000_0001;

	/**
	 * @notice Link price manager is responsible for updating linking price
	 *
	 * @dev Role ROLE_LINK_PRICE_MANAGER allows `updateLinkPrice` execution,
	 *      and `linkPrice` modification
	 */
	uint32 public constant ROLE_LINK_PRICE_MANAGER = 0x0001_0000;

	/**
	 * @notice Next ID manager is responsible for updating `nextId` variable,
	 *      pointing to the next iNFT ID free slot
	 *
	 * @dev Role ROLE_NEXT_ID_MANAGER allows `updateNextId` execution,
	 *     and `nextId` modification
	 */
	uint32 public constant ROLE_NEXT_ID_MANAGER = 0x0002_0000;

	/**
	 * @notice Whitelist manager is responsible for managing the target NFT contracts
	 *     whitelist, which are the contracts iNFT is allowed to be bound to
	 *
	 * @dev Role ROLE_WHITELIST_MANAGER allows `whitelistTargetContract` execution,
	 *     and `whitelistedTargetContracts` mapping modification
	 */
	uint32 public constant ROLE_WHITELIST_MANAGER = 0x0004_0000;

	/**
	 * @dev Fired in updateLinkPrice()
	 *
	 * @param _by an address which executed the operation
	 * @param _linkPrice new linking price set
	 * @param _linkFee new linking fee set
	 * @param _feeDestination new treasury address set
	 */
	event LinkPriceChanged(address indexed _by, uint96 _linkPrice, uint96 _linkFee, address _feeDestination);

	/**
	 * @dev Fired in updateNextId()
	 *
	 * @param _by an address which executed the operation
	 * @param oldVal old nextId value
	 * @param newVal new nextId value
	 */
	event NextIdChanged(address indexed _by, uint256 oldVal, uint256 newVal);

	/**
	 * @dev Fired in whitelistTargetContract()
	 *
	 * @param _by an address which executed the operation
	 * @param targetContract target NFT contract address affected
	 * @param oldVal old whitelisted value
	 * @param newVal new whitelisted value
	 */
	event TargetContractWhitelisted(address indexed _by, address indexed targetContract, bool oldVal, bool newVal);

	/**
	 * @dev Fired in link() when new iNFT is created
	 *
	 * @param _by an address which executed the link function
	 * @param iNftId ID of the iNFT minted
	 * @param linkPrice amount of ALI tokens locked (transferred) to newly created iNFT
	 * @param personalityContract AI Personality contract address
	 * @param personalityId ID of the AI Personality locked (transferred) to newly created iNFT
	 * @param targetContract target NFT smart contract
	 * @param targetId target NFT ID (where this iNFT binds to and belongs to)
	 */
	event Linked(
		address indexed _by,
		uint256 iNftId,
		uint96 linkPrice,
		uint96 linkFee,
		address personalityContract,
		uint96 personalityId,
		address targetContract,
		uint256 targetId
	);

	/**
	 * @dev Fired in unlink() when an existing iNFT gets destroyed
	 *
	 * @param _by an address which executed the unlink function
	 * @param iNftId ID of the iNFT burnt
	 * @param recipient and address which received unlocked AI Personality and ALI tokens
	 */
	event Unlinked(
		address indexed _by,
		uint256 iNftId,
		address recipient
	);

	/**
	 * @dev Creates/deploys an iNFT Linker instance bound to already deployed
	 *      iNFT, AI Personality and ALI Token instances
	 *
	 * @param _iNft address of the deployed iNFT instance the iNFT Linker is bound to
	 * @param _personality address of the deployed AI Personality instance the iNFT Linker is bound to
	 * @param _ali address of the deployed ALI ERC20 Token instance the iNFT Linker is bound to
	 */
	constructor(address _ali, address _personality, address _iNft) {
		// verify inputs are set
		require(_ali != address(0), "ALI Token addr is not set");
		require(_personality != address(0), "AI Personality addr is not set");
		require(_iNft != address(0), "iNFT addr is not set");

		// verify inputs are valid smart contracts of the expected interfaces
		require(ERC165(_ali).supportsInterface(type(ERC20).interfaceId), "unexpected ALI Token type");
		require(ERC165(_personality).supportsInterface(type(ERC721).interfaceId), "unexpected AI Personality type");
		require(ERC165(_iNft).supportsInterface(type(IntelligentNFTv2Spec).interfaceId), "unexpected iNFT type");

		// setup smart contract internal state
		aliContract = _ali;
		personalityContract = _personality;
		iNftContract = _iNft;
	}

	/**
	 * @notice Links given AI Personality with the given NFT and forms an iNFT.
	 *      AI Personality specified and `linkPrice` ALI are transferred into minted iNFT
	 *      and are effectively locked within an iNFT until it is destructed (burnt)
	 *
	 * @dev AI Personality and ALI tokens are transferred from the transaction sender account,
	 *      by iNFT smart contract
	 * @dev Sender must approve both AI Personality and ALI tokens transfers to be performed by iNFT contract
	 *
	 * @param personalityId AI Personality ID to be locked into iNFT
	 * @param targetContract NFT address iNFT to be linked to
	 * @param targetId NFT ID iNFT to be linked to
	 */
	function link(uint96 personalityId, address targetContract, uint256 targetId) public {
		// verify AI Personality belongs to transaction sender
		require(ERC721(personalityContract).ownerOf(personalityId) == msg.sender, "access denied");
		// verify NFT contract is either whitelisted or any NFT contract is allowed globally
		require(whitelistedTargetContracts[targetContract] || isFeatureEnabled(FEATURE_ALLOW_ANY_NFT_CONTRACT), "not a whitelisted NFT contract");

		// if linking price is set
		if(linkPrice > 0) {
			// transfer ALI tokens to iNFT contract to be locked
			ERC20(aliContract).transferFrom(msg.sender, iNftContract, linkPrice - linkFee);
		}

		// if linking fee is set
		if(linkFee > 0) {
			// transfer ALI tokens to the treasury - `feeDestination`
			ERC20(aliContract).transferFrom(msg.sender, feeDestination, linkFee);
		}

		// transfer AI Personality to iNFT contract to be locked
		ERC721(personalityContract).transferFrom(msg.sender, iNftContract, personalityId);

		// mint the next iNFT, increment next iNFT ID to be minted
		IntelligentNFTv2(iNftContract).mint(nextId++, linkPrice - linkFee, personalityContract, personalityId, targetContract, targetId);

		// emit an event
		emit Linked(msg.sender, nextId - 1, linkPrice, linkFee, personalityContract, personalityId, targetContract, targetId);
	}

	/**
	 * @notice Destroys given iNFT, unlinking it from underlying NFT and unlocking
	 *      the AI Personality and ALI tokens locked in iNFT.
	 *      AI Personality and ALI tokens are transferred to the underlying NFT owner
	 *
	 * @dev Can be executed only by iNFT owner (effectively underlying NFT owner)
	 *
	 * @param iNftId ID of the iNFT to unlink
	 */
	function unlink(uint256 iNftId) public {
		// get a link to an iNFT contract to perform several actions with it
		IntelligentNFTv2 iNFT = IntelligentNFTv2(iNftContract);

		// verify the transaction is executed by iNFT owner (effectively by underlying NFT owner)
		require(iNFT.ownerOf(iNftId) == msg.sender, "not an iNFT owner");

		// burn the iNFT unlocking the AI Personality and ALI tokens - delegate to `IntelligentNFTv2.burn`
		iNFT.burn(iNftId);

		// emit an event
		emit Unlinked(msg.sender, iNftId, msg.sender);
	}

	/**
	 * @notice Unlink given NFT by destroying iNFTs and unlocking
	 *      the AI Personality and ALI tokens locked in iNFTs.
	 *      AI Personality and ALI tokens are transferred to the underlying NFT owner
	 *
	 * @dev Can be executed only by NFT owner
	 *
	 * @param nftContract NFT address iNFTs to be unlinked to
	 * @param nftId NFT ID iNFTs to be unlinked to
	 */
	function unlinkNFT(address nftContract, uint256 nftId) public {
		// get a link to an iNFT contract to perform several actions with it
		IntelligentNFTv2 iNFT = IntelligentNFTv2(iNftContract);

		// verify the transaction is executed by NFT owner
		require(ERC721(nftContract).ownerOf(nftId) == msg.sender, "not an NFT owner");

		// get iNFT ID linked with given NFT
		uint256 iNftId = iNFT.reverseBindings(nftContract, nftId);

		// burn the iNFT unlocking the AI Personality and ALI tokens - delegate to `IntelligentNFTv2.burn`
		iNFT.burn(iNftId);

		// emit an event
		emit Unlinked(msg.sender, iNftId, msg.sender);
	}

	/**
	 * @dev Restricted access function to modify
	 *      - linking price `linkPrice`,
	 *      - linking fee `linkFee`, and
	 *      - treasury address `feeDestination`
	 *
	 * @dev Requires executor to have ROLE_LINK_PRICE_MANAGER permission
	 * @dev Requires linking price to be either unset (zero), or not less than 1e12 (0.000001 ALI)
	 * @dev Requires both linking fee and treasury address to be either set or unset (zero);
	 *      if set, linking fee must not be less than 1e12 (0.000001 ALI);
	 *      if set, linking fee must not exceed linking price
	 *
	 * @param _linkPrice new linking price to be set
	 * @param _linkFee new linking fee to be set
	 * @param _feeDestination treasury address
	 */
	function updateLinkPrice(uint96 _linkPrice, uint96 _linkFee, address _feeDestination) public {
		// verify the access permission
		require(isSenderInRole(ROLE_LINK_PRICE_MANAGER), "access denied");

		// verify the price is not too low if it's set
		require(_linkPrice == 0 || _linkPrice >= 1e12, "invalid price");

		// linking fee/treasury should be either both set or both unset
		// linking fee must not be too low if set
		require(_linkFee == 0 && _feeDestination == address(0) || _linkFee >= 1e12 && _feeDestination != address(0), "invalid linking fee/treasury");
		// linking fee must not exceed linking price
		require(_linkFee <= _linkPrice, "linking fee exceeds linking price");

		// update the linking price, fee, and treasury address
		linkPrice = _linkPrice;
		linkFee = _linkFee;
		feeDestination = _feeDestination;

		// emit an event
		emit LinkPriceChanged(msg.sender, _linkPrice, _linkFee, _feeDestination);
	}

	/**
	 * @dev Restricted access function to modify next iNFT ID `nextId`
	 *
	 * @param _nextId new next iNFT ID to be set
	 */
	function updateNextId(uint256 _nextId) public {
		// verify the access permission
		require(isSenderInRole(ROLE_NEXT_ID_MANAGER), "access denied");

		// verify nextId is in safe bounds
		require(_nextId > 0xFFFF_FFFF, "value too low");

		// emit a event
		emit NextIdChanged(msg.sender, nextId, _nextId);

		// update next ID
		nextId = _nextId;
	}

	/**
	 * @dev Restricted access function to manage whitelisted NFT contracts mapping `whitelistedTargetContracts`
	 *
	 * @dev Requires executor to have ROLE_WHITELIST_MANAGER permission
	 *
	 * @param targetContract target NFT contract address to add/remove to/from the whitelist
	 * @param whitelist true to add, false to remove to/from whitelist
	 */
	function whitelistTargetContract(address targetContract, bool whitelist) public {
		// verify the access permission
		require(isSenderInRole(ROLE_WHITELIST_MANAGER), "access denied");

		// verify the address is set
		require(targetContract != address(0), "zero address");

		// delisting is always possible, whitelisting - only for valid ERC721
		if(whitelist) {
			// verify targetContract is a valid ERC721
			require(ERC165(targetContract).supportsInterface(type(ERC721).interfaceId), "target NFT is not ERC721");
		}

		// emit an event
		emit TargetContractWhitelisted(msg.sender, targetContract, whitelistedTargetContracts[targetContract], whitelist);

		// add/remove the contract address to/from the whitelist
		whitelistedTargetContracts[targetContract] = whitelist;
	}
}