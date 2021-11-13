// SPDX-License-Identifier: MIT
// Smart Contract Written by: Ian Olson

/*

    ____                      __               ______                                __
   / __ )________  ____  ____/ /___ _____     / ____/__  _________  ____ _____  ____/ /__  ______
  / __  / ___/ _ \/ __ \/ __  / __ `/ __ \   / /_  / _ \/ ___/ __ \/ __ `/ __ \/ __  / _ \/ ___(_)
 / /_/ / /  /  __/ / / / /_/ / /_/ / / / /  / __/ /  __/ /  / / / / /_/ / / / / /_/ /  __(__  )
/_____/_/   \___/_/ /_/\__,_/\__,_/_/ /_/  /_/    \___/_/  /_/ /_/\__,_/_/ /_/\__,_/\___/____(_)
  / ___/____  __  ___   _____  ____  (_)____
  \__ \/ __ \/ / / / | / / _ \/ __ \/ / ___/
 ___/ / /_/ / /_/ /| |/ /  __/ / / / / /
/____/\____/\__,_/ |___/\___/_/ /_/_/_/

We are not moving our lives into the digital space any more than we moved our lives into the tactile space with the
advent of woodblock printing in the 9th century. The digital is not infinite or transcendent, but maybe we can use it to
create systems in our material world that are. It is our duty not to shy away from new spaces, but to transform them
into new possibilities; something that reflects our own visions.

In 2010 Brendan Fernandes began to investigate ideas of “authenticity” explored through the dissemination of Western
notions of an exotic Africa through the symbolic economy of "African" masks. These masks were removed from their place
of origin and displayed in the collections of museums such as The Metropolitan Museum of Art. They lost their
specificity and cultural identity as they became commodifiable objects, bought and sold in places like Canal Street in
New York City.

In traditional West African masquerade when the performer puts on the mask, it becomes a bridge between the human and
spiritual realms. The work examines the  authenticity of these objects in the context of Western museums where they have
been placed at rest and serve as exotified objects as opposed to serving their original aforementioned spiritual purpose.

In Fernandes’ genesis NFT project he is coming back to this work and thinking through the mask as an object that is
still in flux and that lives within a cryptographic and digital space.  Conceptually in this new work the masks now take
on an alternate form of existence as we re-imbue them with the ability to morph and change in both physical form as well
as economic value. The piece is constantly in a state of becoming and in that it can be seen as a take away or a
souvenir. These NFT masks take inspiration from three specific masks housed in the Metropolitan Museum's African
collection. The artist has scanned different materials: Gold, Textiles, Wood and Shells to create layers that will
become the foundation of these “new” masks.

*/

pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IRaribleRoyaltiesV2.sol";
import "./libraries/StringsUtil.sol";

