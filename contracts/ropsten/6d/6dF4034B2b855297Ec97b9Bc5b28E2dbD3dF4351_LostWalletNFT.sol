// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IAdminContract {

    function hasRole(bytes32 role, address account)
        external
        view
        returns (bool);

}

contract LostWalletNFT is ERC721URIStorage, Pausable {
    address public owner;
    address public nftowner;
    address public Admincontract;
    string public Wallet_Owner_Information_Name;
    string public Wallet_Owner_Information_Address;
    string public Wallet_Owner_Information_Wallet_address;

    string public Wallet_Information_Public_key;
    string public Wallet_Information_Current_value_of_wallet;
    string public Wallet_Information_value_of_wallet;
    string public Due_Diligence_Date_of_owner_s_interaction_with_Chrysalis;

    bytes32 public constant SUB_ADMIN_ROLE = keccak256("SUB_ADMIN_ROLE");

    constructor(
        address _owner,
        address _user,
        string memory _URI,
        string memory _Wallet_Owner_Information_Name,
        string memory _Wallet_Owner_Information_Address,
        string memory _Wallet_Owner_Information_Wallet_address,
        string memory _Wallet_Information_Public_key,
        string memory _Wallet_Information_Current_value_of_wallet,
        string memory _Wallet_Information_value_of_wallet,
        string memory _Due_Diligence_Date_of_owner_s_interaction_with_Chrysalis,
        address _Admincontract
    ) ERC721("NFT", "NFT") {
        owner = _owner;
        nftowner = _user;

        Wallet_Owner_Information_Name = _Wallet_Owner_Information_Name;
        Wallet_Owner_Information_Address = _Wallet_Owner_Information_Address;
        Wallet_Owner_Information_Wallet_address = _Wallet_Owner_Information_Wallet_address;
        Wallet_Information_Public_key = _Wallet_Information_Public_key;
        Wallet_Information_Current_value_of_wallet = _Wallet_Information_Current_value_of_wallet;
        Wallet_Information_value_of_wallet = _Wallet_Information_value_of_wallet;
        Due_Diligence_Date_of_owner_s_interaction_with_Chrysalis = _Due_Diligence_Date_of_owner_s_interaction_with_Chrysalis;

        Admincontract = _Admincontract;

        mint(_URI);
    }

    function mint(string memory _uri) internal {
        _mint(nftowner, 0);
        _setTokenURI(0, _uri);
    }

    function destroySmartContract() public {
        require(Admincontract == msg.sender, "only  admin destroye");
        selfdestruct(payable(address(this)));
    }

    // whenNotPaused

    function updatePauseStatus(bool _status) public {
        require(msg.sender == owner, "only admin can call");
        if (paused()) {
            require(_status == false, "Already in pause same status");
            _unpause();
        } else {
            require(_status == true, "Already in unpause same status");
            _pause();
        }
    }

    struct Lost_wallet_owner_info {
        string name;
        string Address;
        string National_id_Number;
        string DOB;
        string Address_history;
        string phone_number;
        string Email_address;
        string Wallet_address;
        string IP_address;
    }

    Lost_wallet_owner_info[] public lost_wallet_owner_info;

    function owner_info(
        string memory _name,
        string memory _Address,
        string memory _National_id_Number,
        string memory _DOB,
        string memory _Address_history,
        string memory _phone_number,
        string memory _Email_address,
        string memory _Wallet_address,
        string memory _IP_address
    ) public whenNotPaused {
        require(
            IAdminContract(Admincontract).hasRole(SUB_ADMIN_ROLE, msg.sender) ||
                owner == msg.sender,
            "onlyAdmin can call"
        );

        lost_wallet_owner_info.push(
            Lost_wallet_owner_info({
                name: _name,
                Address: _Address,
                National_id_Number: _National_id_Number,
                DOB: _DOB,
                Address_history: _Address_history,
                phone_number: _phone_number,
                Email_address: _Email_address,
                Wallet_address: _Wallet_address,
                IP_address: _IP_address
            })
        );
    }

    struct Lost_wallet_info {
        string Wallet_source;
        string Public_key;
        string Current_value_of_wallet;
        string Value_of_wallet;
        string Value_of_wallet_at_time_of_acquisition_by_owner;
        string Date_of_acquisition_of_wallet;
        string Date_of_last_transaction;
        string Amount_of_last_transaction;
        string Narrative;
    }

    Lost_wallet_info[] public lost_wallet_info;

    function wallet_info(
        string memory _Wallet_source,
        string memory _Public_key,
        string memory _Current_value_of_wallet,
        string memory _Value_of_wallet,
        string memory _Value_of_wallet_at_time_of_acquisition_by_owner,
        string memory _Date_of_acquisition_of_wallet,
        string memory _Date_of_last_transaction,
        string memory _Amount_of_last_transaction,
        string memory _Narrative
    ) public whenNotPaused {
        require(
            owner == msg.sender ||
                (
                    IAdminContract(Admincontract).hasRole(
                        SUB_ADMIN_ROLE,
                        msg.sender
                    )
                ),
            "onlyAdmin can call"
        );

        lost_wallet_info.push(
            Lost_wallet_info({
                Wallet_source: _Wallet_source,
                Public_key: _Public_key,
                Current_value_of_wallet: _Current_value_of_wallet,
                Value_of_wallet: _Value_of_wallet,
                Value_of_wallet_at_time_of_acquisition_by_owner: _Value_of_wallet_at_time_of_acquisition_by_owner,
                Date_of_acquisition_of_wallet: _Date_of_acquisition_of_wallet,
                Date_of_last_transaction: _Date_of_last_transaction,
                Amount_of_last_transaction: _Amount_of_last_transaction,
                Narrative: _Narrative
            })
        );
    }

    struct Lost_wallet_Due_Diligence {
        string Date_of_owner_s_interaction_with_Chrysalis;
        string Date_of_commencing_the_due_diligence;
        string Date_of_completing_the_due_diligence;
        string Date_of_refresh_of_due_diligence;
        string Due_diligence_executed_by;
        bool Due_diligence_success;
    }

    Lost_wallet_Due_Diligence[] public lost_wallet_Due_Diligence;

    function Due_Diligence(
        string memory _Date_of_owner_s_interaction_with_Chrysalis,
        string memory _Date_of_commencing_the_due_diligence,
        string memory _Date_of_completing_the_due_diligence,
        string memory _Date_of_refresh_of_due_diligence,
        string memory _Due_diligence_executed_by,
        bool _Due_diligence_success
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );

        lost_wallet_Due_Diligence.push(
            Lost_wallet_Due_Diligence({
                Date_of_owner_s_interaction_with_Chrysalis: _Date_of_owner_s_interaction_with_Chrysalis,
                Date_of_commencing_the_due_diligence: _Date_of_commencing_the_due_diligence,
                Date_of_completing_the_due_diligence: _Date_of_completing_the_due_diligence,
                Date_of_refresh_of_due_diligence: _Date_of_refresh_of_due_diligence,
                Due_diligence_executed_by: _Due_diligence_executed_by,
                Due_diligence_success: _Due_diligence_success
            })
        );
    }

    struct Lost_Wallet_Intermediary {
        string name;
        string Industry;
        string Geolocation;
    }
    Lost_Wallet_Intermediary[] public lost_Wallet_Intermediary;

    function Intermediary(
        string memory _name,
        string memory _Industry,
        string memory _Geolocation
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );

        lost_Wallet_Intermediary.push(
            Lost_Wallet_Intermediary({
                name: _name,
                Industry: _Industry,
                Geolocation: _Geolocation
            })
        );
    }

    struct Lost_Wallet_Chrysalis_token_Owner_Information {
        string Name;
        string Address;
        string National_ID_number;
        string Date_of_birth;
        string Phone_number;
        string Email_address;
        string IP_address;
    }

    Lost_Wallet_Chrysalis_token_Owner_Information[]
        public lost_Wallet_Chrysalis_token_Owner_Information;

    function token_Owner_Information(
        string memory _Name,
        string memory _Address,
        string memory _National_ID_number,
        string memory _Date_of_birth,
        string memory _Phone_number,
        string memory _Email_address,
        string memory _IP_address
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );

        lost_Wallet_Chrysalis_token_Owner_Information.push(
            Lost_Wallet_Chrysalis_token_Owner_Information({
                Name: _Name,
                Address: _Address,
                National_ID_number: _National_ID_number,
                Date_of_birth: _Date_of_birth,
                Phone_number: _Phone_number,
                Email_address: _Email_address,
                IP_address: _IP_address
            })
        );
    }

    struct Lost_Wallet_Chrysalis_Token {
        bool Tradeable;
        string Type;
        string Rating;
    }

    Lost_Wallet_Chrysalis_Token[] public lost_Wallet_Chrysalis_Token;

    function Chrysalis_Token(
        bool _Tradeable,
        string memory _Type,
        string memory _Rating
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );

        lost_Wallet_Chrysalis_Token.push(
            Lost_Wallet_Chrysalis_Token({
                Tradeable: _Tradeable,
                Type: _Type,
                Rating: _Rating
            })
        );
    }
}

