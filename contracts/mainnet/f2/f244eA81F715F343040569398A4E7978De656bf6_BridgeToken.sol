// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.11;

// ============ Internal Imports ============
import {IBridgeToken} from "../../interfaces/bridge/IBridgeToken.sol";
import {ERC20} from "./vendored/OZERC20.sol";
// ============ External Imports ============
import {Version0} from "@celo-org/optics-sol/contracts/Version0.sol";
import {TypeCasts} from "@celo-org/optics-sol/contracts/XAppConnectionManager.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BridgeToken is Version0, IBridgeToken, OwnableUpgradeable, ERC20 {
    // ============ Immutables ============

    // Immutables used in EIP 712 structured data hashing & signing
    // https://eips.ethereum.org/EIPS/eip-712
    bytes32 public immutable _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
    bytes32 private immutable _EIP712_STRUCTURED_DATA_VERSION =
        keccak256(bytes("1"));
    uint16 private immutable _EIP712_PREFIX_AND_VERSION = uint16(0x1901);

    // ============ Public Storage ============

    mapping(address => uint256) public nonces;

    // ============ Upgrade Gap ============

    uint256[49] private __GAP; // gap for upgrade safety

    // ============ Initializer ============

    function initialize() public override initializer {
        __Ownable_init();
    }

    // ============ External Functions ============

    /**
     * @notice Destroys `_amnt` tokens from `_from`, reducing the
     * total supply.
     * @dev Emits a {Transfer} event with `to` set to the zero address.
     * Requirements:
     * - `_from` cannot be the zero address.
     * - `_from` must have at least `_amnt` tokens.
     * @param _from The address from which to destroy the tokens
     * @param _amnt The amount of tokens to be destroyed
     */
    function burn(address _from, uint256 _amnt) external override onlyOwner {
        _burn(_from, _amnt);
    }

    /** @notice Creates `_amnt` tokens and assigns them to `_to`, increasing
     * the total supply.
     * @dev Emits a {Transfer} event with `from` set to the zero address.
     * Requirements:
     * - `to` cannot be the zero address.
     * @param _to The destination address
     * @param _amnt The amount of tokens to be minted
     */
    function mint(address _to, uint256 _amnt) external override onlyOwner {
        _mint(_to, _amnt);
    }

    /**
     * @notice Set the details of a token
     * @param _newName The new name
     * @param _newSymbol The new symbol
     * @param _newDecimals The new decimals
     */
    function setDetails(
        string calldata _newName,
        string calldata _newSymbol,
        uint8 _newDecimals
    ) external override onlyOwner {
        // careful with naming convention change here
        token.name = _newName;
        token.symbol = _newSymbol;
        token.decimals = _newDecimals;
    }

    /**
     * @notice Sets approval from owner to spender to value
     * as long as deadline has not passed
     * by submitting a valid signature from owner
     * Uses EIP 712 structured data hashing & signing
     * https://eips.ethereum.org/EIPS/eip-712
     * @param _owner The account setting approval & signing the message
     * @param _spender The account receiving approval to spend owner's tokens
     * @param _value The amount to set approval for
     * @param _deadline The timestamp before which the signature must be submitted
     * @param _v ECDSA signature v
     * @param _r ECDSA signature r
     * @param _s ECDSA signature s
     */
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        require(block.timestamp <= _deadline, "ERC20Permit: expired deadline");
        require(_owner != address(0), "ERC20Permit: owner zero address");
        uint256 _nonce = nonces[_owner];
        bytes32 _hashStruct = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                _owner,
                _spender,
                _value,
                _nonce,
                _deadline
            )
        );
        bytes32 _digest = keccak256(
            abi.encodePacked(
                _EIP712_PREFIX_AND_VERSION,
                domainSeparator(),
                _hashStruct
            )
        );
        address _signer = ecrecover(_digest, _v, _r, _s);
        require(_signer == _owner, "ERC20Permit: invalid signature");
        nonces[_owner] = _nonce + 1;
        _approve(_owner, _spender, _value);
    }

    // ============ Public Functions ============

    /**
     * @dev silence the compiler being dumb
     */
    function balanceOf(address _account)
        public
        view
        override(IBridgeToken, ERC20)
        returns (uint256)
    {
        return ERC20.balanceOf(_account);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return token.name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view override returns (string memory) {
        return token.symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view override returns (uint8) {
        return token.decimals;
    }

    /**
     * @dev This is ALWAYS calculated at runtime
     * because the token name may change
     */
    function domainSeparator() public view returns (bytes32) {
        uint256 _chainId;
        assembly {
            _chainId := chainid()
        }
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(token.name)),
                    _EIP712_STRUCTURED_DATA_VERSION,
                    _chainId,
                    address(this)
                )
            );
    }
}