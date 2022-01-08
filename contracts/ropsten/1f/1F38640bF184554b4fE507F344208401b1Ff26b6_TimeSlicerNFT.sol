//SPDX-License-Identifier: MIT


/**
88888888888 d8b                        .d8888b.  888 d8b                          
    888     Y8P                       d88P  Y88b 888 Y8P                          
    888                               Y88b.      888                              
    888     888 88888b.d88b.   .d88b.  "Y888b.   888 888  .d8888b .d88b.  888d888 
    888     888 888 "888 "88b d8P  Y8b    "Y88b. 888 888 d88P"   d8P  Y8b 888P"   
    888     888 888  888  888 88888888      "888 888 888 888     88888888 888     
    888     888 888  888  888 Y8b.    Y88b  d88P 888 888 Y88b.   Y8b.     888     
    888     888 888  888  888  "Y8888  "Y8888P"  888 888  "Y8888P "Y8888  888     
**/

pragma solidity ^0.8.7;
import "./ERC721B.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract TimeSlicerNFT is ERC721B, EIP712, Ownable {
    using Strings for uint256;
    using ECDSA for bytes32;

    uint256 public constant PRESALE_PRICE = 0.044 ether;
    uint256 public constant PUBLIC_PRICE = 0.066 ether;
    uint256 public constant PRESALE_LIMIT = 2;
    uint256 public constant PUBLIC_LIMIT = 2;
    uint256 public constant MAX_SUPPLY = 6666;
    uint256 public stage; // 1 for presale, 2 for public sale.


    string public baseURI;
    string private previewBaseURI;
    address public signerPresale;
    address public signerPrivate;

    bytes32 public constant MINTER_TYPEHASH =
        keccak256("Minter(address recipient,uint256 amount)"); 

    string private constant SIGNING_DOMAIN = "TimeSlicerNFT";
    string private constant SIGNATURE_VERSION = "1";

    event PresaleMint(address indexed minter, uint256 amount);
    event PublicMint(address indexed minter, uint256 amount);
    
    mapping(address => uint256) public publicMinter;
    mapping(address => uint256) public presaleMinter;
    mapping(address => uint256) public privateMinter;

    constructor() 
        ERC721B("TimeSlicerNFT","TIMESLICER")
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        previewBaseURI = "ipfs://QmSP37recqqoAusvhiDwhfG5C4jvgCz6ctWtaxBHjKwJDs/1";
        stage = 1;
        signerPresale = 0xbeef10b0f062386FB9429f139e36c531c6c80342; // address that used to sign presale sale
        signerPrivate = 0x1337BE1929eC626e4eF0d691455098E690785A86; // address that used to sign private sale (MUST BE different with presale)
    }

        
    /**
    @notice Mint NFT at presale period (only for whitelisted user)  
    @param _amount amount of NFT to be minted
    @param _signature EIP-712 signature (for whitelisting purpose)
    */
    function presaleMint(uint256 _amount, bytes calldata _signature) external payable {
        require(stage == 1, "PRESALE_DISABLED"); // Presale is disabled when public sale is active
        require(signerPresale == _verify(_msgSender(), PRESALE_LIMIT, _signature), "INVALID_SIGNER"); // check if signature match with our minter address
        require(presaleMinter[msg.sender] + _amount <= PRESALE_LIMIT,"LIMIT_EXCEEDED");
        require(PRESALE_PRICE * _amount <= msg.value, "INSUFFICIENT_FUNDS"); // check msg.value must be equal with price * amount

        uint256 supply = _owners.length;

        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(_msgSender(), supply++);
        }

        presaleMinter[msg.sender] += _amount;
        emit PresaleMint(msg.sender, _amount);
    }

    /**
    @notice Mint NFT for public user 
    @param _amount amount of NFT to be minted
    */
    function mint(uint256 _amount) external payable {
        require(stage == 2, "SALE_DISABLED");
        
        require(publicMinter[msg.sender] + _amount <= PUBLIC_LIMIT, "LIMIT_EXCEED");
        require((PUBLIC_PRICE *_amount) <= msg.value, "INSUFFICIENT_FUNDS");
        
        uint256 supply = _owners.length;

        require(
            (supply + _amount) < MAX_SUPPLY,
            "MAX_TOKEN_EXCEED"
        );
        publicMinter[msg.sender] += _amount;
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(msg.sender, supply++);
        }

        emit PublicMint(msg.sender, _amount);
    }
    /**
    @notice Mint NFT at presale period (only for whitelisted user)
    @param _amount amount of NFT to be minted
    @param _amountLimit amount limit of NFT to be minted (must match with signature)
    @param _signature EIP-712 signature (for whitelisting purpose)
     */
    function privateMint(uint256 _amount, uint256 _amountLimit, bytes calldata _signature) external {
        require(stage == 1, "PRESALE_DISABLED"); // Private mint only enabled on presale stage
        require(signerPrivate == _verify(_msgSender(), _amountLimit, _signature), "INVALID_SIGNER"); // check if signature match with our private minter address
        require(privateMinter[msg.sender] + _amount <= _amountLimit, "LIMIT_EXCEEDED");
        uint256 supply = _owners.length;

        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(_msgSender(), supply++);
        }

        privateMinter[msg.sender] += _amount;
        emit PresaleMint(msg.sender, _amount);
    }

    function gift(address _to, uint256 _amount) external onlyOwner {
        uint256 supply = _owners.length;
        require(
            (supply +_amount) < MAX_SUPPLY,
            "MAX_TOKEN_EXCEED"
        );
        for (uint256 i = 0; i < _amount; i++) {
            _safeMint(_to, supply++);
        }
    }
    /**
    @notice Set base URI for the NFT.  
    @param _uri IPFS URI
    */
    function setBaseURI(string calldata _uri) external onlyOwner {
        baseURI = _uri;
    }

    /**
    @notice Set stage  
    @param _stage current stage(0 = minting phase ended, 1 = presale, 2 = public)
    */
    function setStage(uint256 _stage) external onlyOwner {
        stage = _stage;
    }

    function setPrivateSigner(address _signer) external onlyOwner {
        signerPrivate = _signer;
    }
    function setPresaleSigner(address _signer) external onlyOwner {
        signerPresale = _signer;
    }

    function withdrawAll() external onlyOwner {
        require(address(this).balance > 0, "BALANCE_ZERO");
        payable(owner()).transfer(address(this).balance);

    }

    function tokenSupply() public view returns (uint256) {
        return _owners.length;
    }

    function getChainID() public view returns(uint){
        return block.chainid;
    }

    function _verify(address _recipient, uint256 _amountLimit, bytes calldata _sign)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(MINTER_TYPEHASH, _recipient, _amountLimit))
        );
        return ECDSA.recover(digest, _sign);
    }


    function tokenURI(uint256 _id)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(_id), "Token does not exist");

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _id.toString()))
                : previewBaseURI;
    }
}