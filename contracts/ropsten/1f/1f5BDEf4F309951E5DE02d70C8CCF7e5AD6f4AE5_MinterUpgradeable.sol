pragma solidity ^0.7.6;
pragma abicoder v2;

import "./../tokens/@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./../tokens/@openzeppelin/contracts-upgradeable/introspection/ERC165Upgradeable.sol";
import "./../tokens/@rarible/libraries/contracts/LibSignature.sol";
import "./../tokens/erc-1271/ERC1271.sol";
import "./IMinterUpgradeable.sol";
import "./LibMinter.sol";
import "./RolesValidator.sol";
import "../tokens/@rarible/royalties/contracts/LibPart.sol";
import "./../tokens/SplitPayments.sol";

contract MinterUpgradeable is ERC1271, OwnableUpgradeable, ERC165Upgradeable, IMinterUpgradeable, RolesValidator {

    using LibSignature for bytes32;
    using AddressUpgradeable for address;

    struct Minter {
        bool active;
        uint96 fee;
        uint256 cancelValue;
        uint256 start;
        uint256 end;
        LibPart.Part[] creators;    // No need to create splitter for creator payouts
        bytes32 royalties;          // Creating a splitter to allow for EIP 2981
    }

    struct DefaultMinter {
        bool active;
        uint96 fee;
        uint256 cancelValue;
        uint256 start;
        uint256 end;
    }

    // bytes4 constant public ERC1271_INTERFACE_ID = 0xfb855dc9; // this.isValidSignature.selector

    // bytes4 constant public ERC1271_RETURN_VALID_SIGNATURE =   0x1626ba7e;
    // bytes4 constant public ERC1271_RETURN_INVALID_SIGNATURE = 0x00000000;

    // Store the royalty stakes from the wallets
    mapping(address => uint256) public stake;

    // Default minter
    // address private minter;
    // uint96 private fee;
    mapping(address => uint256) private defaults;
    // Creator approved minters
    mapping(address => mapping(address => mapping(address => uint256))) private minters;

    // Minters registry
    DefaultMinter[] public defaultsRegistry;
    Minter[] public mintersRegistry;

    // To map created payment splitters with their definition, used for custom minters
    address public splitterImplementationContract;
    mapping (bytes32 => LibPart.Part) public splitters;

    // Maps splitter address to whom the staked amount should go to
    mapping (address => LibPart.Part[]) public withdrawSplits;
    // Overall percentage basis points excluding the minter contract
    mapping (address => uint96) public depositBPS;

    // Mapping from creator to payment splitter for default royalties
    mapping (address => mapping(address => LibPart.Part[] )) public defaultPayoutMapping;
    mapping (address => mapping(address => bytes32)) public defaultRoyaltySplittersMapping;

    // Minimum royalty for using the default signer
    uint96 public minDefaultMinterRoyalty;

    LibPart.Part[] private placeholder;

    function __MinterUpgradable_init (address _minter, uint96 _fee, uint96 _minDefaultMinterRoyalty, address _splitterImplementationContract ) public initializer {
        __Ownable_init();
        __ERC165_init_unchained();
        _registerInterface(ERC1271_INTERFACE_ID);

        // Ensure index 0 is empty by default for cases where data is not set
        defaultsRegistry.push();
        mintersRegistry.push();

        upsertDefaultMinter(_minter, _fee, true);
        setMinDefaultMinterRoyalty(_minDefaultMinterRoyalty);
        setSplitterImplementationContract(_splitterImplementationContract);
    }

    function setSplitterImplementationContract(address _splitterImplementationContract) public onlyOwner {
        splitterImplementationContract = _splitterImplementationContract;
    }
    
    function setMinDefaultMinterRoyalty(uint96 _minDefaultMinterRoyalty) public onlyOwner {
        minDefaultMinterRoyalty = _minDefaultMinterRoyalty;
    }

    function upsertDefaultMinter(address _minter, uint96 _fee, bool active ) public onlyOwner {
        defaults[_minter] = defaultsRegistry.length;
        defaultsRegistry.push(DefaultMinter(active, _fee, 0, 0, 0));
    }

    function upsertDefaultCreatorPayoutsAndRoyalties(LibMinter.DefaultMinter memory data) public onlyOwner {

        delete defaultPayoutMapping[data.token][data.creator];
        for (uint i = 0; i < data.creators.length; i++) {
            defaultPayoutMapping[data.token][data.creator].push(data.creators[i]);
        }
        bytes32 royalties = getOrCreateSplitterUsingSplit(data.royalties);
        defaultRoyaltySplittersMapping[data.token][data.creator] = royalties;
    }

    function upsertDefaultCreatorPayoutsAndRoyaltiesByCreator(LibMinter.DefaultMinter memory data) public {

        require(data.creator == _msgSender(), "Can't set for someone else");
        delete defaultPayoutMapping[data.token][data.creator];
        for (uint i = 0; i < data.creators.length; i++) {
            defaultPayoutMapping[data.token][data.creator].push(data.creators[i]);
        }

        // Ensure Minters contract gets a minimum specified royalty
        bool setDefault;
        for (uint i = 0; i < data.royalties.length; i++) {
            if (data.royalties[i].account == address(this)){
                if (data.royalties[i].value < minDefaultMinterRoyalty) {
                    data.royalties[i].value = minDefaultMinterRoyalty;
                }
                setDefault = true;
                break;
            }
        }
        
        if (!setDefault){
            // Extend array in memory
            LibPart.Part[] memory royalties = new LibPart.Part[](data.royalties.length + 1);
            for (uint i = 0; i < data.royalties.length; i++) {
                royalties[i].account = data.royalties[i].account;
                royalties[i].value = data.royalties[i].value;
            }
            royalties[data.royalties.length].account = payable(address(this));
            royalties[data.royalties.length].value = minDefaultMinterRoyalty;

            bytes32 royaltiesBytes = getOrCreateSplitterUsingSplit(royalties);
            defaultRoyaltySplittersMapping[data.token][data.creator] = royaltiesBytes;
        } else {
            bytes32 royaltiesBytes = getOrCreateSplitterUsingSplit(data.royalties);
            defaultRoyaltySplittersMapping[data.token][data.creator] = royaltiesBytes;
        }
    }

    function getDefaultMinter(address _minter) external view returns (uint256 index, DefaultMinter memory) {
        return (defaults[_minter], defaultsRegistry[defaults[_minter]]);
    }

    function getDefaultMinterFee(address _minter) public view returns (uint96) {
        return defaultsRegistry[defaults[_minter]].fee;
    }

    function getOrCreateSplitterUsingSplit(LibPart.Part[] memory payees) internal virtual returns (bytes32){

        address payable splitterAddress;
        uint96 totalValue;
        bytes32 splitterBytes = LibPart.hashParts(payees);
        if (payees.length == 1) {
            require(payees[0].account != address(0x0), "Recipient should be present");
            require(payees[0].value != 0, "Royalty value should be positive");
            require(payees[0].value < 10000, "Royalty total value should be < 10000");

            splitters[splitterBytes] = LibPart.Part(payees[0].account, payees[0].value);

        } else if ( payees.length > 0) {
            splitterAddress = splitters[splitterBytes].account;
            totalValue = splitters[splitterBytes].value;
            
            // Check if splitter is not already created
            if (splitterAddress == address(0x0)){

                for (uint i = 0; i < payees.length; i++) {
                    require(payees[i].account != address(0x0), "Recipient should be present");
                    require(payees[i].value != 0, "Royalty value should be positive");
                    totalValue += payees[i].value;
                }
                require(totalValue < 10000, "Royalty total value should be < 10000");

                // Deploy new royalty splitter and save
                // emit RoyaltySplitter(splitter, _royalties);
                uint96 _depositBPS;
                for (uint i = 0; i < payees.length; i++){
                    payees[i].value = payees[i].value * 10000 / totalValue;
                    if (payees[i].account != address(this)){
                        _depositBPS += payees[i].value;
                    } else {
                        payees[i].value = 0;
                    }
                }

                splitterAddress = payable(ClonesUpgradeable.clone(splitterImplementationContract));
                SplitPayments(splitterAddress).setMinterContract(address(this));

                splitters[splitterBytes] = LibPart.Part(splitterAddress, totalValue);
                depositBPS[splitterAddress] = _depositBPS;

                for (uint i = 0; i < payees.length; i++){
                    withdrawSplits[splitterAddress].push(payees[i]);
                }

            }

            // return LibPart.Part(payable(splitter), totalValue);
        }

        return splitterBytes;
    }

    function recieveRoyaltyStake() external payable override {
        require(depositBPS[_msgSender()] > 0, "Isn't a splitter address");
        // Stake the royalty users into their staked wallet address to be withdrawn when they want
        // The minterDefault's stake is just added to the contract balance
        stake[_msgSender()] = msg.value * depositBPS[_msgSender()] / 10000 ;
        stake[owner()] = msg.value * (10000 - depositBPS[_msgSender()]) / 10000 ;
    }

    function withdrawRoyaltyStake(bytes32 splitterBytes) external {
        address splitterAddress = splitters[splitterBytes].account;
        // Send the staked amounts to participants wallets
        for (uint i = 0; i < withdrawSplits[splitterAddress].length; i++) {
            if (withdrawSplits[splitterAddress][i].account != address(this)) {
                (bool success, ) = withdrawSplits[splitterAddress][i].account.call{
                value:(stake[splitterAddress] * withdrawSplits[splitterAddress][i].value ) / depositBPS[splitterAddress]
                }("");
                // require(success, "Transfer failed."); // If someone messed up, others shouldn't suffer
            }
        }
        delete stake[splitterAddress];
    }

    function upsertMinter(address _token, LibMinter.Minter memory data) public virtual {

        bytes32 hash = LibMinter.hash(data);

        // Check if creator and minter gave signature
        address signer = validate(data.minter, hash, data.signatures[0]);
        validate(data.creator, hash, data.signatures[1]);

        // Creator is free to choose royalty split
        bytes32 royalties = getOrCreateSplitterUsingSplit(data.royalties);
        minters[_token][data.creator][data.minter] = mintersRegistry.length;

        
        mintersRegistry.push();

        mintersRegistry[mintersRegistry.length - 1].active = true;
        mintersRegistry[mintersRegistry.length - 1].fee = data.fee;
        mintersRegistry[mintersRegistry.length - 1].cancelValue = data.cancelValue;
        mintersRegistry[mintersRegistry.length - 1].start = data.start;
        mintersRegistry[mintersRegistry.length - 1].end = data.end;
        mintersRegistry[mintersRegistry.length - 1].royalties = royalties;

        for (uint i = 0; i < data.creators.length; i++) {
            mintersRegistry[mintersRegistry.length - 1].creators.push(data.creators[i]);
        }

    }

    function cancelMinter(address _token, address _minter) public payable virtual {
        require(
            msg.value == mintersRegistry[minters[_token][_msgSender()][_minter]].cancelValue,
            "Cancel charge"
        );
        delete mintersRegistry[minters[_token][_msgSender()][_minter]].active;
    }

    function getMinter(address _token, address _creator, address _minter)
        public
        view
        virtual
        returns (Minter memory)
    {
        return mintersRegistry[minters[_token][_creator][_minter]];
    }


    function getDetailsForMinting(address _token, address _creator, address _signer) external view virtual override returns (
        uint96,                 // Minting fee
        LibPart.Part[] memory,  // Creators payouts
        bytes32,                // Royalty splitter contract bytes to save
        LibPart.Part memory     // Royalty splitter contract address and percentage basis points
    ){
       
        if (_signer == _creator){
            // Allowing self signed
            if (defaultPayoutMapping[_token][_creator].length == 0){
                LibPart.Part[] memory creators = new LibPart.Part[](1);
                creators[0].account = payable(_creator);
                creators[0].value  = 10000;

                return (0, 
                        creators, 
                        defaultRoyaltySplittersMapping[_token][_creator], 
                        splitters[defaultRoyaltySplittersMapping[_token][_creator]]);
            }

            return (0, 
                    defaultPayoutMapping[_token][_creator], 
                    defaultRoyaltySplittersMapping[_token][_creator], 
                    splitters[defaultRoyaltySplittersMapping[_token][_creator]]);

        } else if (mintersRegistry[minters[_token][_creator][_signer]].active) {
            
            // Signed by creator defined minter
            return (mintersRegistry[minters[_token][_creator][_signer]].fee, 
                    mintersRegistry[minters[_token][_creator][_signer]].creators, 
                    mintersRegistry[minters[_token][_creator][_signer]].royalties, 
                    splitters[mintersRegistry[minters[_token][_creator][_signer]].royalties]);

        } else if (defaultsRegistry[defaults[_signer]].active) {

            // Signed by any of the default minters
            if (defaultPayoutMapping[_token][_creator].length == 0){
                LibPart.Part[] memory creators = new LibPart.Part[](1);
                creators[0].account = payable(_creator);
                creators[0].value  = 10000;

                return (defaultsRegistry[defaults[_signer]].fee, 
                        creators, 
                        defaultRoyaltySplittersMapping[_token][_creator], 
                        splitters[defaultRoyaltySplittersMapping[_token][_creator]]);
            } 

            return (defaultsRegistry[defaults[_signer]].fee, 
                    defaultPayoutMapping[_token][_creator], 
                    defaultRoyaltySplittersMapping[_token][_creator], 
                    splitters[defaultRoyaltySplittersMapping[_token][_creator]]);
        }
        revert("Illegal minter");
    }


    function getDetailsForRoyalty(address _token, address _creator, address _signer) external view virtual override returns (
        bytes32 // Splitter description bytes identifier for the wallet
    ){
        if (_signer == _creator){
            return defaultRoyaltySplittersMapping[_token][_creator];
        } else if (mintersRegistry[minters[_token][_creator][_signer]].active) {
            return mintersRegistry[minters[_token][_creator][_signer]].royalties;
        } else if (defaultsRegistry[defaults[_signer]].active) {
            return defaultRoyaltySplittersMapping[_token][_creator];
        }
        revert("Illegal minter");
    }

    function getSplitter(bytes32 splitterBytes) external view override returns(LibPart.Part memory) {
        return splitters[splitterBytes];
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
            if (defaultsRegistry[defaults[signerFromSig]].active) {
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