contract Souvenir is Ownable, ERC721, IRaribleRoyaltiesV2 {
    using SafeMath for uint256;

    // ---
    // Constants
    // ---

    uint256 constant public imnotArtInitialSaleBps = 2860; // 28.6%
    uint256 constant public royaltyFeeBps = 1000; // 10%
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
    bytes4 private constant _INTERFACE_ID_EIP2981 = 0x2a55205a;
    bytes4 private constant _INTERFACE_RARIBLE_ROYALTIES = 0xcad96cca; // bytes4(keccak256('getRaribleV2Royalties(uint256)')) == 0xcad96cca

    // ---
    // Events
    // ---

    event Mint(uint256 indexed tokenId, string metadata, address indexed owner);
    event Debug(string breakpoint);

    // ---
    // Properties
    // ---

    string public contractUri;
    string public metadataBaseUri;
    address public royaltyContractAddress;
    address public imnotArtPayoutAddress;
    address public artistPayoutAddress;

    uint256 public nextTokenId = 0;
    uint256 public maxPerAddress = 10;
    uint256 public invocations = 0;
    uint256 public maxInvocations = 1000;
    uint256 public mintPriceInWei = 100000000000000000; // 0.1 ETH
    bool public active = false;
    bool public presale = true;
    bool public paused = false;
    bool public completed = false;

    // ---
    // Mappings
    // ---

    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isPresaleWallet;

    // ---
    // Modifiers
    // ---

    modifier onlyValidTokenId(uint256 tokenId) {
        require(_exists(tokenId), "Token ID does not exist.");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[_msgSender()], "Only admins.");
        _;
    }

    modifier onlyActive() {
        require(active, "Minting is not active.");
        _;
    }

    modifier onlyNonPaused() {
        require(!paused, "Minting is paused.");
        _;
    }

    // ---
    // Constructor
    // ---

    constructor(address _royaltyContractAddress) ERC721("Brendan Fernandes Souvenir", "SOUVENIR") {
        royaltyContractAddress = _royaltyContractAddress;

        // Defaults
        contractUri = 'https://ipfs.imnotart.com/ipfs/QmZTPfna2V16oqqdsZz7SQNcqtSgkk3DxRHKdYqHFHiH7Y';
        metadataBaseUri = 'https://ipfs.imnotart.com/ipfs/QmXdiQriG11LQoNfrZrCdWwxa5CdDVYCEMGgZGEQJKxutf/';

        // Brendan Fernandes Address
        artistPayoutAddress = address(0x711c0385795624A338E0399863dfdad4523C46b3);

        // imnotArt Gnosis Safe
        imnotArtPayoutAddress = address(0x12b66baFc99D351f7e24874B3e52B1889641D3f3);

        // Add admins
        isAdmin[_msgSender()] = true;
        isAdmin[imnotArtPayoutAddress] = true;
        isAdmin[artistPayoutAddress] = true;

        // Setup Initial Pre-Sale List (Sign-Up form & POAP)
        isPresaleWallet[address(0x1E206C62a4021199B1C11436eaA4feea3c5d0F1b)] = true;
        isPresaleWallet[address(0x049569adb8a1e8A9349E9F1111C7b7993A4612eB)] = true;
        isPresaleWallet[address(0x07cBD4e4473140b6078Aa987907aafF5E500b9f1)] = true;
        isPresaleWallet[address(0x07dD8451d27eBB6442395A512A081dAfC6791850)] = true;
        isPresaleWallet[address(0x089D3D1A1d25F565BC556D7f10b0fb35ddfd2cE4)] = true;
        isPresaleWallet[address(0x08cF1208e638a5A3623be58d600e35c6199baa9C)] = true;
        isPresaleWallet[address(0x107BF3FD5Db09230A296e282fC97880fCcF8aBF6)] = true;
        isPresaleWallet[address(0x1633D4bc407069A31D261a427EF6FB0492cD9B88)] = true;
        isPresaleWallet[address(0x22E26230461878969062008Dba98301e2FB6b8A5)] = true;
        isPresaleWallet[address(0x22ed7a936D3DEA108004E3229F3bD3D84C7225db)] = true;
        isPresaleWallet[address(0x23c418410A9709a318999f3e2D332A9eD684a030)] = true;
        isPresaleWallet[address(0x29ce0DF06dA9d430538606251C377476C6423cd1)] = true;
        isPresaleWallet[address(0x2B5598777dea6bb41D4aB812886530376cAfFdD8)] = true;
        isPresaleWallet[address(0x2DEFa1bd7f698ad0324D57134b97ba54AB1cD0B1)] = true;
        isPresaleWallet[address(0x3128f5E622781AF0757b8085BC1ae694519a9340)] = true;
        isPresaleWallet[address(0x396054f3012B76d2C940b233751FB18d25a80200)] = true;
        isPresaleWallet[address(0x3b0AA499Cc6acDE1d4a7433dA6968d7bb8BD8509)] = true;
        isPresaleWallet[address(0x3b6D0dd29a60ff5EA96b54e60fBb0d71dA80ef78)] = true;
        isPresaleWallet[address(0x3fd5c53c5A6ef5Cd8d90d07acBcF50cED07fD2cE)] = true;
        isPresaleWallet[address(0x474B6c2366128eaCAeA1b6e411171c06B49BDC97)] = true;
        isPresaleWallet[address(0x4b4169206483f17117D3C5825Ab9cfaa2Be7A4C1)] = true;
        isPresaleWallet[address(0x4cA4c3Da7a977D6B5865A96aD5125C4786019b97)] = true;
        isPresaleWallet[address(0x50FEe0261674f5e6b982D93F6D033ab975bc2769)] = true;
        isPresaleWallet[address(0x52f630867FbE5A9AC916Ad3148693ba45068c399)] = true;
        isPresaleWallet[address(0x55a21799569065Cf6eF7Fb2d505BB8d8238f132F)] = true;
        isPresaleWallet[address(0x580E911CE60323505bc00889fC5F4671fe3095c0)] = true;
        isPresaleWallet[address(0x595a670f8171c304594eCAAff5E7C940d01F1352)] = true;
        isPresaleWallet[address(0x5a970AcECb41a627f51d9624b9ED90c666001b12)] = true;
        isPresaleWallet[address(0x5cC1E6229708533aC0F5e9E98931334341ff24C2)] = true;
        isPresaleWallet[address(0x5d2833644fAD83Ae01dd500964b0446175F2AA74)] = true;
        isPresaleWallet[address(0x5F24078e1F76a3E7d007488a018942365F51f6B4)] = true;
        isPresaleWallet[address(0x7466ebF3B8aF67511f7163Ab1E31f928b2E60330)] = true;
        isPresaleWallet[address(0x75B0BD88159f8D0E19b904E900F0517b00F8012f)] = true;
        isPresaleWallet[address(0x75E7c0D05c6b43173A78494dAa78f777f03643Eb)] = true;
        isPresaleWallet[address(0x76c1eEAAAd4c3BF6526E09A84a1FBCdff56F8D55)] = true;
        isPresaleWallet[address(0x7bA549105C8741a499F0b248458964B8c03fC6AB)] = true;
        isPresaleWallet[address(0x7e97e648B6576187f1A4a03b194CBFD4eE76F543)] = true;
        isPresaleWallet[address(0x85f9c38a44EfB45CeF47cBf510e6e18cDdf2a78A)] = true;
        isPresaleWallet[address(0x8667ec8568B1e6c28E4e9e95379e4c0176d20aE1)] = true;
        isPresaleWallet[address(0x8693975917C99642938CF9481AC6829Bf625de71)] = true;
        isPresaleWallet[address(0x877167231d569c9fcF5e7a5E2b073c7cd41f2cFF)] = true;
        isPresaleWallet[address(0x8813DAB606E72EFDaBB26DB2D599527857cee583)] = true;
        isPresaleWallet[address(0x89189Eb2a65727Ed51C4bAb56748AA0C2d61C310)] = true;
        isPresaleWallet[address(0x89a591CDe66526765c2A58E09a0970BcF0D6Df0F)] = true;
        isPresaleWallet[address(0x8ee2338478a3f300f43cAF240Dd06bB2F76bd23e)] = true;
        isPresaleWallet[address(0x914DBC290ef0848153418E96d7c2e242d77eF295)] = true;
        isPresaleWallet[address(0x94F666Ff38C1C911B887C0A252F69cA4eF69C8ec)] = true;
        isPresaleWallet[address(0x963BA08F07e32e496faDc6ea6C1B40806E93dFD9)] = true;
        isPresaleWallet[address(0x967C26f060c991fc630B014901fd1eFb33B2c82A)] = true;
        isPresaleWallet[address(0x9692B10361e206A43121b359231A8D1792C20804)] = true;
        isPresaleWallet[address(0x969b94dB7fde3DF010aa1C75c58112a9b40B88B2)] = true;
        isPresaleWallet[address(0x98AAC498014A20fA3F40Ba703D60A691FDd6949c)] = true;
        isPresaleWallet[address(0x9a9ac2c433c312F930E10E70fe3431E1ADeC3671)] = true;
        isPresaleWallet[address(0x9AD30880F19adc37929Bf1413FbfE54a2837e982)] = true;
        isPresaleWallet[address(0x9aE264DA471a45E54F57d61e6226A72689a33200)] = true;
        isPresaleWallet[address(0x9bF2a97995A79Ea04B5BF3fA1414Fe91c453c153)] = true;
        isPresaleWallet[address(0xA335ADE338308B8e071Cf2c8F3cA5e50F6563C60)] = true;
        isPresaleWallet[address(0xa83858CE6035F4a18FA615882f4E9E55fE78D274)] = true;
        isPresaleWallet[address(0xad2b5e6cF9bCc32236e8c6add40e779E58ccdadA)] = true;
        isPresaleWallet[address(0xaD69690011d37e5ec9aE44f1b361755B93456Fa9)] = true;
        isPresaleWallet[address(0xB00A0aF5eD3dcEC55E2222e25a151ae35408e0e6)] = true;
        isPresaleWallet[address(0xb582911362080D51657596853Cd56344B3F320C3)] = true;
        isPresaleWallet[address(0xc62b2e226b73106FB155065a6135a7cD84684c21)] = true;
        isPresaleWallet[address(0xCa3951d132062201D1FAc69323F9D15510b64D41)] = true;
        isPresaleWallet[address(0xd1cDFc352b317cDdB931299017E09c4f34e02F27)] = true;
        isPresaleWallet[address(0xDd8c1dB65964607C119535c98a6F6eD52b41588E)] = true;
        isPresaleWallet[address(0xDdff95614ada6e8336866db2336eF000077FA9bD)] = true;
        isPresaleWallet[address(0xe6564cE948A3097916e7d4FC466d49DBd4d5b4eb)] = true;
        isPresaleWallet[address(0xe7E2D654434F505ae6A40f723d5cFb3B40FEb8Da)] = true;
        isPresaleWallet[address(0xe89C2545e4e05A79D21351CdEeDa4651ca48DeBc)] = true;
        isPresaleWallet[address(0xEb6BD1e09569a06a08B5b3379d5B8976Fe0B30Ae)] = true;
        isPresaleWallet[address(0xf1474fBa301e6432c50464561E68610CA53fA096)] = true;
        isPresaleWallet[address(0xF221181Fc26Ee4896E8dB86f6F68Fb3a6d2F93F4)] = true;
        isPresaleWallet[address(0xfEA9B1760505fe0ac6ac48c30Bc81c9D7431f554)] = true;
        isPresaleWallet[address(0xC16f1eDAbfAEa8981F2Ba8D61401f7a76B1fDa50)] = true;
        isPresaleWallet[address(0xE8323AEF317e8A9E64ac337A8E4EcB3FD14E4156)] = true;
        isPresaleWallet[address(0x175cFaD33122b97daE15F063093D445646069665)] = true;
        isPresaleWallet[address(0xE6D64Fc98b7EAd6b3A4E4b06d6dF13bBe381e3c1)] = true;

        // Mint the artist proof
        uint256 tokenId = nextTokenId;
        _mint(artistPayoutAddress, tokenId);
        invocations = invocations.add(1);
        emit Mint(tokenId, tokenURI(tokenId), artistPayoutAddress);

        // Setup the next tokenId
        nextTokenId = nextTokenId.add(1);
    }

    // ---
    // Supported Interfaces
    // ---

    // @dev Return the support interfaces of this contract.
    // @author Ian Olson
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC165
        || interfaceId == _INTERFACE_RARIBLE_ROYALTIES
        || interfaceId == _INTERFACE_ID_ERC721
        || interfaceId == _INTERFACE_ID_ERC721_METADATA
        || interfaceId == _INTERFACE_ID_EIP2981
        || super.supportsInterface(interfaceId);
    }

    // ---
    // Minting
    // ---

    // @dev Mint a new token from the contract.
    // @author Ian Olson
    function mint() public payable onlyActive onlyNonPaused {
        emit Debug("mint: function called");

        if (presale) {
            emit Debug("mint: presale active");
            require(isPresaleWallet[_msgSender()], "Wallet is not part of pre-sale.");
            emit Debug("mint: presale wallet verified");
        }

        emit Debug("mint: starting minting logic");

        uint256 requestedInvocations = invocations.add(1);
        require(requestedInvocations <= maxInvocations, "Must not exceed max invocations.");
        require(msg.value >= mintPriceInWei, "Must send minimum value.");

        emit Debug("mint: passed invocation and value check");

        // Grab Next Token ID and Mint
        uint256 tokenId = nextTokenId;
        emit Debug("mint: grabbed nextTokenId");
        _mint(_msgSender(), tokenId);
        emit Debug("mint: minted tokenId");
        emit Mint(tokenId, tokenURI(tokenId), _msgSender());

        // Update nextTokenId
        nextTokenId = nextTokenId.add(1);
        emit Debug("mint: updated nextTokenId");

        // Update number of invocations
        invocations = invocations.add(1);
        emit Debug("mint: updated invocations");

        emit Debug("mint: starting refunds and payouts");
        uint256 balance = msg.value;
        uint256 refund = balance.sub(mintPriceInWei);
        if (refund > 0) {
            emit Debug("mint: refund needed");
            balance = balance.sub(refund);
            payable(_msgSender()).transfer(refund);
            emit Debug("mint: refund completed");
        }

        // Payout imnotArt
        uint256 imnotArtPayout = SafeMath.div(SafeMath.mul(balance, imnotArtInitialSaleBps), 10000);
        if (imnotArtPayout > 0) {
            emit Debug("mint: imnotartPayout needed");
            balance = balance.sub(imnotArtPayout);
            payable(imnotArtPayoutAddress).transfer(imnotArtPayout);
            emit Debug("mint: imnotartPayout completed");
        }

        // Payout Artist
        payable(artistPayoutAddress).transfer(balance);
        emit Debug("mint: artist payout completed");
    }

    // ---
    // Update Functions
    // ---

    // @dev Add an admin to the contract.
    // @author Ian Olson
    function addAdmin(address adminAddress) public onlyAdmin {
        isAdmin[adminAddress] = true;
    }

    // @dev Remove an admin from the contract.
    // @author Ian Olson
    function removeAdmin(address adminAddress) public onlyAdmin {
        require((_msgSender() != adminAddress), "Cannot remove self.");

        isAdmin[adminAddress] = false;
    }

    // @dev Update the contract URI for the contract.
    // @author Ian Olson
    function updateContractUri(string memory updatedContractUri) public onlyAdmin {
        contractUri = updatedContractUri;
    }

    // @dev Update the artist payout address.
    // @author Ian Olson
    function updateArtistPayoutAddress(address _payoutAddress) public onlyAdmin {
        artistPayoutAddress = _payoutAddress;
    }

    // @dev Update the imnotArt payout address.
    // @author Ian Olson
    function updateImNotArtPayoutAddress(address _payoutAddress) public onlyAdmin {
        imnotArtPayoutAddress = _payoutAddress;
    }

    // @dev Update the royalty contract address.
    // @author Ian Olson
    function updateRoyaltyContractAddress(address _payoutAddress) public onlyAdmin {
        royaltyContractAddress = _payoutAddress;
    }

    // @dev Update the base URL that will be used for the tokenURI() function.
    // @author Ian Olson
    function updateMetadataBaseUri(string memory _metadataBaseUri) public onlyAdmin {
        metadataBaseUri = _metadataBaseUri;
    }

    // @dev Bulk add wallets to pre-sale list.
    // @author Ian Olson
    function bulkAddPresaleWallets(address[] memory presaleWallets) public onlyAdmin {
        require(presaleWallets.length > 1, "Use addPresaleWallet function instead.");
        uint amountOfPresaleWallets = presaleWallets.length;
        for (uint i = 0; i < amountOfPresaleWallets; i++) {
            isPresaleWallet[presaleWallets[i]] = true;
        }
    }

    // @dev Add a wallet to pre-sale list.
    // @author Ian Olson
    function addPresaleWallet(address presaleWallet) public onlyAdmin {
        isPresaleWallet[presaleWallet] = true;
    }

    // @dev Remove a wallet from pre-sale list.
    // @author Ian Olson
    function removePresaleWallet(address presaleWallet) public onlyAdmin {
        require((_msgSender() != presaleWallet), "Cannot remove self.");

        isPresaleWallet[presaleWallet] = false;
    }

    // @dev Update the max invocations, this can only be done BEFORE the minting is active.
    // @author Ian Olson
    function updateMaxInvocations(uint256 newMaxInvocations) public onlyAdmin {
        require(!active, "Cannot change max invocations after active.");
        maxInvocations = newMaxInvocations;
    }

    // @dev Update the mint price, this can only be done BEFORE the minting is active.
    // @author Ian Olson
    function updateMintPriceInWei(uint256 newMintPriceInWei) public onlyAdmin {
        require(!active, "Cannot change mint price after active.");
        mintPriceInWei = newMintPriceInWei;
    }

    // @dev Update the max per address, this can only be done BEFORE the minting is active.
    // @author Ian Olson
    function updateMaxPerAddress(uint newMaxPerAddress) public onlyAdmin {
        require(!active, "Cannot change max per address after active.");
        maxPerAddress = newMaxPerAddress;
    }

    // @dev Enable pre-sale on the mint function.
    // @author Ian Olson
    function enableMinting() public onlyAdmin {
        active = true;
    }

    // @dev Enable public sale on the mint function.
    // @author Ian Olson
    function enablePublicSale() public onlyAdmin {
        presale = false;
    }

    // @dev Toggle the pause state of minting.
    // @author Ian Olson
    function toggleMintPause() public onlyAdmin {
        paused = !paused;
    }

    // ---
    // Get Functions
    // ---

    // @dev Get the token URI. Secondary marketplace specification.
    // @author Ian Olson
    function tokenURI(uint256 tokenId) public view override virtual onlyValidTokenId(tokenId) returns (string memory) {
        return StringsUtil.concat(metadataBaseUri, StringsUtil.uint2str(tokenId));
    }

    // @dev Get the contract URI. OpenSea specification.
    // @author Ian Olson
    function contractURI() public view virtual returns (string memory) {
        return contractUri;
    }

    // ---
    // Withdraw
    // ---

    // @dev Withdraw ETH funds from the given contract with a payout address.
    // @author Ian Olson
    function withdraw(address to) public onlyAdmin {
        uint256 amount = address(this).balance;
        require(amount > 0, "Contract balance empty.");
        payable(to).transfer(amount);
    }

    // ---
    // Secondary Marketplace Functions
    // ---

    // @dev Rarible royalties V2 implementation.
    // @author Ian Olson
    function getRaribleV2Royalties(uint256 id) external view override onlyValidTokenId(id) returns (LibPart.Part[] memory) {
        LibPart.Part[] memory royalties = new LibPart.Part[](1);
        royalties[0] = LibPart.Part({
        account : payable(royaltyContractAddress),
        value : uint96(royaltyFeeBps)
        });

        return royalties;
    }

    // @dev EIP-2981 royalty standard implementation.
    // @author Ian Olson
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view onlyValidTokenId(tokenId) returns (address receiver, uint256 amount) {
        uint256 royaltyPercentageAmount = SafeMath.div(SafeMath.mul(salePrice, royaltyFeeBps), 10000);
        return (royaltyContractAddress, royaltyPercentageAmount);
    }
}