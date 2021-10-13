// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IERC20Mintable.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IGameStationBridge.sol";

contract GameStationBridge is IGameStationBridge, EIP712, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address payable;

    uint256 private constant MAX_INITIAL_PERCENTAGE = 1e20;
    address private constant NATIVE = address(0);
    bytes32 private constant _CONTAINER_TYPEHASE =
        keccak256(
            "Container(address sender,uint256 chainIdFrom,address token,uint256 amount,uint256 nonce)"
        );
    bytes32 private constant _CONTAINER_KYC_TYPEHASE =
        keccak256("KycContainer(address sender)");

    EnumerableSet.AddressSet private _supportedTokens;
    EnumerableSet.AddressSet private _signers;

    mapping(address => mapping(uint256 => bool)) private _nonces;

    mapping(address => mapping(address => uint256)) public userLiquidity;
    mapping(address => TokenInfo) public tokensInfo;

    address payable public feeRecipient;
    address public feeDistributor;

    constructor(
        address[] memory signers_,
        address[] memory tokensToSupport_,
        TokenInfo[] memory tokensInfo_
    ) EIP712("GameStationBridge", "v1") {
        require(signers_.length > 0, "signer_ array is empty");
        require(
            tokensInfo_.length == tokensToSupport_.length,
            "Arrays have different lengths"
        );

        for (uint256 i = 0; i < signers_.length; i++) {
            _signers.add(signers_[i]);
        }

        for (uint256 i = 0; i < tokensToSupport_.length; i++) {
            TokenInfo memory info = tokensInfo_[i];
            require(
                info.fee < MAX_INITIAL_PERCENTAGE,
                "fee is more or equal then 100%"
            );
            require(info.liquidity == 0, "liquidity is not zero");
            address tokenAddress = tokensToSupport_[i];
            _supportedTokens.add(tokenAddress);
            tokensInfo[tokenAddress] = info;

            emit AddSuportedToken(tokensToSupport_[i], info, false);
        }
    }

    function IS_TOKEN_SUPPORTED(address tokenAddress_)
        public
        view
        returns (bool)
    {
        return _supportedTokens.contains(tokenAddress_);
    }

    function getSupportedTokens()
        external
        view
        returns (address[] memory list)
    {
        uint256 lastIndex = _supportedTokens.length();

        list = new address[](lastIndex);

        for (uint256 i = 0; i < lastIndex; i++) {
            list[i] = _supportedTokens.at(i);
        }
    }

    function getSignersAddress()
        external
        view
        onlyOwner
        returns (address[] memory list)
    {
        uint256 lastIndex = _signers.length();

        list = new address[](lastIndex);

        for (uint256 i = 0; i < lastIndex; i++) {
            list[i] = _signers.at(i);
        }
    }

    function addSigners(address[] calldata signers_) external onlyOwner {
        for (uint256 i = 0; i < signers_.length; i++) {
            _signers.add(signers_[i]);
        }
    }

    function removeSigners(address[] calldata signers_) external onlyOwner {
        for (uint256 i = 0; i < signers_.length; i++) {
            bool res = _signers.remove(signers_[i]);
            require(res, "signer for delete not found");
        }
        require(_signers.length() > 0, "_signers can't be empty");
    }

    function setFeeRecipient(address payable recipient_) external onlyOwner {
        feeRecipient = recipient_;
    }

    function setFeeDistributor(address distributor_) external onlyOwner {
        feeDistributor = distributor_;
    }

    function addSupportedToken(address tokenAddress_, TokenInfo calldata info_)
        external
        onlyOwner
    {
        require(
            info_.fee < MAX_INITIAL_PERCENTAGE,
            "fee is more or equal then 100%"
        );
        TokenInfo storage info = tokensInfo[tokenAddress_];
        info.fee = info_.fee;
        info.needKYC = info_.needKYC;
        info.tokenType = info_.tokenType;
        bool result = _supportedTokens.add(tokenAddress_);
        emit AddSuportedToken(tokenAddress_, info, !result);
    }

    function removeSupportedToken(address tokenAddress_) external onlyOwner {
        require(
            _supportedTokens.remove(tokenAddress_),
            "Token is not supported"
        );
        emit RemoveSupportedToken(tokenAddress_);
    }

    function addLiquidity(address tokenAddress_, uint256 amount_)
        external
        payable
        override
    {
        uint256 amount = _depositeRequire(tokenAddress_, amount_);

        if (!_isNative(tokenAddress_)) {
            IERC20(tokenAddress_).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }

        tokensInfo[tokenAddress_].liquidity += amount;
        userLiquidity[tokenAddress_][msg.sender] += amount;

        emit AddLiquidity(msg.sender, tokenAddress_, amount);
    }

    function withdrawLiquidity(address tokenAddress_, uint256 amount_)
        external
        override
    {
        uint256 liquidityBalance = userLiquidity[tokenAddress_][msg.sender];
        uint256 contractBalance = _isNative(tokenAddress_)
            ? address(this).balance
            : IERC20(tokenAddress_).balanceOf(address(this));

        uint256 availableAmount = liquidityBalance > contractBalance
            ? contractBalance
            : liquidityBalance;

        require(amount_ <= availableAmount && amount_ != 0, "Incorrect amount");

        tokensInfo[tokenAddress_].liquidity -= amount_;
        userLiquidity[tokenAddress_][msg.sender] -= amount_;

        if (_isNative(tokenAddress_)) {
            payable(msg.sender).sendValue(amount_);
        } else {
            IERC20(tokenAddress_).safeTransfer(msg.sender, amount_);
        }

        emit RemoveLiquidity(msg.sender, tokenAddress_, amount_);
    }

    function deposite(
        uint256 chainIdTo_,
        address tokenAddress_,
        uint256 amount_,
        string memory recipient_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external payable override {
        require(_isValidKYC(tokenAddress_, v_, r_, s_), "Not passed KYC");

        uint256 amount = _depositeRequire(tokenAddress_, amount_);
        uint256 feePercentage = tokensInfo[tokenAddress_].fee;

        if (feePercentage > 0) {
            uint256 fee = (amount * feePercentage) / MAX_INITIAL_PERCENTAGE;
            amount -= fee;
            _feeDistribute(tokenAddress_, fee);
        }

        _transferFrom(tokenAddress_, amount);

        emit Deposite(
            msg.sender,
            block.chainid,
            chainIdTo_,
            tokenAddress_,
            amount,
            recipient_
        );
    }

    function withdraw(
        uint256 chainIdFrom_,
        address tokenAddress_,
        uint256 amount_,
        uint256 nonce_,
        uint8[] calldata v_,
        bytes32[] calldata r_,
        bytes32[] calldata s_
    ) external override {
        require(IS_TOKEN_SUPPORTED(tokenAddress_), "Token is not supported");
        require(!_nonces[msg.sender][nonce_], "Invalid nonce");
        require(
            v_.length == r_.length &&
                r_.length == s_.length &&
                s_.length == _signers.length(),
            "Arrays have different lengths"
        );
        bytes32 structHash = keccak256(
            abi.encode(
                _CONTAINER_TYPEHASE,
                msg.sender,
                chainIdFrom_,
                tokenAddress_,
                amount_,
                nonce_
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);

        require(_isValidSigners(digest, v_, r_, s_), "Invalid signers");

        _nonces[msg.sender][nonce_] = true;

        if (_isNative(tokenAddress_)) {
            payable(msg.sender).sendValue(amount_);
        } else if (tokensInfo[tokenAddress_].tokenType == TokenType.ERC20) {
            IERC20(tokenAddress_).safeTransfer(msg.sender, amount_);
        } else {
            IERC20Mintable(tokenAddress_).mint(msg.sender, amount_);
        }

        emit Withdraw(
            msg.sender,
            chainIdFrom_,
            block.chainid,
            tokenAddress_,
            amount_,
            nonce_
        );
    }

    function _feeDistribute(address tokenAddress_, uint256 fee_) internal {
        if (_isNative(tokenAddress_)) {
            feeRecipient.sendValue(fee_);
        } else if (tokensInfo[tokenAddress_].tokenType == TokenType.ERC20) {
            IERC20(tokenAddress_).safeTransferFrom(
                msg.sender,
                feeRecipient,
                fee_
            );
        } else {
            IERC20Mintable(tokenAddress_).mint(feeRecipient, fee_);
        }
        if (feeDistributor != address(0)) {
            IFeeDistributor(feeDistributor).distributeFee(tokenAddress_, fee_);
        }
    }

    function _transferFrom(address tokenAddress_, uint256 amount_) internal {
        TokenType tokenType = tokensInfo[tokenAddress_].tokenType;
        if (_isNative(tokenAddress_)) {
            return;
        } else if (tokenType == TokenType.ERC20) {
            IERC20(tokenAddress_).safeTransferFrom(
                msg.sender,
                address(this),
                amount_
            );
        } else if (tokenType == TokenType.ERC20_MINT_BURN_V2) {
            IERC20Mintable(tokenAddress_).burnFrom(msg.sender, amount_);
        } else {
            IERC20Mintable(tokenAddress_).burn(msg.sender, amount_);
        }
    }

    function _depositeRequire(address tokenAddress_, uint256 amount_)
        internal
        returns (uint256)
    {
        require(IS_TOKEN_SUPPORTED(tokenAddress_), "Token is not supported");

        require(!(msg.value > 0 && amount_ > 0), "Input two amount");

        uint256 amount = _isNative(tokenAddress_) ? msg.value : amount_;

        require(amount > 0, "Amount must be greater than zero");
        return amount;
    }

    function _isValidKYC(
        address tokenAddress_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) internal view returns (bool) {
        if (tokensInfo[tokenAddress_].needKYC) {
            bytes32 structHash = keccak256(
                abi.encode(_CONTAINER_KYC_TYPEHASE, msg.sender)
            );
            bytes32 hash = _hashTypedDataV4(structHash);
            address messageSigner = ECDSA.recover(hash, v_, r_, s_);
            return messageSigner == _signers.at(0);
        }
        return true;
    }

    function _isValidSigners(
        bytes32 digest_,
        uint8[] calldata v_,
        bytes32[] calldata r_,
        bytes32[] calldata s_
    ) internal view returns (bool) {
        for (uint256 i = 0; i < v_.length; i++) {
            address messageSigner = ECDSA.recover(digest_, v_[i], r_[i], s_[i]);
            if (messageSigner != _signers.at(i)) {
                return false;
            }
        }
        return true;
    }

    function _isNative(address tokenAddress_) internal pure returns (bool) {
        return tokenAddress_ == NATIVE;
    }
}