// SPDX-License-Identifier: MIT

pragma solidity >=0.4.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract  ICompRandom {
    function simpleRandom(string memory luckyData,uint pointer) public view virtual returns  (bytes32);
}

abstract contract INMT{
    function balanceOf(address account) external view  virtual returns (uint256);
}

contract Comp is ERC721, Ownable{
    // Mapping from token ID to gene
    mapping (uint256 => string) public geneMap;

    // Mapping from gene to token ID
    mapping (string => uint256) public gene2TokenIdMap;

    //all mint history
    mapping (address => uint256) public mintDate;
    mapping (address => uint256) public addressMintAmount;
    mapping (uint256 => uint256) public dailyAmount;

    //auto increasing tokenid;
    uint256  public tokenId=1;
    uint public totalSupply=10000;
    int256 private baseNMT = -100;

    string private _uri;



    //all gene template
    uint8[][] private _geneTemplates = [
        [ 5, 9, 9,10, 9, 0, 0, 0],
        [ 5, 10, 9, 9, 9,10, 0, 0],
        [ 5, 9, 9, 9, 9, 9, 0, 0],
        [ 5, 9,10, 9,10, 9, 9, 9]
    ];

    // random contract
    address  public randomContract= address(0x29B35f0cafBccd12928cd968A0Fc267B544bCe45);
    address  public NMTERC20Contract= address(0x6E01d408682FE6a654925AA4E05F945d23D2b10a);

//    address  public randomContract= address(0x8427248D38D3756CC9Ae8861C1A537dab5376EeD);
//    address  public NMTERC20Contract= address(0xd742C20DDe8474f74026df193AA12f26f96e3e65);


    event SetURI(string);
    event SetBaseNMT(int256);
    event SetRandomContract(address);


    /**
    * Init metadata url
    *
    */
    constructor() ERC721("Chinese Opera Mask Plus","COMP"){
        _uri = "http://www.chineseoperamaskplus.com/assets/data/";
    }

    /**
    * Update metadate url
    *
    * onlyOwner
    *
    * Emits a {SetURI} event.
    *
    * Requirements:
    * - `newuri`
    */
    function setURI(string memory newuri) public onlyOwner{

        _uri = newuri;
        emit SetURI(newuri);
    }

    function _baseURI() internal view override returns(string memory){
        return _uri;
    }

    /**
    * Update base NMT
    *
    * onlyOwner
    *
    * Emits a {SetBaseNMT} event.
    *
    * Requirements:
    * - `baseNMT`*
    */
    function setBaseNMT(int256 amount) public onlyOwner{
        baseNMT = amount;
        emit SetBaseNMT(amount);
    }

    /**
    * update random contract
    *
    * onlyOwner
    *
    *  Emits a {SetRandomContract} event.
    *
    * Requirements
    * - `randomAddress`   random contract address
    */
    function  setRandomContract(address randomAddress) public onlyOwner{

        require(randomAddress != address(0), "Comp: set zero address");

        randomContract = randomAddress;

        emit SetRandomContract(randomAddress);
    }

    /**
    * @dev Mint new NFT
    *
    * This is internal function is equivalent to {transfer}, and can be used to
    * e.g. implement automatic token fees, slashing mechanisms, etc.
    *
    * Emits a {Transfer} event.
    *
    * Requirements:
    *
    * - `luckyDate` cannot be the null.
    */
    function mint(string memory luckyData) public{

        //up to 10000
        require(  totalSupply >= tokenId, "Comp: Has reached totalSupply ");

        //daily mining
        uint256 nmtAmount = _getNMTAmount();
        require( int256(nmtAmount) > (baseNMT + int256(tokenId)), "Comp: not enough NMT");

        //up to 5
//        require(  addressMintAmount[msg.sender] < 5, "Comp: One address can mint up to 5");
        //utc data timestamp

        uint256 timestamp =  block.timestamp;
        uint256 coolingTime = (addressMintAmount[msg.sender]/5 + 1 )* (24 * 3600);
//        require(mintDate[msg.sender]+ coolingTime <  timestamp  , "Comp: during cooling time");

        //up to 1000 per day
        uint256 dateTimestamp = block.timestamp - block.timestamp%(24*3600);
        require(  dailyAmount[dateTimestamp] < 1000, "Comp: Up to 1000 per day");



        (string memory gene,string memory bg_gene) = _generateGene(luckyData);
        while(gene2TokenIdMap[gene] >0 ){ //Whether the gene is occupied
            luckyData = string(abi.encodePacked(luckyData,"_")); //new luckyData
            (gene,bg_gene) = _generateGene(luckyData);
        }
        geneMap[tokenId] = string(abi.encodePacked(gene,"_",bg_gene));
        gene2TokenIdMap[gene] = tokenId;
        _mint(msg.sender,tokenId);

        addressMintAmount[msg.sender] ++;
        dailyAmount[dateTimestamp]++;
        mintDate[msg.sender] = timestamp;
        tokenId++;  //start from 1
    }


    /**
    * show NFT uri with token id
    *
    * Requirements
    * - `id`  tokenId
    */
    function tokenURI(uint256 id) public view override returns (string memory) {
        string memory gene = geneMap[id];
        return string(abi.encodePacked(_uri, Strings.toString(id),".json?gene=",gene));
    }


    function _getNMTAmount() internal view returns(uint256){
        INMT nmt = INMT(NMTERC20Contract);
        return nmt.balanceOf(msg.sender);
    }
    /**
    *
    * generate gene from luckData
    *
    * Requirements
    * - `luckyData`  lucky key
    */
    function _generateGene(string memory luckyData) internal view returns(string memory,string memory){
        uint8 preGenes = 255;
        uint8 backgroudColorSize = 9;
        string memory geneStr = "";

        ICompRandom random = ICompRandom(randomContract);
        bytes32 str = random.simpleRandom(luckyData,tokenId);
        //1: template
        uint256 templateId =  uint8(str[0])%_geneTemplates.length;

        uint8[] memory templateInfo = _geneTemplates[templateId];
        geneStr = Strings.toString(templateId);
        //2: add eye + maskup
        for(uint8 i=0; i< templateInfo.length;i++){
            if(0==templateInfo[i]){
                break;
            }
            uint8 geneRandomNum = uint8(str[i+1]);
            uint8 gene = geneRandomNum % templateInfo[i]+1;
            if(preGenes==gene && (gene!=10) && (preGenes != 10)){
                geneRandomNum++;
                gene = geneRandomNum %templateInfo[i]+1;
            }
            geneStr = string(abi.encodePacked(geneStr, '_',Strings.toString(gene)));
            preGenes = gene;
        }
        return (geneStr,Strings.toString(
            uint8 (str[str.length-1]) % backgroudColorSize + 1 //last one is bg color
        ));
    }
}