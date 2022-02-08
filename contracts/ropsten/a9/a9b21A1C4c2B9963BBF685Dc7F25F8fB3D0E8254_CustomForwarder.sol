// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CustomForwarder is EIP712, AccessControl {
    bytes32 public constant RELAYER = keccak256("RELAYER");
    using ECDSA for bytes32;

    struct ForwardRequest {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 nonce;
        bytes data;
    }

    bytes32 private constant _TYPEHASH =
        keccak256(
            "ForwardRequest(address from,address to,uint256 value,uint256 nonce)"
        );

    mapping(address => uint256) private _nonces;

    /**
     * @dev Constructor for CustomForwarder contract
     */
    constructor() EIP712("MinimalForwarder", "0.0.1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(RELAYER, msg.sender);
    }

    /**
     @dev modifier to check if the sender is the Relayer
     * Revert if the sender is not the relayer
     */
    modifier onlyRelayer() {
        require(
            hasRole(RELAYER, msg.sender),
            "CF: Only relayer"
        );
        _;
    }

    /**
     * @dev Public function to get nonce for particular address
     * @param from address for which nonce will be retrieved
     */
    function getNonce(address from) public view returns (uint256) {
        return _nonces[from];
    }


    /**
     * @dev Public function to verify signature authenticity and nonce for particular address
     * @param req ForwardRequest structure variable consisting required details for verification
     * @param signature bytes of data used to verify original request sender
     */
    function verify(ForwardRequest calldata req, bytes calldata signature)
        public
        view
        returns (bool)
    {
        address signer = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _TYPEHASH,
                    req.from,
                    req.to,
                    req.value,
                    //req.gas,
                    req.nonce
                    //keccak256(req.data)
                )
            )
        ).recover(signature);
        return _nonces[req.from] == req.nonce && signer == req.from;
    }

    /**
     * @dev Public payable function to verify the call and make call to required function
     * @param req ForwardRequest structure variable consisting required details for verification
     * @param signature bytes of data used to verify original request sender
     */
    function execute(ForwardRequest calldata req, bytes calldata signature)
        public
        payable
        onlyRelayer
        returns (bool, bytes memory)
    {
        require(
            verify(req, signature),
            "CF: signature does not match request"
        );
        _nonces[req.from] = req.nonce + 1;

        (bool success, bytes memory returndata) = req.to.call{
            gas: req.gas,
            value: req.value
        }(abi.encodePacked(req.data, req.from));
        // Validate that the relayer has sent enough gas for the call.
        // See https://ronan.eth.link/blog/ethereum-gas-dangers/
        assert(gasleft() > req.gas / 63);

        return (success, returndata);
    }
}