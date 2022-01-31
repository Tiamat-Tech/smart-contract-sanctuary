// SPDX-License-Identifier: GPL-3.0


pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract BlockchainDMV is ERC721, AccessControl{
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum VehicleClass{undefined, PASS, COMM, MCYC, TRAILER}
    enum TitleStatus{undefined, CLEAN, SALVAGE, REBUILT}

    struct VehicleAttributes {
        uint256 year;
        string vinNumber;
        string vehicleMake;
        string vehicleModel;
        uint256 curbWeight;
        VehicleClass class;
        TitleStatus status;
        string plateNumber;
    }
    
    
    struct VehicleOwnerAttributes{
        string firstName;
        string lastName;
        string address1;
        string address2;
        string city;
        string state;
        string zipCode;
    }

    struct PendingVehicleRegistrationRequest{
        address owner;
        VehicleAttributes vehicleInfo;
    }

    address[] public pendingKYC;

    PendingVehicleRegistrationRequest[] public pendingVehicleRegistrationRequests;

    mapping (address => uint256[]) vehicleTokenIdsToOwner;
    mapping (uint256 => VehicleAttributes) tokenIdtoVehicleAttributes;
    
    mapping (address => VehicleOwnerAttributes) ownerAttributesToOwner;
    mapping (address => bool) ownerKYCComplete;
    
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    
    event newVehicleTokenMinted(address sender, uint256 tokenId);
    event newVehicleOwnerKYCCompleted(address vehicleOwner);
    event vehicleTransferredtoNewOwner(address recipient, uint256 tokenId);

    constructor() ERC721("Blockchain DMV", "DMV"){
        
        _tokenIds.increment();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(ADMIN_ROLE, msg.sender);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function getPendingRegistrationRequests() public view returns(PendingVehicleRegistrationRequest[] memory){
        require(hasRole(ADMIN_ROLE, msg.sender), "User does not have admin role");
        return pendingVehicleRegistrationRequests;
    }

    function newRegistrationRequest(uint256 _year, 
            string memory _vinNumber, 
            string memory _vehicleMake, 
            string memory _vehicleModel,
            uint256 _curbWeight) external{
                require(ownerKYCComplete[msg.sender] == true, "Vehicle owner must provide information first");
                VehicleAttributes memory newReg = VehicleAttributes({
                    year: _year,
                    vinNumber: _vinNumber,
                    vehicleMake: _vehicleMake,
                    vehicleModel: _vehicleModel,
                    curbWeight: _curbWeight,
                    class: VehicleClass.undefined,
                    status: TitleStatus.undefined,
                    plateNumber: ""
                });
                PendingVehicleRegistrationRequest memory newRequest = PendingVehicleRegistrationRequest({
                    owner: msg.sender,
                    vehicleInfo: newReg
                });
                pendingVehicleRegistrationRequests.push(newRequest);
            }

    function mintVehicleToken (  
    /* Originally I was just copying the data from the pending registration but that
    prevented an admin from making edits before approval. */
            uint256 queueIndex,
            uint256 _vehicleYear,
            string memory _vinNumber,
            string memory _vehicleMake,
            string memory _vehicleModel,
            uint256 _curbWeight,
            uint256 _titleStatus,
            uint256 _vehicleClass, 
            string memory _plateNumber) external {
        PendingVehicleRegistrationRequest memory pendingRequest = pendingVehicleRegistrationRequests[queueIndex];

        require(ownerKYCComplete[pendingRequest.owner] == true, "Vehicle owner must provide information first");
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin can do this."); 

        
        uint256 newItemId = _tokenIds.current();
        _safeMint(pendingRequest.owner, newItemId);
        _tokenIds.increment();

        tokenIdtoVehicleAttributes[newItemId] = VehicleAttributes({
            year: _vehicleYear,
            vinNumber: _vinNumber,
            vehicleMake: _vehicleMake,
            vehicleModel: _vehicleModel,
            curbWeight: _curbWeight,
            class: VehicleClass(_vehicleClass),
            status: TitleStatus(_titleStatus),
            plateNumber: _plateNumber
        });
        vehicleTokenIdsToOwner[pendingRequest.owner].push(newItemId);

        require(queueIndex < pendingVehicleRegistrationRequests.length, "index out of bound");
             for (uint i = queueIndex; i < pendingVehicleRegistrationRequests.length - 1; i++) {
                 pendingVehicleRegistrationRequests[i] = pendingVehicleRegistrationRequests[i + 1];
                    }
            pendingVehicleRegistrationRequests.pop();

        emit newVehicleTokenMinted(pendingRequest.owner, newItemId);
        
    }

    function editVehicleInformation(uint256 _tokenId, uint256 _vehicleYear,
            string memory _vinNumber,
            string memory _vehicleMake,
            string memory _vehicleModel,
            uint256 _curbWeight,
            uint256 _titleStatus,
            uint256 _vehicleClass, 
            string memory _plateNumber) external{
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin can do this.");
        tokenIdtoVehicleAttributes[_tokenId] = VehicleAttributes({
            year: _vehicleYear,
            vinNumber: _vinNumber,
            vehicleMake: _vehicleMake,
            vehicleModel: _vehicleModel,
            curbWeight: _curbWeight,
            class: VehicleClass(_vehicleClass),
            status: TitleStatus(_titleStatus),
            plateNumber: _plateNumber
        });



    }

    function cancelRegRequest(uint256 queueIndex) public{
            require(queueIndex < pendingVehicleRegistrationRequests.length, "index out of bound");
             for (uint i = queueIndex; i < pendingVehicleRegistrationRequests.length - 1; i++) {
                 pendingVehicleRegistrationRequests[i] = pendingVehicleRegistrationRequests[i + 1];
                    }
            pendingVehicleRegistrationRequests.pop();

    }
    
    // Only admin can retrieve any user's vehicles. 
     function adminRetreiveOwnerVehicles (address owner) public view returns(VehicleAttributes[] memory){
        require(hasRole(ADMIN_ROLE, msg.sender), "User does not have admin role");
        uint256[] memory tokenIds = vehicleTokenIdsToOwner[owner];
         VehicleAttributes[] memory returnValue = new VehicleAttributes[](tokenIds.length);
         for (uint i = 0; i < tokenIds.length; i++){
            returnValue[i] = tokenIdtoVehicleAttributes[tokenIds[i]];
        }
        
        return returnValue;
 
     }

    function retrieveOwnerTokens () public view returns(uint256[] memory){
        
        return vehicleTokenIdsToOwner[msg.sender];
    }
    
    function retrieveOwnerVehicles () public view returns(VehicleAttributes[] memory){
        
        uint256[] memory tokenIds = vehicleTokenIdsToOwner[msg.sender];
        
        VehicleAttributes[] memory returnValue = new VehicleAttributes[](tokenIds.length);
        
        for (uint i = 0; i < tokenIds.length; i++){
            returnValue[i] = tokenIdtoVehicleAttributes[tokenIds[i]];
        }
        
        return returnValue;
    }
    
    function retrieveOwnerInfo (address owner) public view returns(VehicleOwnerAttributes memory){
       
        return ownerAttributesToOwner[owner];

    }
    
    function transferVehicleToNewOwner (address recipient, uint256 _tokenID) public{
        require(msg.sender == ownerOf(_tokenID), "Caller must be the owner of this token");   
        require(ownerKYCComplete[recipient] == true, "New owner must complete KYC");
            uint256[] memory oldOwnerTokenIDArray = vehicleTokenIdsToOwner[msg.sender];
            uint256[] memory newOwnerTokenIDArray = new uint256[](oldOwnerTokenIDArray.length - 1); // Creating a new array - 1 index for the vehicle we're removing.
            for (uint i = 0; i < oldOwnerTokenIDArray.length; i++ ){
                if (_tokenID != oldOwnerTokenIDArray[i]){
                    newOwnerTokenIDArray[i] = oldOwnerTokenIDArray[i];
                }
            }
            vehicleTokenIdsToOwner[msg.sender] = newOwnerTokenIDArray;
             vehicleTokenIdsToOwner[recipient].push(_tokenID);
             safeTransferFrom(msg.sender, recipient, (_tokenID));
             emit vehicleTransferredtoNewOwner(recipient, _tokenID);
        
    }
    
    function getPendingKYC() public view returns(address[] memory){
        require(hasRole(ADMIN_ROLE, msg.sender), "User does not have admin role");

        return pendingKYC; 
    }

   
    function isKycCompleted(address user) public view returns(bool){
        require(hasRole(ADMIN_ROLE, msg.sender), "User does not have admin role");
        return ownerKYCComplete[user];

    }

    function approveKYC(uint256 queueIndex) public{
        require(hasRole(ADMIN_ROLE, msg.sender), "User does not have admin role");
        
        address userAddress = pendingKYC[queueIndex];
        ownerKYCComplete[userAddress] = true;

             require(queueIndex < pendingKYC.length, "index out of bound");
             for (uint i = queueIndex; i < pendingKYC.length - 1; i++) {
                 pendingKYC[i] = pendingKYC[i + 1];
                    }
            pendingKYC.pop();
        grantRole(USER_ROLE, userAddress);


    }
    
    function editKYC(address user, 
         string memory _firstName,
            string memory _lastName,
            string memory _address1,
            string memory _address2,
            string memory _city,
            string memory _state,
            string memory _zipCode) external{

            require(hasRole(ADMIN_ROLE, msg.sender) || user == msg.sender, "Only admin or owner can do this");

            ownerAttributesToOwner[user] = VehicleOwnerAttributes({
                firstName: _firstName,
                lastName: _lastName,
                address1: _address1,
                address2: _address2,
                city: _city,
                state: _state,
                zipCode: _zipCode
            });



        }



    function ownerKYC(string memory _firstName,
            string memory _lastName,
            string memory _address1,
            string memory _address2,
            string memory _city,
            string memory _state,
            string memory _zipCode) external{
                
            ownerAttributesToOwner[msg.sender] = VehicleOwnerAttributes({
                firstName: _firstName,
                lastName: _lastName,
                address1: _address1,
                address2: _address2,
                city: _city,
                state: _state,
                zipCode: _zipCode
            });
            
            ownerKYCComplete[msg.sender] = false; //Pending approval
            pendingKYC.push(msg.sender);
            emit newVehicleOwnerKYCCompleted(msg.sender);
    }
    
}