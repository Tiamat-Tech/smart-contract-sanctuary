// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "./ISlave.sol";
//import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "./Club.sol";

contract Hornymals is ERC721EnumerableUpgradeable,   OwnableUpgradeable,Club, UUPSUpgradeable {
    using StringsUpgradeable for uint256;
    //using SafeMathUpgradeable for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_MINTS = 5;
    uint256 public price;
    uint256 public presalePrice;
    uint256 public reserved;
    uint256 private randNonce;
    uint256 public startingIndexBlock;
    uint256 public startingIndex;
    bytes32 public merkleRoot;
    address public artistAddress;
    uint8 public season;
    uint8 public extraStars;
    bool public saleActive;
    bool public presaleActive;
    address  public stardustTokenAddress;
    address public slaveContractAddress;
    string public baseURI;
    string public PROVENANCE;
    mapping(uint256 => uint8) private _stars;
    mapping(uint256 => uint8) private _breedInfo;
    mapping(address => uint256) private _allowed;



    function initialize(address stardustToken) initializer public{
        stardustTokenAddress = stardustToken;
        price = 0.05 ether;
        presalePrice = 0.04 ether;
        reserved = 104;
        __ERC721_init("Hornymals", "Hornymals");
        __ERC721Enumerable_init();
        //__AccessControl_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }
    function setArtist(address _artistAddress)public onlyOwner{
        artistAddress = _artistAddress;
    }



    function mint(uint256 _nbTokens) external payable {
        require(saleActive, "Sale not active");
        require(_nbTokens <= MAX_MINTS, "Exceeds max token purchase.");
        uint256 supply = totalSupply();
        require(supply + _nbTokens <= MAX_SUPPLY - reserved, "Not enough Tokens left.");
        require(_nbTokens * price <= msg.value, "Sent incorrect ETH value");
        for (uint256 i=0; i < _nbTokens; i++) {
            _safeMint(msg.sender, supply +i);
        }
    }
    function preMint(bytes32[] calldata _proof, uint256 _nbTokens) external payable{
        require(msg.sender == tx.origin, "Can't mint through another contract");
        require(presaleActive, "Presale not active");
        bytes32 node = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProofUpgradeable.verify(_proof, merkleRoot, node), "Not on allow list");
        require(_allowed[msg.sender] + _nbTokens<= MAX_MINTS, "Exceeds mint limit");
        uint256 supply = totalSupply();
        require(supply + _nbTokens <= MAX_SUPPLY - reserved, "Not enough Tokens left.");
        require(presalePrice * _nbTokens <= msg.value, "Sent incorrect ETH value");

        if (_allowed[msg.sender] > 0) {
            _allowed[msg.sender] = _allowed[msg.sender] + _nbTokens;
        } else {
            _allowed[msg.sender] = _nbTokens;
        }


        for (uint256 i=0; i < _nbTokens; i++) {
            _safeMint(msg.sender, supply +i);
        }
    }
    function isPreMinter(bytes32[] calldata _proof,address preMinter) public view returns (bool){
        bytes32 node = keccak256(abi.encodePacked(preMinter));
     return MerkleProofUpgradeable.verify(_proof, merkleRoot, node);
    }
    function getLeaf(address myAddress)public view returns (bytes32){
        return  keccak256(abi.encodePacked(myAddress));
    }
    /*function freeMint() external onlyRole(FREE_MINTER_ROLE){
        renounceRole(FREE_MINTER_ROLE, msg.sender);
        uint256 supply = totalSupply();
        _safeMint(msg.sender, supply);
        reserved--;
    }*/

    function starsOfToken(uint256 tokenId) public view returns (uint8){
        require(_exists(tokenId), "Stars: query for nonexistent token");
        return  _stars[tokenId];

    }
    function usedBreeds(uint tokenId) public view returns(uint8){
        require(_exists(tokenId), "Breeds: query for nonexistent token");
        uint8 myBreeds = _breedInfo[tokenId];
        return myBreeds%10;
    }
    function breedInfo(uint256 tokenId)public view returns(uint8){
        require(_exists(tokenId), "Breeds: query for nonexistent token");
        return _breedInfo[tokenId];
    }

    function togglePresaleActive() external onlyOwner {
        presaleActive = !presaleActive;
    }

    function toggleSaleActive() external onlyOwner {
        saleActive = !saleActive;
    }
    function setSeason(address slaveAddress , uint8 newSeason, uint8 newExtraPrice) external artistOrOwner {
        season = newSeason;
        slaveContractAddress = slaveAddress;
        extraStars = newExtraPrice;
    }
    function buyStars(uint256 tokenId, uint8 starsToBuy) public {
        address  from = msg.sender;
        require(ownerOf(tokenId) == from, "You are not the owner of the Hornymal");
        require(starsOfToken(tokenId) + starsToBuy <=5, "Cant buy that many stars");
        uint256 amount =  starsToBuy *100 ether;
        require(IERC20Upgradeable(stardustTokenAddress).allowance(from, address(this)) >= amount , "First, approve more stardust to this contract!");
        IERC20Upgradeable(stardustTokenAddress).transferFrom(from, address(this),amount);
        _stars[tokenId] +=starsToBuy;
        if(_stars[tokenId]>=5){
            _addMember(tokenId);
        }

    }
    function buyStarsMultiple(uint256[] calldata tokenIds, uint8[] calldata numberOfStars) public{
        address  from = msg.sender;
        uint256 amount=0;
        for(uint256 index=0;index<tokenIds.length;index++){
            require(ownerOf(tokenIds[index]) == from, "You are not the owner of all the Hornymals");
            require(_stars[tokenIds[index]]+numberOfStars[index]<=5,"Not more than five stars");
            amount += numberOfStars[index];
        }
        amount = amount*100 ether;
        require(IERC20Upgradeable(stardustTokenAddress).allowance(from, address(this)) >= amount , "First, approve more stardust to this contract!");
        IERC20Upgradeable(stardustTokenAddress).transferFrom(from, address(this),amount);
        for(uint256 index=0;index<tokenIds.length;index++){
            _stars[tokenIds[index]] +=numberOfStars[index];
            if(_stars[tokenIds[index]]==5){
                _addMember(tokenIds[index]);
            }
        }

}
    function fillUpStars(uint256[] calldata tokenIds) public {
        address  from = msg.sender;
        uint amount=0;
        for(uint256 index=0;index<tokenIds.length;index++){
            require(ownerOf(tokenIds[index]) == from, "You are not the owner of the Hornymal");
            amount += 5-_stars[tokenIds[index]];
        }
        amount =amount *100 ether;
        require(IERC20Upgradeable(stardustTokenAddress).allowance(from, address(this)) >= amount , "First, approve more stardust to this contract!");
        IERC20Upgradeable(stardustTokenAddress).transferFrom(from, address(this),amount);
        for(uint256 index=0;index<tokenIds.length;index++){
            _stars[tokenIds[index]]=5;
            _addMember(tokenIds[index]);
        }
    }
    function drawWinner() public artistOrOwner{
        uint256 mp=numberOfMembers();
        require(mp>0 ,"No members in club");
        uint256 clubIndex = pseudoRandom(mp);
        uint256 tokenId =getMemberByIndex(clubIndex);
        address winner= ownerOf(tokenId);
        uint256 supply = totalSupply();
        _safeMint(winner, supply);
        reserved --;
        emit LotteryWin(winner, supply);
    }



    function setBaseURI(string memory _URI) external onlyOwner{
        baseURI = _URI;
    }
    function setStardustToken(address stardustAddress) external onlyOwner {
        stardustTokenAddress = stardustAddress;
    }

    function _baseURI() internal view override(ERC721Upgradeable) returns(string memory) {
        return baseURI;
    }

    // Make it possible to change the price: just in case
    function setPrice(uint256 _newPrice) external artistOrOwner {
        price = _newPrice;
    }



    function withdraw() public artistOrOwner {
        uint256 balance = address(this).balance;
        uint256 split = balance/10;
        require(artistAddress!=address(0), "Set an artist address!");
        require(payable(owner()).send(split), "owner not payable");
        require(payable(artistAddress).send(balance-split), "artist not payable");
    }
    function withdrawTokens() public onlyOwner {
        uint256 balance = IERC20Upgradeable(stardustTokenAddress).balanceOf(address(this));
        IERC20Upgradeable(stardustTokenAddress).transfer(msg.sender, balance);
    }



    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721EnumerableUpgradeable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    function tokenURI(uint256 tokenId) public view
    override(ERC721Upgradeable)
    returns (string memory){
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    //string memory _baseURI = _baseURI();
        uint myStars = starsOfToken(tokenId);
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, myStars.toString(),"/",tokenId.toString())) : "";
    }
    function getAnimalType(uint256 tokenId) internal pure returns (uint8){
        return uint8(tokenId % 14);
    }
    function breed(uint256 parentOneId, uint256 parentTwoId) external{
        require( season == 1, "This is not the breeding-season");
        require(msg.sender == ownerOf(parentOneId) && msg.sender == ownerOf(parentTwoId), "You are not the owner");

        uint8 usedOne= _breedInfo[parentOneId]%10;
        require(usedOne<5, "Parent one cant breed anymore");
        uint8 usedTwo = _breedInfo[parentTwoId]%10;
        require(usedTwo<5, "Parent two cant breed anymore");
        uint8 starsOne = _stars[parentOneId];//starsOfToken(parentOneId);
        uint8 priceOne = usedOne +1;
        require(starsOne>=priceOne , "Parent one has not enough star");
        if(starsOne==5){
           _removeMember(parentOneId);
        }
        uint8 starsTwo = _stars[parentTwoId];//tokenId]starsOfToken(parentTwoId);
        uint8 priceTwo = usedTwo+1;
        require(starsTwo>=priceTwo, "Parent two has not enough star");
        if(starsTwo==5){
            _removeMember(parentTwoId);
        }

        uint256 rnd = pseudoRandom(2);
            if(rnd == 0){
                ISlave(slaveContractAddress).masterMint(msg.sender,parentOneId, _breedInfo[parentOneId] );
                _breedInfo[parentOneId]+=11;
                _breedInfo[parentTwoId]++;

            }
        else{
                ISlave(slaveContractAddress).masterMint(msg.sender, parentTwoId,  _breedInfo[parentTwoId]);
                _breedInfo[parentOneId]++;
                _breedInfo[parentTwoId]+=11;
            }
    _stars[parentOneId] -=priceOne;
    _stars[parentTwoId] -=priceTwo;

     }

    function pseudoRandom(uint256 moduloParameter) internal returns(uint256)
    {
        // increase nonce
        randNonce++;

        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % moduloParameter;
    }


    function useOffer(uint256 tokenId) external{
        require(season>1, "There is not any suitable offers available at the moment");
        require(msg.sender == ownerOf(tokenId) , "You are not the owner");
        uint8 stars = starsOfToken(tokenId);
        uint8 starsToUse = 1+ extraStars;

        require(stars>= starsToUse, "The Hornymal has not enough star");
        if(stars==5){
            _removeMember(tokenId);
        }
        ISlave(slaveContractAddress).masterMint(msg.sender, tokenId, 0);
        _stars[tokenId] = _stars[tokenId] -starsToUse;
    }

    /*function freeList( address[] calldata freeMinters) external onlyOwner{
        require(totalSupply()+ reserved + freeMinters.length <= MAX_SUPPLY, "Not enough left to reserve");
        for(uint i=0 ; i<freeMinters.length;i++){
            grantRole(FREE_MINTER_ROLE, freeMinters[i]);
        }
        reserved +=  freeMinters.length;
    }
    function preList( address[] calldata preMinters) external onlyOwner{
        require(totalSupply()+ reserved + preMinters.length <= MAX_SUPPLY, "Not enough left to reserve");
        for(uint i=0 ; i<preMinters.length;i++){
            grantRole(PRE_MINTER_ROLE, preMinters[i]);
        }
        reserved +=  preMinters.length;
    }*/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal  override(ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }



    function _authorizeUpgrade(address) internal override onlyOwner{

    }
    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        PROVENANCE = provenanceHash;
    }



    modifier artistOrOwner(){
        require(artistAddress == _msgSender() || owner() ==_msgSender(), "Caller is not artist or owner");
        _;
    }
    function setStartingIndex() public {
        require(startingIndex == 0, "Starting index is already set");
        require(startingIndexBlock != 0, "Starting index block must be set");

        startingIndex = pseudoRandom(MAX_SUPPLY);
       // Prevent default sequence
        if (startingIndex == 0) {
            startingIndex ++;
        }
    }

    /**
     * Set the starting index block for the collection, essentially unblocking
     * setting starting index
     */
    function setStartingIndexBlock() public onlyOwner {
        require(startingIndex == 0, "Starting index is already set");
        startingIndexBlock = block.number;
    }
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }
}