contract InsuredWalletNFT is ERC721URIStorage, Pausable {
    address public owner;
    address public nftowner;
    address public Admincontract;

    string public Wallet_Owner_Information_Name;
    string public Wallet_Owner_Information_Address;
    string public Wallet_Owner_Information_Wallet_address;

    string public Wallet_Information_Public_key;
    string public Wallet_Information_Current_value_of_wallet;
    string public Wallet_Information_value_of_wallet;

    bool public Due_Diligence__success;

    bool public isTradable;

    bytes32 public constant SUB_ADMIN_ROLE = keccak256("SUB_ADMIN_ROLE");

    constructor(
        address _owner,
        address _user,
        string memory _URI,
        string memory _Wallet_Owner_Information_Name,
        string memory _Wallet_Owner_Information_Address,
        string memory _Wallet_Owner_Information_Wallet_address,
        string memory _Wallet_Information_Public_key,
        string memory _Wallet_Information_Current_value_of_wallet,
        string memory _Wallet_Information_value_of_wallet,
        bool _Due_Diligence__success,
        address _Admincontract
    ) ERC721("NFT", "NFT") {
        owner = _owner;
        nftowner = _user;
        isTradable = true;

        Wallet_Owner_Information_Name = _Wallet_Owner_Information_Name;
        Wallet_Owner_Information_Address = _Wallet_Owner_Information_Address;
        Wallet_Owner_Information_Wallet_address = _Wallet_Owner_Information_Wallet_address;
        Wallet_Information_Public_key = _Wallet_Information_Public_key;
        Wallet_Information_Current_value_of_wallet = _Wallet_Information_Current_value_of_wallet;
        Wallet_Information_value_of_wallet = _Wallet_Information_value_of_wallet;
        Due_Diligence__success = _Due_Diligence__success;

        Admincontract = _Admincontract;

        mint(_URI);
    }

    function mint(string memory _uri) internal {
        _mint(nftowner, 0);
        _setTokenURI(0, _uri);
        isTradable = false;
    }

    function destroySmartContract() public {
        require(Admincontract == msg.sender, "only  admin destroye");
        selfdestruct(payable(address(this)));
    }

    function change_tradable(bool value) public {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );
        isTradable = value;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(isTradable, "Cannot trade");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function updatePauseStatus(bool _status) public {
        require(owner == msg.sender, "only admin can pause");

        if (paused()) {
            require(_status == false, "Already in pause same status");
            _unpause();
        } else {
            require(_status == true, "Already in unpause same status");
            _pause();
        }
    }

    struct Insured_Wallet_Wallet_Owner_Information {
        string name;
        string Address;
        string National_id_Number;
        string DOB;
        string Address_history;
        string phone_number;
        string Email_address;
        string Wallet_address;
        string IP_address;
    }

    Insured_Wallet_Wallet_Owner_Information[]
        public insured_Wallet_Wallet_Owner_Information;

    function Owner_Information(
        string memory _name,
        string memory _Address,
        string memory _National_id_Number,
        string memory _DOB,
        string memory _Address_history,
        string memory _phone_number,
        string memory _Email_address,
        string memory _Wallet_address,
        string memory _IP_address
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );

        insured_Wallet_Wallet_Owner_Information.push(
            Insured_Wallet_Wallet_Owner_Information({
                name: _name,
                Address: _Address,
                National_id_Number: _National_id_Number,
                DOB: _DOB,
                Address_history: _Address_history,
                phone_number: _phone_number,
                Email_address: _Email_address,
                Wallet_address: _Wallet_address,
                IP_address: _IP_address
            })
        );
    }

    struct Insured_Wallet_Wallet_Information {
        string Wallet_source;
        string Public_key;
        string Value_of_wallet_at_the_initial_interaction_with_Chrysalis;
        string Current_value_of_wallet;
        string Narrative;
    }
    Insured_Wallet_Wallet_Information[]
        public insured_Wallet_Wallet_Information;

    function Wallet_Information(
        string memory _Wallet_source,
        string memory _Public_key,
        string
            memory _Value_of_wallet_at_the_initial_interaction_with_Chrysalis,
        string memory _Current_value_of_wallet,
        string memory _Narrative
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );
        insured_Wallet_Wallet_Information.push(
            Insured_Wallet_Wallet_Information({
                Wallet_source: _Wallet_source,
                Public_key: _Public_key,
                Value_of_wallet_at_the_initial_interaction_with_Chrysalis: _Value_of_wallet_at_the_initial_interaction_with_Chrysalis,
                Current_value_of_wallet: _Current_value_of_wallet,
                Narrative: _Narrative
            })
        );
    }

    struct Insured_Wallet_Due_Diligence {
        string Test_transaction_description;
        string Test_transaction_source;
        string Test_transaction_destination;
        bool Due_diligence_success;
    }

    Insured_Wallet_Due_Diligence[] public insured_Wallet_Due_Diligence;

    function Due_Diligence(
        string memory _Test_transaction_description,
        string memory _Test_transaction_source,
        string memory _Test_transaction_destination,
        bool _Due_diligence_success
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );

        insured_Wallet_Due_Diligence.push(
            Insured_Wallet_Due_Diligence({
                Test_transaction_description: _Test_transaction_description,
                Test_transaction_source: _Test_transaction_source,
                Test_transaction_destination: _Test_transaction_destination,
                Due_diligence_success: _Due_diligence_success
            })
        );
    }

    struct Insured_Wallet_Intermediary {
        string name;
        string Industry;
        string Geolocation;
    }

    Insured_Wallet_Intermediary[] public insured_Wallet_Intermediary;

    function Wallet_Intermediary(
        string memory _name,
        string memory _Industry,
        string memory _Geolocation
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );
        insured_Wallet_Intermediary.push(
            Insured_Wallet_Intermediary({
                name: _name,
                Industry: _Industry,
                Geolocation: _Geolocation
            })
        );
    }

    struct Insured_Wallet_Chrysalis_token_Owner_Information {
        string name;
        string Address;
        string National_id_Number;
        string DOB;
        string phone_number;
        string Email_address;
        string IP_address;
    }

    Insured_Wallet_Chrysalis_token_Owner_Information[]
        public insured_Wallet_Chrysalis_token_Owner_Information;

    function Chrysalis_token_Owner_Information(
        string memory _name,
        string memory _Address,
        string memory _National_id_Number,
        string memory _DOB,
        string memory _phone_number,
        string memory _Email_address,
        string memory _IP_address
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );
        insured_Wallet_Chrysalis_token_Owner_Information.push(
            Insured_Wallet_Chrysalis_token_Owner_Information({
                name: _name,
                Address: _Address,
                National_id_Number: _National_id_Number,
                DOB: _DOB,
                phone_number: _phone_number,
                Email_address: _Email_address,
                IP_address: _IP_address
            })
        );
    }

    struct Insured_Wallet_Chrysalis_token {
        bool Tradeable;
        string Type;
        string Rating;
    }

    Insured_Wallet_Chrysalis_token[] public insured_Wallet_Chrysalis_token;

    function Chrysalis_token(
        bool _Tradeable,
        string memory _Type,
        string memory _Rating
    ) public whenNotPaused {
        require(
            (IAdminContract(Admincontract).hasRole(
                SUB_ADMIN_ROLE,
                msg.sender
            ) || owner == msg.sender),
            "onlyAdmin can call"
        );
        insured_Wallet_Chrysalis_token.push(
            Insured_Wallet_Chrysalis_token({
                Tradeable: _Tradeable,
                Type: _Type,
                Rating: _Rating
            })
        );
    }
}

