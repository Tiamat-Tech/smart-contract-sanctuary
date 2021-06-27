// SPDX-License-Identifier: MIT

pragma solidity >=0.4.25;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract  ICompRandom {
    function simpleRandom(string memory luckyData,uint pointer) public view virtual returns  (bytes32);
}

abstract contract INMT{
    function balanceOf(address account) external view  virtual returns (uint256);
}

contract Comp is ERC1155, Ownable{
    // Mapping from token ID to gene
    mapping (uint256 => string) public geneMap;

    // Mapping from gene to token ID
    mapping (string => uint256) public _gene2TokenIdMap;

    //all mint history
    mapping (address => uint256) private _mintDate;
    mapping (address => uint256) public addressMintAmount;
    mapping (uint256 => uint256) public dailyAmount;

    //auto increasing tokenid;
    uint256  public tokenId=1;
    int256 private baseNMT = -100;





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

    event SetURI(string);
    event SetBaseNMT(int256);
    event SetRandomContract(address);


    /**
    * Init metadata url
    *
    */
    constructor() ERC1155("http://www.chineseoperamaskplus.com/assets/data/") {
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
        _setURI(newuri);

        emit SetURI(newuri);
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
    * Emits a {TransferSingle} event.
    *
    * Requirements:
    *
    * - `luckyDate` cannot be the null.
    */
    function mint(string memory luckyData) public{

        //up to 10000
        require(  10000 > tokenId, "Comp: Has reached 10000 ");

        //daily mining
        uint256 nmtAmount = _getNMTAmount();
        require( int256(nmtAmount) > (baseNMT + int256(tokenId)), "Comp: not enough NMT");

        //up to 5
        require(  addressMintAmount[msg.sender] < 5, "Comp: One address can mine up to 5");
        //utc data timestamp
        uint256 dataTimestamp =  block.timestamp - block.timestamp%(24*3600);
        require(_mintDate[msg.sender] < dataTimestamp , "Comp: mint once a day");

        //up to 1000 per day
        require(  dailyAmount[dataTimestamp] < 1000, "Comp: Up to 1000 per day");



        (string memory gene,string memory bg_gene) = _generateGene(luckyData);
        while(_gene2TokenIdMap[gene] >0 ){ //Whether the gene is occupied
            luckyData = _strConcat(luckyData,"_"); //new luckyData
            (gene,bg_gene) = _generateGene(luckyData);
        }
        geneMap[tokenId] = _strConcat(gene,_strConcat("_",bg_gene));
        _gene2TokenIdMap[gene] = tokenId;
        _mint(msg.sender,tokenId,1,"");

        addressMintAmount[msg.sender] ++;
        dailyAmount[dataTimestamp]++;
        _mintDate[msg.sender] = dataTimestamp;
        tokenId++;  //start from 1
    }


    /**
    * show NFT uri with token id
    *
    * Requirements
    * - `id`  tokenId
    */
    function uri(uint256 id) public view override returns (string memory) {
        string memory gene = geneMap[id];
        return  _strConcat(_strConcat(super.uri(id), Strings.toString(id)), _strConcat(".json?gene=",gene));
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
            if(preGenes==gene){
                geneRandomNum++;
                gene = geneRandomNum %templateInfo[i]+1;
            }
            geneStr = _strConcat(geneStr, _strConcat('_',Strings.toString(gene)));
            preGenes = gene;
        }
        return (geneStr,Strings.toString(
            uint8 (str[str.length-1]) % backgroudColorSize  //last one is bg color
        ));
    }

    /**
    *  tool str concat
    *
    * Requirements
    * - `_a`  string
    * - `_b`  string
    */
    function _strConcat(string memory _a, string memory _b) internal pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++){
            bret[k++] = _ba[i];
        }
        for (uint i = 0; i < _bb.length; i++){
            bret[k++] = _bb[i];
        }
        return string(ret);
    }

}