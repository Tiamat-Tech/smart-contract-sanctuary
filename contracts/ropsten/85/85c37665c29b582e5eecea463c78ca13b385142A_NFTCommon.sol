// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./XIOCustodian.sol";

contract NFTCommon is ERC721URIStorage, Ownable, RoyaltiesV2Impl {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    string constant ipfsURL = "ipfs://QmVe5HFBNcFhWUQEgsa7oRqrKWvF4NyRhvY4QYaT92fjZ1/111.json";
    uint256 constant hardCap = 1000;

    // Amount to transfer into NFT
    uint256 constant depositAmount = 100 * 10**18;

    // Royalty stuff
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    struct RoyaltyInformation {
        address payable receiver;
        uint96 percentageBasisPoints;
    }
    RoyaltyInformation royaltyInformation;

    // The details for the mint payment
    struct MintingDetails {
        address paymentERCTokenAddress;
        address paymentRecipientAddress;
        uint256 paymentAmount;
    }
    MintingDetails mintingDetails;

    // Additional details
    address custodianContractAddress;

    // Define Events to emit
    event PaymentDetailsUpdated(
        address indexed _paymentERCTokenAddress,
        uint256 _paymentAmount,
        address indexed _paymentRecipientAddress
    );

    constructor() public ERC721("BZNFT_T3_TN", "BZNFT_T3_TN") {}

    function contractURI() public view returns (string memory) {
        return "ipfs://QmWecwcp9qp68cfa5NarzAPbkjj8m29we1v3MNiYyBfxGg";
    }

    function setDefaultRoyaltyDetails(address payable _defaultRoyaltyReceiver, uint96 _defaultPercentageBasisPoints)
        public
        onlyOwner
        returns (bool)
    {
        royaltyInformation.receiver = _defaultRoyaltyReceiver;
        royaltyInformation.percentageBasisPoints = _defaultPercentageBasisPoints;
        return true;
    }

    function getDefaultRoyaltyDetails() public view returns (address payable, uint96) {
        return (royaltyInformation.receiver, royaltyInformation.percentageBasisPoints);
    }

    function setCustodianContract(address _custodianContract) public onlyOwner returns (bool) {
        require(custodianContractAddress == address(0), "CUSTODIAN IS ALREADY SET");
        custodianContractAddress = _custodianContract;

        // Approve the ERC20 payment token such that this NFTCommon contract can spent the custodian funds
        IERC20(mintingDetails.paymentERCTokenAddress).approve(
            custodianContractAddress,
            IERC20(mintingDetails.paymentERCTokenAddress).totalSupply()
        );
        return true;
    }

    function getCustodianContract() public view returns (address) {
        return custodianContractAddress;
    }

    function exists(uint256 _tokenId) public view returns (bool) {
        return _exists(_tokenId);
    }

    function setPaymentDetails(
        address _paymentERCTokenAddress,
        uint256 _paymentAmount,
        address _paymentRecipientAddress
    ) public onlyOwner {
        mintingDetails = MintingDetails(_paymentERCTokenAddress, _paymentRecipientAddress, _paymentAmount);
        emit PaymentDetailsUpdated(_paymentERCTokenAddress, _paymentAmount, _paymentRecipientAddress);
    }

    function getPaymentDetails()
        public
        view
        returns (
            address,
            uint256,
            address
        )
    {
        return (
            mintingDetails.paymentERCTokenAddress,
            mintingDetails.paymentAmount,
            mintingDetails.paymentRecipientAddress
        );
    }

    function burn(uint256 _tokenId) public returns (bool) {
        require(msg.sender == ownerOf(_tokenId) || msg.sender == custodianContractAddress, "NOT OWNER OR CUSTODIAN");

        _burn(_tokenId);
        return true;
    }

    function mint(address _recipientAddress) public virtual returns (uint256) {
        uint256 newUniqueId = tokenIds.current();

        require(newUniqueId <= hardCap, "HARD CAP REACHED");
        require(custodianContractAddress != address(0), "CUSTODIAN IS INVALID");

        // Accept payment from the minter
        IERC20(mintingDetails.paymentERCTokenAddress).transferFrom(
            msg.sender,
            mintingDetails.paymentRecipientAddress,
            mintingDetails.paymentAmount
        );

        // Mint the actual token
        _mint(_recipientAddress, newUniqueId);
        _setTokenURI(newUniqueId, ipfsURL);
        tokenIds.increment();

        // Call the Custodian contract to transfer X XIO
        XIOCustodian(custodianContractAddress).deposit(newUniqueId, depositAmount);

        // Set the royalties
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = royaltyInformation.percentageBasisPoints;
        _royalties[0].account = royaltyInformation.receiver;
        _saveRoyalties(newUniqueId, _royalties);

        return newUniqueId;
    }

    // This is the same as mint but allows bulk minting
    function bulkMint(address[] memory _recipientAddresses) public returns (uint256[] memory) {
        uint256[] memory newUniqueIds = new uint256[](_recipientAddresses.length);

        for (uint256 i = 0; i < _recipientAddresses.length; i++) {
            newUniqueIds[i] = mint(_recipientAddresses[i]);
        }

        return newUniqueIds;
    }

    function totalSupply() public view returns (uint256) {
        return tokenIds.current();
    }

    function setRoyalties(
        uint256 _tokenId,
        address payable _royaltiesRecipientAddress,
        uint96 _percentageBasisPoints
    ) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesRecipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721) returns (bool) {
        if (_interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        if (_interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(_interfaceId);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        LibPart.Part[] memory _royalties = royalties[_tokenId];
        if (_royalties.length > 0) {
            return (_royalties[0].account, (_salePrice * _royalties[0].value) / 10000);
        }
        return (address(0), 0);
    }
}