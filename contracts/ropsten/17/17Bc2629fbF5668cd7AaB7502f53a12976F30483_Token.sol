// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


interface EscrowInt {
    function placeOrder(
        address _creator,
        uint256 _tokenId,
        uint256 _editions,
        uint256 _pricePerNFT,
        uint256 _saleType,
        uint256 _timeline,
        uint256 _adminPlatformFee,
        address _tokenAddress
    ) external returns (bool);
}

contract Token is ERC1155 {
    using SafeMath for uint256;

    uint256 public maxEditionsPerNFT;
    uint256 public tokenId;
    address[] public paymentTokens;

    struct owner {
        address creator;
        uint256 percent1;
        address coCreator;
        uint256 percent2;
    }

    enum Type {
        Instant,
        Auction
    }

    mapping(address => bool) public creator;
    mapping(uint256 => owner) private ownerOf;
    mapping(uint256 => string) public tokenURI;
    mapping(address => bool) public paymentEnabled;

    constructor(address _admin, address _escrowAddress)
        ERC1155("")
    {
        
        creator[_admin] = true;
        paymentEnabled[address(0)] = true;
        paymentTokens.push(address(0));
        require(_admin != address(0), "Zero admin address");
        require(_escrowAddress != address(0), "Zero Escrow address");
        admin = _admin;
        escrowAddress = _escrowAddress;
        EscrowInterface = EscrowInt(escrowAddress);
        
    }

// ERC1155

    address public escrowAddress;
    address public admin;
    EscrowInt public EscrowInterface;
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }


    function setEscrowAddress(address _escrowAddress) external onlyAdmin {
        require(_escrowAddress != address(0), "Zero escrow address");
        escrowAddress = _escrowAddress;
        EscrowInterface = EscrowInt(escrowAddress);
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        //require(_msgSender() == escrowAddress, "Only escrow contract");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "Not owner or not approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(_msgSender() == escrowAddress, "Only escrow contract");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155:Caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }
    
    function changeAdmin(address _admin) external onlyAdmin returns (bool) {
        require(_admin != address(0), "Zero admin address");
        admin = _admin;
        creator[_admin] = true;
        return true;
    }
    
    function setURI(string memory newuri) public {
        _setURI(newuri);
    }

    function approveCreator(address _creator) external onlyAdmin {
        creator[_creator] = true;
    }

    function disableCreator(address _creator) external onlyAdmin {
        creator[_creator] = false;
        
    }
    
    function addPaymentTokens(address tokenAddress) external onlyAdmin {
        require(tokenAddress != address(0), "Zero token address");
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            if (paymentTokens[i] == tokenAddress) {
                paymentEnabled[tokenAddress] = true;
            } else {
                paymentTokens.push(tokenAddress);
                paymentEnabled[tokenAddress] = true;
            }
        }
    }

    function disablePaymentTokens(address tokenAddress) external onlyAdmin {
        paymentEnabled[tokenAddress] = false;
    }

    function TokenURI(uint256 _tokenId) external view returns (string memory) {
        return tokenURI[_tokenId];
    }

    function ownerOfToken(uint256 _tokenId)
        public
        view
        returns (
            address,
            uint256,
            address,
            uint256
        )
    {
        return (
            ownerOf[_tokenId].creator,
            ownerOf[_tokenId].percent1,
            ownerOf[_tokenId].coCreator,
            ownerOf[_tokenId].percent2
        );
    }

    function setMaxEditions(uint256 _number) external onlyAdmin {
        require(_number > 0, "Zero editions per NFT");
        maxEditionsPerNFT = _number;
    }

    function mintToken(
        uint256 _editions,
        string memory _tokenURI,
        string memory _tokenURIMongo,
        address _creator,
        address _coCreator,
        uint256 _creatorPercent,
        Type _saleType,
        uint256 _timeline,
        uint256 _pricePerNFT,
        uint256 _adminPlatformFee,
        address tokenAddress
    ) external returns (bool) {
        require(_editions > 0, "Zero editions");
        require(_pricePerNFT > 0, "Zero price");
        require(bytes(_tokenURI).length > 0, "Invalid token URI");
        require(_adminPlatformFee < 51, "Admin fee too high");
        require(creator[msg.sender], "Only approved users can mint");
        require(
            paymentEnabled[tokenAddress],
            "Selected token payment disabled"
        );

        require(
            _saleType == Type.Instant || _saleType == Type.Auction,
            "Invalid saletype"
        );
        if (_saleType == Type.Instant) {
            require(_timeline == 0, "Invalid time for Buy Now");
        } else if (_saleType == Type.Auction && msg.sender != admin) {
            require(
                _timeline == 12 || _timeline == 24 || _timeline == 48,
                "Incorrect time"
            );
        }
        if (msg.sender != admin) {
            require(
                _editions <= maxEditionsPerNFT,
                "Editions greater than allowed"
            );
            require(msg.sender == _creator, "Invalid Parameters");
        }
        require(
            _creatorPercent <= 100,
            "Creator over 100 percent"
        );
        if (msg.sender == admin) {
            _adminPlatformFee = _adminPlatformFee;
        } else {
            _adminPlatformFee = 0;
        }
        tokenId = tokenId.add(1);
        setURI(_tokenURI);
        _mint(escrowAddress, tokenId, _editions, "");
        setApprovalForAll(_creator, true);
        {
            tokenURI[tokenId] = _tokenURIMongo;
            ownerOf[tokenId] = owner(
                _creator,
                _creatorPercent,
                _coCreator,
                100 - _creatorPercent
            );
            EscrowInterface.placeOrder(
                _creator,
                tokenId,
                _editions,
                _pricePerNFT,
                uint256(_saleType),
                _timeline,
                _adminPlatformFee,
                tokenAddress
            );
        }
        return true;
    }

    function burn(
        address from,
        uint256 _tokenId,
        uint256 amount
    ) external returns (bool) {
        require(msg.sender == escrowAddress, "Only escrow");
        _burn(from, _tokenId, amount);
        return true;
    }
}