// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RNFTGeneric is ERC1155{
    string  baseUri     = "https://ipfs.io/ipfs/";
    string  completeUri = "https://ipfs.io/ipfs/{cid}";
    address contract_owner;
    uint256 RNFTRequest;
    uint256 holdersCount;
    uint256 mintingLimit= 10000;
    
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
    mapping(uint256 => uint256)    projectMints;
    mapping(uint256 => bool)       tokenExists;


    constructor() public ERC1155(completeUri) {
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

    function getRNFTHolders(uint256 RNFTId) public view returns(address[] memory){
       return  RNFTHolders[RNFTId];
    }

    function uri(uint256 tokenId) override public view returns (string memory){
        return(
        string(abi.encodePacked(
         "https://ipfs.io/ipfs/",
        RNFTProjectDetails[tokenId].cid
          ))
      );
    }

    function createRNFTRequest(string memory cid, uint256 budget, uint256 price) public {
        require(bytes(cid).length > 0, "icid");
        RNFTRequest++;
        RNFTProjectDetails[RNFTRequest] = RNFT({
            cid    : cid,
            creator  : msg.sender,
            budget : budget,
            status : RNFTStatus.OPEN,
            price  : price
        });
        tokenExists[RNFTRequest] = true;
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

    function burn(address account,uint256 id, uint256 amount) external OnlyOwner{
       _burn(account, id, amount);
    }

    function airdrop(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external OnlyOwner{
       _mintBatch(to, ids, amounts, data);
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
        require(msg.value == RNFTProjectDetails[tokenId].price*amount, 'wa');
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

    function listRNFT(uint256 RNFTId) external{
    require(tokenExists[RNFTId] == true, 'It');
    require(RNFTProjectDetails[RNFTId].status != RNFTStatus.DENIED, 'osa');
    uint256 valid;
    if(msg.sender == RNFTProjectDetails[RNFTId].creator || msg.sender == contract_owner) {
     valid = 1;
    }
    require(valid == 1, "NTC");
    RNFTProjectDetails[RNFTId].status = RNFTStatus.ONSALE;
    }

    function unListRNFT(uint256 RNFTId) external{
    require(tokenExists[RNFTId] == true, 'It');
    uint256 valid;
    if(msg.sender == RNFTProjectDetails[RNFTId].creator || msg.sender == contract_owner) {
     valid = 1;
    }
    require(valid == 1, "NTC");
    RNFTProjectDetails[RNFTId].status = RNFTStatus.REMOVED;
    }

    function transferToken(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual{
        require(balanceOf(from,id) > 0,'nh');
        if(balanceOf(to,id) <= 0){
        RNFTHolders[id].push(to); 
        holdersCount++;
        }
        super.safeTransferFrom(from, to, id, amount, data);
      }
}