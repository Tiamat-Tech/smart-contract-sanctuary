// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ohdatCast is AccessControl,Pausable {

    using Strings for string;
    uint256 public castSingleFee;
    bytes32 public constant CAST_ROLE = keccak256("CAST_ROLE");
    bytes32 public constant SUB_CONTRACT_ALLOW_ROLE = keccak256("SUB_CONTRACT_ALLOW_ROLE");
    bytes32 public constant NFT_DISALLOW_ROLE = keccak256("NFT_DISALLOW_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    address internal mainBodyContractAddress;
    address public owner;
    address internal agentAddress;

    //Interface Signature ERC1155 and ERC721
    bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;
    bytes4 constant private INTERFACE_SIGNATURE_ERC721 = 0x9a20483d;

    //Cast info
    struct castInfo{
        uint256 tokenId;
        uint256 musicTokenId;
        address musicAddress;
        uint256 backgroundTokenId;
        address backgroundAddress;
        address agentAddress;
    }

    //Info map
    mapping (uint256 => castInfo) internal CastInfoMap;
    mapping (uint256 => bool) internal DisallowCastNFTMap;

    event ETHReceived(address indexed sender, uint256 indexed value);
    event UncastSuccessful(uint256 indexed _mainBodyTokenId,uint256 indexed _musicTokenId,address _musicAddress,uint256 indexed _backgroundTokenId,address _backgroundAddress);
    event CastSuccessful(uint256 indexed _mainBodyTokenId,uint256 indexed _musicTokenId,address _musicAddress,uint256 indexed _backgroundTokenId,address _backgroundAddress);

    //Constructor
    constructor(uint256 _castSingleFee,address _mainBodyContractAddress,address _agentAddress) {
         _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
         _setupRole(PAUSER_ROLE, msg.sender);
         castSingleFee = _castSingleFee;
         mainBodyContractAddress = _mainBodyContractAddress;
         agentAddress = _agentAddress;
         owner = msg.sender;
     }

    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
        if (msg.value > castSingleFee){
                payable(msg.sender).transfer(msg.value - castSingleFee);
            }
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }

    //Get balance of this contract
    function getContractBalance() public whenNotPaused view returns (uint256) {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        return address(this).balance;
    }

    function withdraw() public whenNotPaused payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance - 20 gwei;
        payable(owner).transfer(withdrawETH);
    }

    //Cast function
    function cast(uint256 _mainBodyTokenId,uint256 _musicTokenId,address _musicAddress,uint256 _backgroundTokenId,address _backgroundAddress)public whenNotPaused payable {
        //Check if the sub-contract is approved to be casted
        require(hasRole(SUB_CONTRACT_ALLOW_ROLE, _musicAddress));
        require(hasRole(SUB_CONTRACT_ALLOW_ROLE, _backgroundAddress));
        //Check if the mainBody NFT is allowed to be casted
        require(_validateCastable(_mainBodyTokenId));
        //Check sub-NFT ownership
        require(_validateOwnership(_mainBodyTokenId,_musicTokenId,_musicAddress,_backgroundTokenId,_backgroundAddress));
        if (_musicAddress == _backgroundAddress){
            require(_musicTokenId != _backgroundTokenId);
        }
        //Trasfer sub-NFT to agent address
        if (msg.value >= castSingleFee){
            _castHelper(_mainBodyTokenId,_musicTokenId,_musicAddress,_backgroundTokenId,_backgroundAddress,agentAddress);
            emit CastSuccessful(_mainBodyTokenId,_musicTokenId,_musicAddress,_backgroundTokenId,_backgroundAddress);
            _setCastInfo(_mainBodyTokenId,_musicTokenId,_musicAddress,_backgroundTokenId,_backgroundAddress);
            // withdraw(msg.value);
            payable(address(this)).transfer(castSingleFee);
            if (msg.value > castSingleFee){
                payable(msg.sender).transfer(msg.value - castSingleFee);
            }
        }
    }

    function _castHelper(uint256 _mainBodyTokenId,uint256 _musicTokenId,address _musicAddress,uint256 _backgroundTokenId,address _backgroundAddress,address _agentAddress)internal whenNotPaused {
        //Check music
        if (CastInfoMap[_mainBodyTokenId].musicAddress != _musicAddress || CastInfoMap[_mainBodyTokenId].musicTokenId != _musicTokenId){
             //Return used music
            _uncastMusic(_mainBodyTokenId);
             if(_musicTokenId != 0 && _musicAddress != address(0)){
                 //Transfer new music to agent address
                require(_transferSubNFT(_musicTokenId,_musicAddress,msg.sender,_agentAddress));
             }
        }
        //Check background
        if(CastInfoMap[_mainBodyTokenId].backgroundAddress != _backgroundAddress || CastInfoMap[_mainBodyTokenId].backgroundTokenId !=  _backgroundTokenId ){
             //Return used background
            _uncastBackground(_mainBodyTokenId);
            if(_backgroundTokenId != 0 &&  _backgroundAddress != address(0)){
                //Transfer new background to agent address
                require(_transferSubNFT(_backgroundTokenId,_backgroundAddress,msg.sender,_agentAddress));
            }
        }
    }

    function _transferSubNFT(uint256 _TokenId,address _contractAddress,address from,address to)internal whenNotPaused returns (bool){
        if (_checkProtocol(_contractAddress)){
            IERC1155 NFTContract = IERC1155(_contractAddress);
            NFTContract.safeTransferFrom(from,to,_TokenId,1,abi.encodePacked(msg.sender));
        }else{
            IERC721 NFTContract = IERC721(_contractAddress);
            NFTContract.safeTransferFrom(from,to,_TokenId);
        }
        return true;
    }

    function _uncastMusic(uint256 _mainBodyTokenId) whenNotPaused internal{
        if (CastInfoMap[_mainBodyTokenId].musicAddress != address(0) && CastInfoMap[_mainBodyTokenId].musicTokenId != 0){
            require(_transferSubNFT(CastInfoMap[_mainBodyTokenId].musicTokenId,CastInfoMap[_mainBodyTokenId].musicAddress,agentAddress,msg.sender));
        }
    }

    function _uncastBackground(uint256 _mainBodyTokenId) whenNotPaused internal{
        if(CastInfoMap[_mainBodyTokenId].backgroundAddress != address(0) && CastInfoMap[_mainBodyTokenId].backgroundTokenId != 0){
            require(_transferSubNFT(CastInfoMap[_mainBodyTokenId].backgroundTokenId ,CastInfoMap[_mainBodyTokenId].backgroundAddress,agentAddress,msg.sender));
        }
    }

    function _setCastInfo(uint256 _mainBodyTokenId,uint256 _musicTokenId,address _musicAddress,uint256 _backgroundTokenId,address _backgroundAddress) whenNotPaused internal{
        CastInfoMap[_mainBodyTokenId].tokenId = _mainBodyTokenId;
        CastInfoMap[_mainBodyTokenId].musicTokenId = _musicTokenId;
        CastInfoMap[_mainBodyTokenId].musicAddress = _musicAddress;
        CastInfoMap[_mainBodyTokenId].backgroundAddress = _backgroundAddress;
        CastInfoMap[_mainBodyTokenId].backgroundTokenId = _backgroundTokenId;
    }

    function getCastInfo(uint256 _tokenId)public view whenNotPaused returns(string memory){
        //require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        castInfo memory _castInfo = CastInfoMap[_tokenId];
        //string memory _tokenId = _uint2str(_castInfo.tokenId);
        string memory _musicTokenId = _uint2str(_castInfo.musicTokenId);
        string memory _musicAddress = _addressToString(_castInfo.musicAddress);
        string memory _backgroundTokenId = _uint2str(_castInfo.backgroundTokenId);
        string memory _backgroundAddress = _addressToString(_castInfo.backgroundAddress);
        string memory _agentAddress = _addressToString(_castInfo.agentAddress);
        string memory _castInfoStr = _contactStr(_musicTokenId,_musicAddress,_backgroundTokenId,_backgroundAddress,_agentAddress);
        return  _castInfoStr;
    }

    function _contactStr(string memory a, string memory b, string memory c, string memory d, string memory e) internal  pure returns (string memory) {
        return string(abi.encodePacked(a,"--", b,"--", c, "--",d,"--", e));
    }
    
    function _uint2str(uint _i) internal  pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    function _toString(bytes memory data) internal  pure returns(string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function _addressToString(address account) internal  pure returns(string memory) {
        return _toString(abi.encodePacked(account));
    }

    //Uncast function
    function uncast(uint256 _mainBodyTokenId) public whenNotPaused {
        IERC1155 mainBodyContract =  IERC1155(mainBodyContractAddress);
        require(mainBodyContract.balanceOf(msg.sender,_mainBodyTokenId)>0,"You don't have this NFT!");
        //Return used music
        _uncastMusic(_mainBodyTokenId);
        //Return used background
        _uncastBackground(_mainBodyTokenId);
        _setCastInfo(_mainBodyTokenId,0, address(0),0, address(0));

        //Return successful
        emit UncastSuccessful(_mainBodyTokenId,CastInfoMap[_mainBodyTokenId].musicTokenId,CastInfoMap[_mainBodyTokenId].musicAddress,CastInfoMap[_mainBodyTokenId].backgroundTokenId,CastInfoMap[_mainBodyTokenId].backgroundAddress);
    }

    //Check NFT ownership
    function _validateOwnership(uint256 _mainBodyTokenId,uint256 _musicTokenId,address _musicAddress,uint256 _backgroundTokenId,address _backgroundAddress)internal whenNotPaused view returns(bool){
        IERC1155 mainBodyContract =  IERC1155(mainBodyContractAddress);
        require(mainBodyContract.balanceOf(msg.sender,_mainBodyTokenId)>0);
        require(_validateSubContractOwnership(_musicTokenId,_musicAddress),"You don't have this music NFT!");
        require(_validateSubContractOwnership(_backgroundTokenId,_backgroundAddress),"You don't have this Background NFT!");
        return true;
    }

    //Check sub-NFT ownership
    function _validateSubContractOwnership(uint256 _contractTokenId,address _contractAddress)internal whenNotPaused view returns(bool){
        if (_checkProtocol(_contractAddress)){
            IERC1155 subContract = IERC1155(_contractAddress);
            if (subContract.balanceOf(msg.sender,_contractTokenId)>0){
                return true;
            }else{
                return false;
            }
        }else{
            IERC721 subContract = IERC721(_contractAddress);
            if (subContract.ownerOf(_contractTokenId) == msg.sender){
                return true;
            }else{
                return false;
            }
        }
    }

    //check if the contract is ERC1155 or ERC721
    function _checkProtocol(address _contractAddress)internal whenNotPaused view returns(bool){
        IERC165 Contract = IERC165(_contractAddress);
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC1155)){
            return true;
        }else{
            if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC721)){
                return false;
            }
            revert("Invalid contract protocol!");
        }
    }

    //Check if the NFT is allowed to be casted
    function _validateCastable(uint256 _mainBodyTokenId) internal whenNotPaused view returns (bool){
        require(!DisallowCastNFTMap[_mainBodyTokenId],"This NFT is not allowed to be casted!");
        return true;
    }

    //******SET UP******

    function setupOwner(address _owner)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        owner = _owner;
    }
    //Set up role
    function setupRole(address[] memory _allowAddresses,bytes32 _role)public whenNotPaused {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        for (uint256 i = 0; i < _allowAddresses.length; i++) {
            _setupRole(_role,_allowAddresses[i]);
        }
    }

    function setupCastSingleFee(uint256 _castSingleFee) public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        require(_castSingleFee > 0,"the price must be more than 0!");
        castSingleFee = _castSingleFee;
    }

       //Set up agent address
    function setupAgentAddress(address _agentAddress)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        agentAddress = _agentAddress;
    }

    //Set up disallow nft
    function setupDisallowCastNFT(uint256[] memory _disallowCastNFT)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        for (uint256 i = 0; i < _disallowCastNFT.length; i++) {
            DisallowCastNFTMap[_disallowCastNFT[i]] = true;
        }
    }

    //Set up main body contract address
    function setupMainBodyContractAddress(address _mainBodyContractAddress)public whenNotPaused{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        mainBodyContractAddress = _mainBodyContractAddress;
    }

    function appendCastInfo(uint256[] memory _mainBodyTokenIds,uint256[] memory _musicTokenIds,address[] memory _musicAddresses,uint256[] memory _backgroundTokenIds,address[] memory _backgroundAddresses) whenNotPaused public{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        for (uint256 i = 0; i < _mainBodyTokenIds.length; i++) {
                CastInfoMap[_mainBodyTokenIds[i]].tokenId = _mainBodyTokenIds[i];
                CastInfoMap[_mainBodyTokenIds[i]].musicTokenId = _musicTokenIds[i];
                CastInfoMap[_mainBodyTokenIds[i]].musicAddress = _musicAddresses[i];
                CastInfoMap[_mainBodyTokenIds[i]].backgroundAddress = _backgroundAddresses[i];
                CastInfoMap[_mainBodyTokenIds[i]].backgroundTokenId = _backgroundTokenIds[i];
        }
    }

    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _unpause();
    }
}
    //******END SET UP******/