contract lost_wallet_Admin is OwnableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant SUB_ADMIN_ROLE = keccak256("SUB_ADMIN_ROLE");
    address[] public Lost_contracts;

    function destroyContract(address _contract) public {
        require(
            hasRole(SUB_ADMIN_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "!! Caller does not have right roles !!"
        );
        LostWalletNFT c = LostWalletNFT(_contract);
        c.destroySmartContract();
    }

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        OwnableUpgradeable.__Ownable_init();
    }

    function Lost_Wallet_NFT(
        address user,
        string memory URI,
        string memory Wallet_Owner_Information_Name,
        string memory Wallet_Owner_Information_Address,
        string memory Wallet_Owner_Information_Wallet_address,
        string memory Wallet_Information_Public_key,
        string memory Wallet_Information_Current_value_of_wallet,
        string memory Wallet_Information_value_of_wallet,
        string memory Due_Diligence_Date_of_owner_s_interaction_with_Chrysalis
    ) external {
        require(
            hasRole(SUB_ADMIN_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "!! Caller does not have right roles !!"
        );
        LostWalletNFT A = new LostWalletNFT(
            owner(),
            user,
            URI,
            Wallet_Owner_Information_Name,
            Wallet_Owner_Information_Address,
            Wallet_Owner_Information_Wallet_address,
            Wallet_Information_Public_key,
            Wallet_Information_Current_value_of_wallet,
            Wallet_Information_value_of_wallet,
            Due_Diligence_Date_of_owner_s_interaction_with_Chrysalis,
            address(this)
        );
        Lost_contracts.push(address(A));
    }

    function setNewAdminRole(address subAdmin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setupRole(SUB_ADMIN_ROLE, subAdmin);
    }

}

