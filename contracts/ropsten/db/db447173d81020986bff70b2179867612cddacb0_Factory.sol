// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "./abstract/AdminAccess.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/IMarketplace.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./TangibleNFT.sol";

contract Factory is EIP712, AdminAccess, IFactory {
    using SafeERC20 for IERC20;

    IERC20 public immutable override USDC;
    address public override feeStorageAddress;
    address public override marketplace;

    mapping (string => ITangibleNFT) public override category;

    string private constant SIGNING_DOMAIN = "TNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    uint256 private _chainId;

    /// @dev Restricted to members of the admin role.
    constructor(address _usdc, address _feeStorageAddress)
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        require(_feeStorageAddress != address(0), "ZFSA");
        require(_usdc != address(0), "ZUSDC");

        uint256 id;
        assembly {
            id := chainid()
        }
        _chainId = id;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        USDC = IERC20(_usdc);

        emit FeeStorageAddressSet(address(0), _feeStorageAddress);
        feeStorageAddress = _feeStorageAddress;
    }

    /// @notice Sets the feeStorageAddress
    /// @dev Will emit FeeStorageAddressSet on change.
    /// @param _feeStorageAddress A new address for fee storage.
    function setFeeStorageAddress(address _feeStorageAddress) onlyAdmin() external {
        require(_feeStorageAddress != address(0), "ZFSA");
        if (feeStorageAddress != _feeStorageAddress) {
            emit FeeStorageAddressSet(feeStorageAddress, _feeStorageAddress);
            feeStorageAddress = _feeStorageAddress;
        }
    }

    /// @notice Sets the IMarketplace address
    /// @dev Will emit MarketplaceAddressSet on change.
    /// @param _marketplace A new address of the Marketplace
    function setMarketplace(address _marketplace) onlyAdmin() external {
        require(_marketplace != address(0), "ZMPA");
        if (marketplace != _marketplace) {
            emit MarketplaceAddressSet(marketplace, _marketplace);
            marketplace = _marketplace;
        }
    }

    /// @notice Mints the TangibleNFT token from the given MintVoucher
    /// @dev Will revert if the signature is invalid.
    /// @param voucher An MintVoucher describing an unminted TangibleNFT.
    /// @param to An address which will receive TangibleNFT when success.
    function mint(MintVoucher calldata voucher, address to) external override {
        // make sure signature is valid and get the address of the vendor
        address signer = _verify(voucher);
        require(signer == voucher.vendor, "Not a vendor signed!");

        // how much will cost asked amount of tokens
        uint256 cost = voucher.price * voucher.amount;

        // first assign the token to the vendor, to establish provenance on-chain
        voucher.token.mint(voucher.tokenId, voucher.mintCount, voucher.vendor);
        voucher.token.setBrand(voucher.tokenId, voucher.brand);

        // Take minting fee
        emit MintingFeePaid(msg.sender, address(voucher.token), voucher.tokenId, voucher.mintingFee);
        USDC.safeTransferFrom(msg.sender, feeStorageAddress, voucher.mintingFee);

        if (marketplace == address(0)) {
            // if not marketplace is set —> transfer USDC directly to the vendor
            USDC.safeTransferFrom(msg.sender, voucher.vendor, cost);
        } else {
            // otherwise -> send to the marketplace
            USDC.safeTransferFrom(msg.sender, marketplace, cost);
            IMarketplace(marketplace).bought(voucher.vendor, cost);
        }

        // Pay for storage
        uint256 storageFee = voucher.token.storagePricePerYear() * voucher.storageYears;
        USDC.safeTransferFrom(msg.sender, address(this), storageFee);
        voucher.token.payForStorage(voucher.tokenId, voucher.storageYears);

        // transfer the tokens to the buyer at the end
        IERC1155(voucher.token).safeTransferFrom(voucher.vendor, to, voucher.tokenId, voucher.amount, "");
    }

    /// @notice Burns the TangibleNFT token from the given BurnVoucher
    /// @dev Will revert if the signature is invalid.
    /// @param voucher An BurnVoucher describing an minted TangibleNFT.
    function burn(BurnVoucher calldata voucher) external override {
        // make sure signature is valid and get the address of the vendor
        address signer = _verify(voucher);
        require(signer == voucher.from, "Not a vendor signed!");

        // first assign the token to the vendor, to establish provenance on-chain
        voucher.token.burn(voucher.tokenId, voucher.amount, voucher.from);
    }

    function newCategory(string memory name) external override returns (ITangibleNFT) {
        require(address(category[name]) == address(0), "CE");

        ITangibleNFT tangibleNFT = new TangibleNFT(address(this));
        category[name] = tangibleNFT;

        return tangibleNFT;
    }

    /// @notice Returns a hash of the given MintVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An MintVoucher to hash.
    function _hash(MintVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("MintVoucher(address token,uint256 tokenId,uint256 price,uint256 storageYears,uint256 mintingFee,uint256 amount,uint256 mintCount,address vendor,string brand)"),
                voucher.token,
                voucher.tokenId,
                voucher.price,
                voucher.storageYears,
                voucher.mintingFee,
                voucher.amount,
                voucher.mintCount,
                voucher.vendor,
                keccak256(bytes(voucher.brand))
            )));
    }

    /// @notice Returns a hash of the given MintVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An MintVoucher to hash.
    function _hash(BurnVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
                keccak256("BurnVoucher(address token,uint256 tokenId,uint256 amount,address from)"),
                voucher.token,
                voucher.tokenId,
                voucher.amount,
                voucher.from
            )));
    }

    /// @notice Verifies the signature for a given MintVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint TangibleNFTs.
    /// @param voucher An MintVoucher describing an unminted TangibleNFT.
    function _verify(MintVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /// @notice Verifies the signature for a given BurnVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to burn TangibleNFTs.
    /// @param voucher An BurnVoucher describing an minted TangibleNFT.
    function _verify(BurnVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }
}