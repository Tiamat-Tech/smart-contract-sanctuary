// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IQLF.sol";

// Baby Princess Ape Club(B.P.A.C)
contract BPAC is ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string baseURI;

    // Token name
    string internal ext_name;

    // Token symbol
    string internal ext_symbol;

    struct PaymentOption {
        address token_addr;
        uint256 price;
    }

    struct PaymentInfo {
        // A token address for payment:
        // 1. ERC-20 token address
        // 2. adderss(0) for ETH
        address token_addr;
        uint256 price;
        uint256 receivable_amount;
    }

    // public sale purchage limit: maxmimum number of NFT(s) user can buy
    uint32 public_sale_purchase_limit;

    // `presale limit` is part of the merkle proof, so it is not here

    // total NFT(s) in stock, not including `airdrop`
    uint32 total_quantity;

    // whitelist sale start time
    uint32 presale_start_time;

    // public sale start time
    uint32 public_sale_start_time;

    // total number of NFT(s) sold
    uint32 sold_quantity;

    // payment info, price/tokens, etc
    PaymentInfo[] payment_list;

    // treasury address, receiving ETH/tokens
    address payable treasury;

    // how many NFT(s) purchased: public sale
    mapping(address => uint32) public public_purchased_by_addr;

    // how many NFT(s) purchased: presale
    mapping(address => uint32) public presale_purchased_by_addr;

    // presale whitelist merkle root
    bytes32 public merkle_root;

    // smart contract admin
    mapping(address => bool) public admin;

    // default URI[before NFT mystery box reveal]
    string defaultURI;

    // whitelist sale end time
    uint32 presale_end_time;

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _defaultURI_,
        uint32 _public_sale_purchase_limit,
        uint32 _total_quantity,
        uint32 _presale_start_time,
        uint32 _presale_end_time,
        uint32 _public_sale_start_time,
        PaymentOption[] calldata _payment,
        bytes32 _merkle_root,
        address payable _treasury
    )
        public
        initializer
    {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Ownable_init();
        ext_name = _name;
        ext_symbol = _symbol;
        defaultURI = _defaultURI_;
        public_sale_purchase_limit = _public_sale_purchase_limit;
        total_quantity = _total_quantity;
        presale_start_time = _presale_start_time;
        presale_end_time = _presale_end_time;
        public_sale_start_time = _public_sale_start_time;
        for (uint256 i = 0; i < _payment.length; i++) {
            if (_payment[i].token_addr != address(0)) {
                require(IERC20(_payment[i].token_addr).totalSupply() > 0, "Not a valid ERC20 token address");
            }
            PaymentInfo memory payment = PaymentInfo(_payment[i].token_addr, _payment[i].price, 0);
            payment_list.push(payment);
        }
        merkle_root = _merkle_root;
        treasury = _treasury;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        if (bytes(baseURI).length > 0) {
            return string(abi.encodePacked(baseURI, StringsUpgradeable.toString(tokenId), ".json"));
        }
        else {
            return defaultURI;
        }
    }

    function _baseURI() internal view override virtual returns (string memory) {
        return baseURI;
    }

    function name() public view virtual override returns (string memory) {
        return ext_name;
    }

    function symbol() public view virtual override returns (string memory) {
        return ext_symbol;
    }

    function publicSaleMint(uint8 number_of_nft)
        external
        payable
    {
        require (public_sale_start_time < block.timestamp, "public sale not started");
        _mint(number_of_nft, true);
    }

    function presaleMint(
        uint256 index,
        uint256 amount,
        bytes32[] calldata proof
    )
        external
        payable
    {
        // for this project, presale: `only 1 for each wallet`
        require (presale_start_time < block.timestamp, "presale not started");
        require (presale_end_time >= block.timestamp, "presale expired");

        // validate whitelist user
        bytes32 leaf = keccak256(abi.encodePacked(index, msg.sender, amount));
        require(MerkleProof.verify(proof, merkle_root, leaf), "not whitelisted");

        require(presale_purchased_by_addr[msg.sender] < amount, "exceeds personal limit");
        presale_purchased_by_addr[msg.sender] += 1;
        _mint(1, false);
    }

    function _mint(
        uint8 number_of_nft,
        bool public_sale
    )
        internal
    {
        require(tx.origin == msg.sender, "not real user");

        uint32 bought_number = public_purchased_by_addr[msg.sender];
        if (public_sale) {
            require((bought_number + number_of_nft) <= public_sale_purchase_limit, "exceeds public sale limit");
        }
        require(sold_quantity < total_quantity, "no NFT left");
        uint8 actual_number_of_nft = number_of_nft;
        if ((sold_quantity + number_of_nft) > total_quantity) {
            actual_number_of_nft = uint8(total_quantity - sold_quantity);
        }
        {
            uint256 total = payment_list[0].price;
            total = total.mul(actual_number_of_nft);
            address token_address = payment_list[0].token_addr;
            if (token_address == address(0)) {
                require(msg.value >= total, "not enough ETH");
                uint256 eth_to_refund = msg.value - total;
                if ((number_of_nft > actual_number_of_nft) && (eth_to_refund > 0)) {
                    address payable addr = payable(_msgSender());
                    addr.transfer(eth_to_refund);
                }
                {
                    // transfer to treasury
                    treasury.transfer(total);
                }
            }
            else {
                // transfer to treasury
                IERC20(token_address).safeTransferFrom(_msgSender(), treasury, total);
            }
            payment_list[0].receivable_amount += total;
        }
        {
            for (uint256 i = 0; i < actual_number_of_nft; i++) {
                _safeMint(_msgSender(), totalSupply());
            }
            if (public_sale) {
                public_purchased_by_addr[msg.sender] = bought_number + actual_number_of_nft;
            }
            sold_quantity = sold_quantity + actual_number_of_nft;
        }
    }

    function adminMint(uint256 count) external onlyAdmin {
        for (uint256 i = 0; i < count; i++) {
            _safeMint(_msgSender(), totalSupply());
        }
    }

    function getNFTInfo()
        external
        view
        returns (
            address _owner,
            string memory _name,
            uint32 _public_sale_purchase_limit,
            uint32 _total_quantity,
            uint32 _presale_start_time,
            uint32 _presale_end_time,
            uint32 _public_sale_start_time,
            uint32 _sold_quantity,
            PaymentInfo[] memory _payment_list
        )
    {
        _owner = owner();
        _name = name();
        _public_sale_purchase_limit = public_sale_purchase_limit;
        _total_quantity = total_quantity;
        _presale_start_time = presale_start_time;
        _presale_end_time = presale_end_time;
        _public_sale_start_time = public_sale_start_time;
        _sold_quantity = sold_quantity;
        _payment_list = payment_list;
    }

    function setTime(
        uint32 _presale_start_time,
        uint32 _presale_end_time,
        uint32 _public_sale_start_time
    ) external onlyAdmin {
        presale_start_time = _presale_start_time;
        presale_end_time = _presale_end_time;
        public_sale_start_time = _public_sale_start_time;
    }

    // reveal mystery box
    function setBaseURI(string memory _baseURI_) external onlyAdmin {
        baseURI = _baseURI_;
    }

    function setName(string memory _name) external onlyAdmin {
        ext_name = _name;
    }

    function setSymbol(string memory _symbol) external onlyAdmin {
        ext_symbol = _symbol;
    }

    function setMerkleRoot(bytes32 root) external onlyAdmin {
        merkle_root = root;
    }

    modifier onlyAdmin() {
        require(owner() == _msgSender() || admin[_msgSender()], "caller not admin");
        _;
    }

    function addAdmin(address[] memory addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            admin[addrs[i]] = true;
        }
    }
}