// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

contract RNFTGeneric is Initializable, ERC1155Upgradeable{
    string  baseUri;
    string  completeUri;
    address contract_owner;
    uint256 RNFTRequest;
    uint256 holdersCount;
    uint256 mintingLimit;
    
    struct RNFT {
        string cid;
        address creator;
        RNFTStatus status;
        uint256 budget;
        uint256 price;
    }

    enum RNFTStatus {
        OPEN,
        DENIED,
        CREATED,
        ONSALE,
        SOLDOUT,
        FINISHED,
        REMOVED
    }
    
    mapping(uint256 => address[])  RNFTHolders;
    mapping(uint256 => RNFT)       RNFTProjectDetails;
    mapping(address => RNFT[])     RNFTProjectListByCreator;
    mapping(uint256 => uint256)    projectMints;
    mapping(uint256 => bool)       tokenExists;

    function initialize() public initializer {
        mintingLimit=10000;
        baseUri = "https://sandbox.com.co/api/test/";
        completeUri = "https://sandbox.com.co/api/test/{id}.jpg";
        __ERC1155_init(completeUri);
        contract_owner = msg.sender;
    }

    modifier ProjectOwnerOnly(uint256 RNFTId) {
        require(msg.sender == RNFTProjectDetails[RNFTId].creator, "NTC");
        _;
    }

    modifier OnlyOwner() {
        require(msg.sender == contract_owner, "NTC");
        _;
    }

    function setURI(string memory newuri) external OnlyOwner{
        _setURI(newuri);
    }

    function setBaseURI(string memory newuri) external OnlyOwner{
        baseUri = newuri;
    }

    function uri(uint256 tokenId) override public view returns (string memory){
        return(
        string(abi.encodePacked(
         baseUri,
         StringsUpgradeable.toString(tokenId),
          ".json"
          ))
      );
    }

    function createRNFTRequest(string memory cid, uint256 budget) public {
        require(bytes(cid).length > 0, "icid");
        RNFTRequest++;
        RNFTProjectDetails[RNFTRequest] = RNFT({
            cid    : cid,
            creator  : msg.sender,
            budget : budget,
            status : RNFTStatus.OPEN,
            price  : 0
        });
        tokenExists[RNFTRequest] = true;
        RNFTProjectListByCreator[msg.sender].push(RNFTProjectDetails[RNFTRequest]);
    }

    function denyRNFTRequest(uint256 RNFTId) external OnlyOwner {
        require(tokenExists[RNFTId] == true, 'It');
        RNFTProjectDetails[RNFTId].status = RNFTStatus.DENIED;
    }

    function processRNFTRequest(uint256 RNFTId) external OnlyOwner{
        require(tokenExists[RNFTId] == true, 'It');
        RNFTProjectDetails[RNFTId].status = RNFTStatus.CREATED;
    }

    function showRNFT(uint256 RNFTId)  public view returns(RNFT memory){
       return  RNFTProjectDetails[RNFTId];
    }

    function showCreatorRNFT(address user)  public view returns(RNFT[] memory){
       return RNFTProjectListByCreator[user];
    }

    function burn(address account,uint256 id, uint256 amount) external OnlyOwner{
       _burn(account, id, amount);
    }

    function airdrop(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external OnlyOwner{
       _mintBatch(to, ids, amounts, data);
    }

    function setRNFTSalePrice(uint256 amount, uint256 RNFTId) external OnlyOwner{
       RNFTProjectDetails[RNFTId].price =  amount;
    }

    function getRNFTHolders(uint256 RNFTId) public view returns(address[] memory){
       return  RNFTHolders[RNFTId];
    }

    function setRNFTBudget(uint256 amount, uint256 RNFTId) external OnlyOwner{
        RNFTProjectDetails[RNFTId].budget =  amount;
    }

    function sendShares(uint256 tokenId) public payable OnlyOwner{
    uint256 amount = msg.value / 10000;
    for (uint256 index = 0; index < RNFTHolders[tokenId].length; index++) {
        if(balanceOf(RNFTHolders[tokenId][index],tokenId) > 0){
        uint256 balance = balanceOf(RNFTHolders[tokenId][index], tokenId);
        payable(RNFTHolders[tokenId][index]).transfer(amount*balance);
        }
    }
    }
    
    function buyRNFT(uint256 amount, uint256 tokenId) external payable{
        require(tokenExists[tokenId] == true, 'Invalid token');
        require(RNFTProjectDetails[tokenId].status == RNFTStatus.ONSALE, 'nos');
        require(msg.value == RNFTProjectDetails[tokenId].price, 'wa');
        if(!(balanceOf(msg.sender,tokenId) > 0)){
            RNFTHolders[tokenId].push(msg.sender); 
        }
        _mint(msg.sender, tokenId, amount, "");
        holdersCount++;
        uint256 currentMint = projectMints[tokenId];
        currentMint++;
        projectMints[tokenId] = currentMint;
        if(currentMint >= mintingLimit){
             RNFTProjectDetails[tokenId].status = RNFTStatus.SOLDOUT;
        }
    }
    
    function withdraw(uint256 amount) public{
    payable(contract_owner).transfer(amount);
    }

    function listRNFT(uint256 RNFTId) external ProjectOwnerOnly(RNFTId){
    require(tokenExists[RNFTId] == true, 'It');
    require(RNFTProjectDetails[RNFTId].status != RNFTStatus.DENIED, 'osa');
    RNFTProjectDetails[RNFTId].status = RNFTStatus.ONSALE;
    }

    function unListRNFT(uint256 RNFTId) external OnlyOwner{
    require(tokenExists[RNFTId] == true, 'It');
    RNFTProjectDetails[RNFTId].status = RNFTStatus.REMOVED;
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
      override public virtual{
        require(balanceOf(from,id) > 0,'nh');
        if(balanceOf(to,id) <= 0){
        RNFTHolders[id].push(to); 
        holdersCount++;
        }
        super.safeTransferFrom(from, to, id, amount, data);
      }
}