pragma solidity ^0.7.6;
pragma abicoder v2;

import "./../tokens/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/introspection/ERC165Upgradeable.sol";
import "./../tokens/@rarible/libraries/contracts/LibSignature.sol";
import "./../tokens/erc-1271/ERC1271.sol";
import "./IAuctioneerUpgradeable.sol";
import "./LibAuctioneer.sol";
import "./RolesValidator.sol";

contract AuctioneerUpgradable is ERC1271, OwnableUpgradeable, ERC165Upgradeable, IAuctioneerUpgradeable, RolesValidator {

    using LibSignature for bytes32;
    using AddressUpgradeable for address;

    struct Auctioneer {
        bool active;
        uint96 fee;
        uint256 cancelValue;
        uint256 start;
        uint256 end;
    }

    // bytes4 constant public ERC1271_INTERFACE_ID = 0xfb855dc9; // this.isValidSignature.selector

    // bytes4 constant public ERC1271_RETURN_VALID_SIGNATURE =   0x1626ba7e;
    // bytes4 constant public ERC1271_RETURN_INVALID_SIGNATURE = 0x00000000;

    // Default auctioneers
    mapping(address => Auctioneer) private defaults;

    // Creator approved auctioneers
    mapping(address => mapping(address => mapping(address => Auctioneer))) private auctioneers;

    uint256 public registrationFee;
    mapping(address => bool) public registered;
    mapping(address => bool) public banned;


    function __AuctioneerUpgradable_init (address _auctioneer, uint96 _fee) public initializer {
        __Ownable_init();
        __ERC165_init_unchained();
        _registerInterface(ERC1271_INTERFACE_ID);
        upsertDefault(_auctioneer, _fee, true);
    }

    function upsertDefault(address _auctioneer, uint96 _fee, bool active ) public onlyOwner {
        defaults[_auctioneer] = Auctioneer(active, _fee, 0, 0, 0);
    }

    function getDefault(address _auctioneer) external view returns (Auctioneer memory) {
        return defaults[_auctioneer];
    }

    function getDefaultFee(address _auctioneer) public view returns (uint96) {
        return defaults[_auctioneer].fee;
    }

    function setRegistrationFee(uint256 _registrationFee)
        external
        virtual
        onlyOwner
    {
        registrationFee = _registrationFee;
    }


    function register() external payable virtual {
        require(msg.value == registrationFee, "Registration fee");
        registered[_msgSender()] = true;
    }

    function ban(address _auctioneer, bool _isBanned) external virtual onlyOwner {
        banned[_auctioneer] = _isBanned;

    }

    // Auctioneer needs to get the form signed by the creator and submits to the contract
    function upsert(address _token, LibAuctioneer.Auctioneer memory data) public virtual {
        
        require(registered[data.auctioneer], "Not registered");
        require(!banned[data.auctioneer], "Banned");

        bytes32 hash = LibAuctioneer.hash(data);

        // Check if auctioneer and minter gave signature
        validate(data.auctioneer, hash, data.signatures[0]);
        validate(data.minter, hash, data.signatures[1]);

        auctioneers[_token][data.minter][data.auctioneer] = Auctioneer(
            true,
            data.fee,
            data.cancelValue,
            data.start,
            data.end
        );
    }

    function cancel(address _token, address _auctioneer) public payable virtual {
        require(
            msg.value == auctioneers[_token][_msgSender()][_auctioneer].cancelValue,
            "Cancel charge"
        );
        delete auctioneers[_token][_msgSender()][_auctioneer];
    }

    function get(address _token, address _minter, address _auctioneer)
        public
        view
        virtual
        returns (Auctioneer memory)
    {
        return auctioneers[_token][_minter][_auctioneer];
    }

    function getFee(address _token, address _minter, address _signer)
        public
        view
        virtual
        override
        returns (uint96)
    {

        // Allowing self signed
        if (_signer == _minter) return 0;
        require(!banned[_signer], "Banned");

        if(auctioneers[_token][_minter][_signer].active
            && block.timestamp >= auctioneers[_token][_minter][_signer].start
            && block.timestamp <= auctioneers[_token][_minter][_signer].end){
                return auctioneers[_token][_minter][_signer].fee;
        }

        // If minter is default minter
        if (defaults[_signer].active) return getDefaultFee(_signer);

        revert("No auctioneer");
    }




    /**
    * @dev Function must be implemented by deriving contract
    * @param _hash Arbitrary length data signed on the behalf of address(this)
    * @param _signature Signature byte array associated with _data
    * @return A bytes4 magic value 0x1626ba7e if the signature check passes, 0x00000000 if not
    *
    * MUST NOT modify state (using STATICCALL for solc < 0.5, view modifier for solc > 0.5)
    * MUST allow external calls
    */
    function isValidSignature(bytes32 _hash, bytes memory _signature) public virtual override view returns (bytes4){

        address signerFromSig;
        if (_signature.length == 65) {
            signerFromSig = _hash.recover(_signature);
            if (defaults[signerFromSig].active) {
                return returnIsValidSignatureMagicNumber(true);
            }
        }
        return returnIsValidSignatureMagicNumber(false);

    }

    // function returnIsValidSignatureMagicNumber(bool isValid) internal pure returns (bytes4) {
    //     return isValid ? ERC1271_RETURN_VALID_SIGNATURE : ERC1271_RETURN_INVALID_SIGNATURE;
    // }

    function releaseFunds() public onlyOwner {
        AddressUpgradeable.sendValue(payable(owner()), address(this).balance);
    }

    uint256[50] private __gap;

}