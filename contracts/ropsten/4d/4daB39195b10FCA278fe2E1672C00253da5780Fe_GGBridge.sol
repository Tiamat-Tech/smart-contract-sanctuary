pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IERC20Mintable.sol";
import "./interfaces/IFeeDistributor.sol";

contract GGBridge is EIP712, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address payable;

    enum TokenType {
        ERC20,
        ERC20_MINT_BURN,
        ERC20_MINT_BURN_V2
    }

    struct TokenInfo {
        bool needKYC;
        uint256 fee;
        TokenType tokenType;
        uint256 liquidity;
    }

    uint256 private constant MAX_INITIAL_PERCENTAGE = 1e20;
    address private constant NATIVE = address(0);
    bytes32 private constant _CONTAINER_TYPEHASE =
        keccak256(
            "Container(address sender,uint256 chainIdFrom,address token,uint256 amount,uint256 nonce)"
        );
    bytes32 private constant _CONTAINER_KYC_TYPEHASE =
        keccak256("KycContainer(address sender)");

    address private _signer;

    mapping(address => mapping(uint256 => bool)) private _nonces;
    EnumerableSet.AddressSet private supportedTokens;

    mapping(address => TokenInfo) public tokensInfo;

    address payable public feeRecipient;
    address public feeDistributor;

    event Deposite(
        address indexed sender,
        uint256 chainIdFrom,
        uint256 chainIdTo,
        address token,
        uint256 amount,
        string recipient
    );
    event Withdraw(
        address indexed sender,
        uint256 chainIdFrom,
        uint256 chainIdTo,
        address token,
        uint256 amount,
        uint256 nonce
    );
    event AddSuportedToken(address indexed token, TokenInfo info);
    event RemoveSupportedToken(address indexed token);
    event LogWithdrawToken(
        address indexed from,
        address indexed token,
        uint256 amount
    );

    constructor(
        address signer_,
        address[] memory tokensToSupport_,
        TokenInfo[] memory tokensInfo_
    ) EIP712("GGBridge", "v1") {
        _signer = signer_;
        for (uint256 i = 0; i < tokensToSupport_.length; i++) {
            address tokenAddress = tokensToSupport_[i];
            TokenInfo memory info = tokensInfo_[i];

            require(info.fee < MAX_INITIAL_PERCENTAGE, "Fee is incorrect");
            require(info.liquidity == 0, "Liquidity is incorrect");
            supportedTokens.add(tokenAddress);
            tokensInfo[tokenAddress] = info;

            emit AddSuportedToken(tokensToSupport_[i], info);
        }
    }

    function IS_TOKEN_SUPPORTED(address tokenAddress_)
        external
        view
        returns (bool)
    {
        return supportedTokens.contains(tokenAddress_);
    }

    function getSupportedTokens() external view returns (address[] memory res) {
        uint256 lastIndex = supportedTokens.length();

        res = new address[](lastIndex);

        for (uint256 i = 0; i < lastIndex; i++) {
            res[i] = supportedTokens.at(i);
        }
    }

    function setSigner(address signer_) external onlyOwner {
        _signer = signer_;
    }

    function setFeeRecipient(address payable recipient_) external onlyOwner {
        feeRecipient = recipient_;
    }

    function setFeeDistributor(address distributor_) external onlyOwner {
        feeDistributor = distributor_;
    }

    function addLiquidity(address tokenAddress_, uint256 amount_)
        external
        payable
    {
        require(!(msg.value > 0 && amount_ > 0), "Input two amount");

        uint256 amount = tokenAddress_ == NATIVE ? msg.value : amount_;

        require(amount > 0, "Amount must be greater than zero");
        if (tokenAddress_ != NATIVE) {
            IERC20(tokenAddress_).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
        tokensInfo[tokenAddress_].liquidity += amount;
    }

    function adminWithdraw(address tokenAddress_) external onlyOwner {
        uint256 tokenBalance = tokenAddress_ == NATIVE
            ? address(this).balance
            : IERC20(tokenAddress_).balanceOf(address(this));

        TokenInfo storage info = tokensInfo[tokenAddress_];

        uint256 initialValue = info.liquidity > tokenBalance
            ? tokenBalance
            : info.liquidity;

        if (tokenAddress_ == NATIVE) {
            payable(msg.sender).sendValue(initialValue);
        } else {
            IERC20(tokenAddress_).safeTransfer(msg.sender, initialValue);
        }

        info.liquidity -= initialValue;

        emit LogWithdrawToken(msg.sender, tokenAddress_, initialValue);
    }

    function addSupportedToken(address tokenAddress_, TokenInfo calldata info_)
        external
        onlyOwner
        returns (bool success)
    {
        require(info_.fee < MAX_INITIAL_PERCENTAGE, "Fee is incorrect");
        require(info_.liquidity == 0, "Liquidity is incorrect");

        tokensInfo[tokenAddress_] = info_;
        emit AddSuportedToken(tokenAddress_, info_);

        return supportedTokens.add(tokenAddress_);
    }

    function removeSupportedToken(address tokenAddress_)
        external
        onlyOwner
        returns (bool success)
    {
        if (!supportedTokens.contains(tokenAddress_)) return false;
        delete tokensInfo[tokenAddress_];
        emit RemoveSupportedToken(tokenAddress_);
        return supportedTokens.remove(tokenAddress_);
    }

    function deposite(
        uint256 chainIdTo_,
        address tokenAddress_,
        uint256 amount_,
        string memory recipient_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external payable {
        require(_isValidKYC(tokenAddress_, v_, r_, s_), "Invalid signer");

        uint256 amount = _depositeRequire(tokenAddress_, amount_);

        TokenInfo storage info = tokensInfo[tokenAddress_];
        uint256 fee = info.fee > 0
            ? (amount * info.fee) / MAX_INITIAL_PERCENTAGE
            : 0;

        _transferFrom(tokenAddress_, info.tokenType, fee, amount);

        amount -= fee;

        if (fee > 0 && feeDistributor != address(0)) {
            IFeeDistributor(feeDistributor).distributeFee(tokenAddress_, fee);
        }

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
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        require(!_nonces[msg.sender][nonce_], "Invalid nonce");
        require(
            _isValidSigner(
                chainIdFrom_,
                tokenAddress_,
                amount_,
                nonce_,
                v_,
                r_,
                s_
            ),
            "Invalid signer"
        );

        _nonces[msg.sender][nonce_] = true;

        if (tokenAddress_ == NATIVE) {
            payable(msg.sender).sendValue(amount_);
        } else {
            if (TokenType.ERC20 == tokensInfo[tokenAddress_].tokenType) {
                IERC20(tokenAddress_).safeTransfer(msg.sender, amount_);
            } else {
                IERC20Mintable(tokenAddress_).mint(msg.sender, amount_);
            }
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

    function _transferFrom(
        address tokenAddress_,
        TokenType type_,
        uint256 fee_,
        uint256 amount_
    ) internal {
        if (type_ == TokenType.ERC20 && tokenAddress_ != NATIVE) {
            IERC20(tokenAddress_).safeTransferFrom(
                msg.sender,
                address(this),
                amount_
            );
        } else if (type_ == TokenType.ERC20_MINT_BURN_V2) {
            IERC20Mintable(tokenAddress_).burnFrom(msg.sender, amount_);
        } else if (type_ == TokenType.ERC20_MINT_BURN) {
            IERC20Mintable(tokenAddress_).burn(msg.sender, amount_);
        }

        if (fee_ > 0) {
            if (tokenAddress_ == NATIVE) {
                feeRecipient.sendValue(fee_);
            } else if (type_ == TokenType.ERC20) {
                IERC20(tokenAddress_).safeTransfer(feeRecipient, fee_);
            } else {
                IERC20Mintable(tokenAddress_).mint(feeRecipient, fee_);
            }
        }
    }

    function _depositeRequire(address tokenAddress_, uint256 amount_)
        internal
        returns (uint256)
    {
        require(
            supportedTokens.contains(tokenAddress_),
            "Token at supplied address is NOT supported"
        );

        require(!(msg.value > 0 && amount_ > 0), "Input two amount");

        uint256 amount = tokenAddress_ == NATIVE ? msg.value : amount_;

        require(amount > 0, "Amount must be greater than zero");
        return amount;
    }

    function _isValidKYC(
        address tokenAddress_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) internal view returns (bool) {
        TokenInfo memory info = tokensInfo[tokenAddress_];
        if (info.needKYC) {
            bytes32 structHash = keccak256(
                abi.encode(_CONTAINER_KYC_TYPEHASE, msg.sender)
            );
            bytes32 hash = _hashTypedDataV4(structHash);
            address messageSigner = ECDSA.recover(hash, v_, r_, s_);
            return messageSigner == _signer;
        }
        return true;
    }

    function _isValidSigner(
        uint256 chainIdFrom_,
        address token_,
        uint256 amount_,
        uint256 nonce_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) internal view returns (bool) {
        bytes32 structHash = keccak256(
            abi.encode(
                _CONTAINER_TYPEHASE,
                msg.sender,
                chainIdFrom_,
                token_,
                amount_,
                nonce_
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address messageSigner = ECDSA.recover(hash, v_, r_, s_);
        return messageSigner == _signer;
    }
}