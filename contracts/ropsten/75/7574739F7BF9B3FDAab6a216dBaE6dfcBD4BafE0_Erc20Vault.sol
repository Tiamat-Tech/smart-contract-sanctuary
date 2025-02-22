pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "./IWETH.sol";
import "./Withdrawable.sol";
import "./Owner.sol";
import "./claim.sol";


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
    uint8 fromChainID = 1;

    event JoinPool(
        address _tokenAddress,
        address _tokenSender,
        uint256 _tokenAmount,
        string _destinationAddress,
        string _tokenSymbol, //tokensymbol raw uint64 instead?
        uint8 _tokenDecimals,
        uint64 _poolID,
        uint8 _fromChainID,
        uint8 _toChainID
    );

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

    // modifier onlyPNetwork() {
    //     require(msg.sender == PNETWORK, "Caller must be PNETWORK address!");
    //     _;
    // }

    receive() external payable {
        require(msg.sender == address(weth));
    }

    function setFromChainID(uint8 _fromChainID) public onlyPNetwork {
        fromChainID = _fromChainID;
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

    // function pegIn(
    //     uint256 _tokenAmount,
    //     address _tokenAddress,
    //     string calldata _destinationAddress
    // ) external returns (bool) {
    //     return pegIn(_tokenAmount, _tokenAddress, _destinationAddress, "");
    // }

    function pegIn(
        uint256 _tokenAmount,
        address _tokenAddress,
        string memory _destinationAddress,
        uint64 _poolID,
        uint8 _toChainID
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
            fromChainID,
            _toChainID
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
            (bytes32 tag, string memory _destinationAddress) = abi.decode(
                userData,
                (bytes32, string)
            );
            require(
                tag == keccak256("ERC777-pegIn"),
                "Invalid tag for automatic pegIn on ERC777 send"
            );
            // emit JoinPool(
            //     _tokenAddress,
            //     from,
            //     amount,
            //     _destinationAddress,
            //     userData
            // );
        }
    }

    // function pegInEth(string calldata _destinationAddress)
    //     external
    //     payable
    //     returns (bool)
    // {
    //     return pegInEth(_destinationAddress, "");
    // }

    function pegInEth(
        string memory _destinationAddress,
        uint64 _poolID,
        uint8 _toChainID
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
            fromChainID,
            _toChainID
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

    // function claim(bytes calldata sigData, bytes[] calldata signatures)
    //     external
    //     returns ( uint64 _ID,
    //         address _tokenRecipient,
    //         address _tokenAddress,
    //         uint64 _tokenAmount)
    // {
    //     // require(false,"Before claim");
    //     //Emit the event
    //     (
    //         uint64 _ID,
    //         address _tokenRecipient,
    //         address _tokenAddress,
    //         uint64 _tokenAmount
    //     ) = claimAction.claim(sigData, signatures);
    //     require(false,"After claim");
    //     //Receive funds
    //     return (_ID,_tokenRecipient,_tokenAddress,_tokenAmount);
    //     // if (_tokenAddress == address(weth)) {
    //     //     pegOutWeth(payable(_tokenRecipient), _tokenAmount, "");
    //     // } else {
    //     //     IERC20(_tokenAddress).safeTransfer(_tokenRecipient, _tokenAmount);
    //     // }
    //     // emit Claimed(_ID, _tokenAddress, _tokenAmount);
    //     // return true;
    // }


    
}