pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "./IWETH.sol";
import "./Withdrawable.sol";
import "./Claim.sol";

pragma experimental ABIEncoderV2;

contract Erc20Vault is Withdrawable, IERC777Recipient, claimToken {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC1820Registry private constant _erc1820 =
        IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH =
        keccak256("ERC777TokensRecipient");
    bytes32 private constant ERC777_TOKEN_INTERFACE_HASH =
        keccak256("ERC777Token");

    EnumerableSet.AddressSet private supportedTokens;
    address public PNETWORK;
    IWETH public weth;
    // claimToken public claimAction;

    event JoinPool(
        address _tokenAddress,
        address _tokenSender,
        uint256 _tokenAmount,
        string _destinationAddress,
        string _tokenSymbol, //tokensymbol raw uint64 instead?
        uint8 _tokenDecimals,
        uint64 _poolID,
        uint8 _fromChainID,
        uint8 _toChainID,
        bytes _userData
    );

    struct userDataERC777 {
        bytes32 tag;
        string destinationAddress;
        uint64 poolID;
        uint8 toChainID;
    }

    constructor(address _weth, address[] memory _tokensToSupport) public {
        PNETWORK = msg.sender;
        for (uint256 i = 0; i < _tokensToSupport.length; i++) {
            supportedTokens.add(_tokensToSupport[i]);
        }
        weth = IWETH(_weth);
        _erc1820.setInterfaceImplementer(
            address(this),
            TOKENS_RECIPIENT_INTERFACE_HASH,
            address(this)
        );
    }

    receive() external payable {
        require(msg.sender == address(weth));
    }

    function setWeth(address _weth) external onlyPNetwork {
        weth = IWETH(_weth);
    }

    function setPNetwork(address _pnetwork) external onlyPNetwork {
        require(
            _pnetwork != address(0),
            "Cannot set the zero address as the pNetwork address!"
        );
        PNETWORK = _pnetwork;
    }

    function IS_TOKEN_SUPPORTED(address _token) external view returns (bool) {
        return supportedTokens.contains(_token);
    }

    function _owner() internal override returns (address) {
        return PNETWORK;
    }

    function adminWithdrawAllowed(address asset)
        internal
        view
        override
        returns (uint256)
    {
        return
            supportedTokens.contains(asset)
                ? 0
                : super.adminWithdrawAllowed(asset);
    }

    function addSupportedToken(address _tokenAddress)
        external
        onlyPNetwork
        returns (bool SUCCESS)
    {
        supportedTokens.add(_tokenAddress);
        return true;
    }

    function removeSupportedToken(address _tokenAddress)
        external
        onlyPNetwork
        returns (bool SUCCESS)
    {
        return supportedTokens.remove(_tokenAddress);
    }

    function getSupportedTokens() external view returns (address[] memory res) {
        res = new address[](supportedTokens.length());
        for (uint256 i = 0; i < supportedTokens.length(); i++) {
            res[i] = supportedTokens.at(i);
        }
    }

    function pegIn(
        uint256 _tokenAmount,
        address _tokenAddress,
        string calldata _destinationAddress,
        uint64 _poolID,
        uint8 _toChainID
    ) external returns (bool) {
        return
            pegIn(
                _tokenAmount,
                _tokenAddress,
                _destinationAddress,
                _poolID,
                _toChainID,
                ""
            );
    }

    function pegIn(
        uint256 _tokenAmount,
        address _tokenAddress,
        string memory _destinationAddress,
        uint64 _poolID,
        uint8 _toChainID,
        bytes memory _userData
    ) public returns (bool) {
        require(
            supportedTokens.contains(_tokenAddress),
            "Token at supplied address is NOT supported!"
        );
        require(_tokenAmount > 0, "Token amount must be greater than zero!");
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
        string memory _tokenSymbol = ERC20(_tokenAddress).symbol();
        uint8 _tokenDecimals = ERC20(_tokenAddress).decimals();
        emit JoinPool(
            _tokenAddress,
            msg.sender,
            _tokenAmount,
            _destinationAddress,
            _tokenSymbol,
            _tokenDecimals,
            _poolID,
            thisChainId,
            _toChainID,
            _userData
        );
        return true;
    }

    /**
     * @dev Implementation of IERC777Recipient.
     */
    function tokensReceived(
        address, /*operator*/
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata /*operatorData*/
    ) external override {
        address _tokenAddress = msg.sender;
        require(
            supportedTokens.contains(_tokenAddress),
            "caller is not a supported ERC777 token!"
        );
        require(to == address(this), "Token receiver is not this contract");
        if (userData.length > 0) {
            require(amount > 0, "Token amount must be greater than zero!");
            userDataERC777 memory decodedUserData = decodeUserData(userData);
            require(
                decodedUserData.tag == keccak256("ERC777-pegIn"),
                "Invalid tag for automatic pegIn on ERC777 send"
            );
            emit JoinPool(
                _tokenAddress,
                from,
                amount,
                decodedUserData.destinationAddress,
                ERC20(_tokenAddress).symbol(),
                ERC20(_tokenAddress).decimals(),
                decodedUserData.poolID,
                thisChainId,
                decodedUserData.toChainID,
                userData
            );
        }
    }

    // abi decode function
    function decodeUserData(bytes memory userData)
        internal
        view
        returns (userDataERC777 memory)
    {
        userDataERC777 memory decodedUserData;
        (
            bytes32 tag,
            string memory _destinationAddress,
            uint64 _poolID,
            uint8 _toChainID
        ) = abi.decode(userData, (bytes32, string, uint64, uint8));
        decodedUserData.tag = tag;
        decodedUserData.destinationAddress = _destinationAddress;
        decodedUserData.poolID = _poolID;
        decodedUserData.toChainID = _toChainID;
        return decodedUserData;
    }

    function pegInEth(
        string calldata _destinationAddress,
        uint64 _poolID,
        uint8 _toChainID
    ) external payable returns (bool) {
        return pegInEth(_destinationAddress, _poolID, _toChainID, "");
    }

    function pegInEth(
        string memory _destinationAddress,
        uint64 _poolID,
        uint8 _toChainID,
        bytes memory _userData
    ) public payable returns (bool) {
        require(
            supportedTokens.contains(address(weth)),
            "WETH is NOT supported!"
        );
        require(msg.value > 0, "Ethers amount must be greater than zero!");
        string memory _tokenSymbol = ERC20(address(weth)).symbol();
        uint8 _tokenDecimals = ERC20(address(weth)).decimals();
        weth.deposit.value(msg.value)();
        emit JoinPool(
            address(weth),
            msg.sender,
            msg.value,
            _destinationAddress,
            _tokenSymbol,
            _tokenDecimals,
            _poolID,
            thisChainId,
            _toChainID,
            _userData
        );
        return true;
    }

    function pegOutWeth(
        address payable _tokenRecipient,
        uint256 _tokenAmount,
        bytes memory _userData
    ) internal returns (bool) {
        weth.withdraw(_tokenAmount);
        // NOTE: This is the latest recommendation (@ time of writing) for transferring ETH. This no longer relies
        // on the provided 2300 gas stipend and instead forwards all available gas onwards.
        // SOURCE: https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now
        (bool success, ) = _tokenRecipient.call.value(_tokenAmount)(_userData);
        require(success, "ETH transfer failed when pegging out wETH!");
    }

    function pegOut(
        address payable _tokenRecipient,
        address _tokenAddress,
        uint256 _tokenAmount
    ) public onlyPNetwork returns (bool) {
        if (_tokenAddress == address(weth)) {
            pegOutWeth(_tokenRecipient, _tokenAmount, "");
        } else {
            IERC20(_tokenAddress).safeTransfer(_tokenRecipient, _tokenAmount);
        }
        return true;
    }

    function pegOut(
        address payable _tokenRecipient,
        address _tokenAddress,
        uint256 _tokenAmount,
        bytes calldata _userData
    ) external onlyPNetwork returns (bool) {
        if (_tokenAddress == address(weth)) {
            pegOutWeth(_tokenRecipient, _tokenAmount, _userData);
        } else {
            address erc777Address = _erc1820.getInterfaceImplementer(
                _tokenAddress,
                ERC777_TOKEN_INTERFACE_HASH
            );
            if (erc777Address == address(0)) {
                return pegOut(_tokenRecipient, _tokenAddress, _tokenAmount);
            } else {
                IERC777(erc777Address).send(
                    _tokenRecipient,
                    _tokenAmount,
                    _userData
                );
                return true;
            }
        }
    }

    function migrate(address payable _to) external onlyPNetwork {
        uint256 numberOfTokens = supportedTokens.length();
        for (uint256 i = 0; i < numberOfTokens; i++) {
            address tokenAddress = supportedTokens.at(0);
            _migrateSingle(_to, tokenAddress);
        }
    }

    function destroy() external onlyPNetwork {
        for (uint256 i = 0; i < supportedTokens.length(); i++) {
            address tokenAddress = supportedTokens.at(i);
            require(
                IERC20(tokenAddress).balanceOf(address(this)) == 0,
                "Balance of supported tokens must be 0"
            );
        }
        selfdestruct(msg.sender);
    }

    function migrateSingle(address payable _to, address _tokenAddress)
        external
        onlyPNetwork
    {
        _migrateSingle(_to, _tokenAddress);
    }

    function _migrateSingle(address payable _to, address _tokenAddress)
        private
    {
        if (supportedTokens.contains(_tokenAddress)) {
            uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
            IERC20(_tokenAddress).safeTransfer(_to, balance);
            supportedTokens.remove(_tokenAddress);
        }
    }

    function claim(bytes memory sigData, bytes[] memory signatures)
        external
        returns (bool)
    {
        // require(false,"Before claim");
        //Emit the event
        TeleportData memory td = claimAction(sigData, signatures);
        require(
            supportedTokens.contains(td.tokenAddress),
            "Token is not supported"
        );
        // TODO require the toAddress is the same as the one in the event
        uint256 precision = ERC20(td.tokenAddress).decimals() -
            td.nativeDecimals;
        uint256 quantity = td.quantity * 10**precision;

        // //Receive funds
        if (td.tokenAddress == address(weth)) {
            pegOutWeth(payable(td.toAddress), quantity, "");
        } else {
            IERC20(td.tokenAddress).safeTransfer(td.toAddress, quantity);
        }
        claimed[td.id] = true;

        emit Claimed(td.id, td.toAddress, td.tokenAddress, quantity);

        return true;
    }
}