contract Insured_wallet_Admin is OwnableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant SUB_ADMIN_ROLE = keccak256("SUB_ADMIN_ROLE");
    address[] public Insured_contracts;

    function destroyContract(address _contract) public {
        require(
            hasRole(SUB_ADMIN_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "!! Caller does not have right roles !!"
        );
        InsuredWalletNFT c = InsuredWalletNFT(_contract);
        c.destroySmartContract();
    }

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        OwnableUpgradeable.__Ownable_init();
    }

    function Insured_Wallet_NFT(
        address user,
        string memory URI,
        string memory Wallet_Owner_Information_Name,
        string memory Wallet_Owner_Information_Address,
        string memory Wallet_Owner_Information_Wallet_address,
        string memory Wallet_Information_Public_key,
        string memory Wallet_Information_Current_value_of_wallet,
        string memory Wallet_Information_value_of_wallet,
        bool Due_Diligence__success
    ) external {
        require(
            hasRole(SUB_ADMIN_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "!! Caller does not have right roles !!"
        );
        InsuredWalletNFT A = new InsuredWalletNFT(
            owner(),
            user,
            URI,
            Wallet_Owner_Information_Name,
            Wallet_Owner_Information_Address,
            Wallet_Owner_Information_Wallet_address,
            Wallet_Information_Public_key,
            Wallet_Information_Current_value_of_wallet,
            Wallet_Information_value_of_wallet,
            Due_Diligence__success,
            address(this)
        );
        Insured_contracts.push(address(A));
    }

    function setNewAdminRole(address subAdmin)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setupRole(SUB_ADMIN_ROLE, subAdmin);
    }
}