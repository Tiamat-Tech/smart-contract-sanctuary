// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./PaymentSplitter.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// ************************ @author: F-Society // ************************ //
/*
MMMMMMMMMMMMMMMMMMMMWWWNX0xl:,'..         ..',:lxOXNWWWMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMWX0kdl:;,....             ....,;:ldk0XWMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMN0dc'.           ..','..           .':d0NMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMWXKKNN0o,.            'lxkko;.            'lONNXKXNWMMMMMMMMMMM
MMMMMMMMMMNKxc;ckXNXd,.         .,lO00Odc,.          'oKNXOl;cd0NWMMMMMMMMM
MMMMMMMMNKx:.  .,o0NXkc.       .:xKXOxl;cl;.       .:xKN0d;.  .;d0NWMMMMMMM
MMMMMMWXx:.      .lOXXOl'     .;xXWNkl,.'cl:,.    .cOXX0o'      .;xKWMMMMMM
MMMMMNOl'         .;xXNKx,   .ckXWMNxc'  .;ol'   'o0NXkc.         .ckNMMMMM
MMMWKx:.           .,dKNXd,..:ONMMMNxc'   .:c:,',oKNKx;.           .;xKWMMM
MMW0o'.              .cOXKOxxONMMMMNxc'    .,coxkKX0l'.             .'l0NMM
MN0o'                 .:xKWWWWMMMMMNxc'     .'lOXXOl.                 'o0NM
W0o,.                  .;kNMMMMMMMMNxc'       .lOkc'                   'l0W
Xx,                    .cOWMMMMMMMMNxc'        .:cc,.                   'dK
kc.                   'o0NMMMMMMMMWXxc'         .,ll;.                  .cx
c,.                 .,oKWMMMMMMWWX0d:'.          .;cl:.                  ':
,.                 .:kXWMMMWNKkdl:,.              .,loc'.                .'
..                'ckNWNK0kdl;'.                   .':lc,.                .
..              .'okOOxo:'.                          .;lc,.               .
::;;;;;;;;;;;,,:oxOkl..                              .;oxxo:,,;;;;;;;;;;;::
KK00KKKXXXXXXXKXNNX0d;..                          ..;lkKNNNXXXXXXXXXXKK00KK
OxdoxOKWMMMMMMMMMMWWXKOko;..                   .':dO0KXNWWMMMMMMMMMWXOxodxk
c,...,l0NWMMMMMMMMWWWMMWNKkdc,.             .;oxk00koox0XWMMMMMMMWN0o,...,:
c,.   .ckXMMMMMWX0xdOXWMMMMWX0xl;'.     .,:lxKX0xl;,',:ox0XWMMMMMNkl'   .':
kc.    .:kNWWN0xl;..,oONMMMMMMWNKko:,,;:dO00Oko;...';:,..,cd0XWWNOc.    .:x
Xx'     .:dkko,.     .:kXWMMMMMMMWNXXKKK0kd:'.  .':c;'.    .,lkkd:.     'dK
W0l'      ....        .:xKWMMMMMMMMWXKOo,.     .;loc.        ....      .cOW
WKd;.                .'lOXWMMMMMMMMNko:.      .lOK0d;.                .,o0W
Nk:.              .'cx0XNWMMMMMMMMMNxc'     .,lONMWN0xc'.              .;kN
Nx,             .;okXWMMMMMMMMMMMMMNxc'    .;xKWMMMMMWXOo;.             'xX
W0o,.           'lOWMMMMMMMMMMMMMMMNxc'   'lONMMMMMMMMMW0l'.           'l0W
MWKx;.           'lOXWMMMMMMMMMMMMMNxc' .'oKWMMMMMMMMWXOl,.          .;dKNM
MMWXkl'.          .'lOXWMMMMMMMMMMWXxc,':kXWMMMMMMMWXOl'.          .'ckXWMM
MMMMWKxc;;,,..      .'lOXWMMMMMMMMWXOxdd0NMMMMMMMWXOl,.      ..,,;;:xKNMMMM
MMMMMWNXXKKKOl'.      .'ckXWWMMMMMWWNNNNWMMMMMMWXkc'.      .'lkKKKKXNWMMMMM
MMMMMMMMMMMMWX0dc'.      .;d0NWWMMMMMMMMMMMWWNKx:..     .':dOXWMMMMMMMMMMMM
MMMMMMMMMMMMMMMNKOxl;'.    .,lx0NWMMMMMMMWN0xl;.    ..;ldOKNMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMWNKkdl:;,...':d0NWMMMWNKx:'...,;:ldkKNWMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMWWNX0xl,. .;d0NMMMWKx:. .,cx0XNWWWMMMMMMMMMMMMMMMMMMMM

#     # ####### #######    #       #######    #    ######  #     # ####### ######   #####
##   ## #          #      # #      #         # #   #     # ##   ## #       #     # #     #
# # # # #          #     #   #     #        #   #  #     # # # # # #       #     # #
#  #  # #####      #    #     #    #####   #     # ######  #  #  # #####   ######   #####
#     # #          #    #######    #       ####### #   #   #     # #       #   #         #
#     # #          #    #     #    #       #     # #    #  #     # #       #    #  #     #
#     # #######    #    #     #    #       #     # #     # #     # ####### #     #  #####
*/
// *************************************************************************** //
contract JeanCode is
    ERC721,
    PaymentSplitter,
    Pausable,
    Ownable,
    ReentrancyGuard
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _tokenSupply;
    uint64 public constant MAX_SUPPLY = 12;
    uint64 public constant RAFFLE_SUPPLY = 2;
    uint64 public constant WHITELIST_SUPPLY = 1;
    uint64 public constant GIFT_SUPPLY = 5;
    uint64 public publicRedeemedCount;
    uint64 public raffleRedeemedCount;
    uint64 public whitelistRedeemedCount;
    uint128 public constant PRICE = 0.00017 ether;
    uint128 public constant RAFFLE_PRICE = 0.0001 ether;
    uint256 public constant WHITELIST_PRICE = 0.0001 ether;

    mapping(address => uint256) public raffleRedeemed;
    mapping(address => uint256) public privateRedeemed;
    mapping(address => uint256) public publicRedeemed;

    WorkflowStatus public workflow;

    event RaffleMint(address indexed _minter, uint256 _amount, uint256 _price);
    event PrivateMint(address indexed _minter, uint256 _amount, uint256 _price);
    event PublicMint(address indexed _minter, uint256 _amount, uint256 _price);

    uint256[] private teamShares_ = [3080, 2816, 2024, 880, 200, 1000];

    address[] private team_ = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x5B8B3eE5D2d99537E0DBe24B01353a38529D9727,
        0x2828D3280801B15C5061F80f752be4130adea2Ed,
        0x584BE9377137D1C34b13FF1D6C8D556feC448100,
        0x5Bd342AAdE55C91aa75694AEef9a10a828e23Cf0,
        0x0323196BD6f5ed0CCc8B0f90eDC8b11435fB7c61
    ];

    enum WorkflowStatus {
        Before,
        Raffle,
        Presale,
        Sale,
        SoldOut,
        Reveal
    }

    bool public revealed;
    string public baseURI;
    string public notRevealedUri;

    bytes32 public raffleWhitelist;
    bytes32 public privateWhitelist;

    constructor(
        string memory _initNotRevealedUri,
        bytes32 _raffleWhitelist,
        bytes32 _privateWhitelist
    ) ERC721("JeanCode", "JC") PaymentSplitter(team_, teamShares_) {
        transferOwnership(msg.sender);
        revealed = false;
        workflow = WorkflowStatus.Before;
        setNotRevealedURI(_initNotRevealedUri);
        raffleWhitelist = _raffleWhitelist;
        privateWhitelist = _privateWhitelist;

    }
    function redeemRaffle(uint64 amount, bytes32[] calldata proof)
        external
        payable
        whenNotPaused
    {
        require(workflow == WorkflowStatus.Raffle, "Raffle sale has ended");

        bool isOnWhitelist = _verifyRaffle(_leaf(msg.sender, 1), proof);
        require(
            isOnWhitelist,
            "address not verified on the raffle winners whitelist"
        );
        require(
            RAFFLE_SUPPLY >= raffleRedeemedCount + amount,
            "cannot mint tokens. will go over raffle supply limit"
        );

        uint256 price = RAFFLE_PRICE;
        uint256 max = MAX_SUPPLY;
        uint256 maxAmount = 1;
        uint256 alreadyRedeemed = raffleRedeemed[msg.sender];
        uint256 supply = _tokenSupply.current() + amount;

        require(supply <= max, "Sold out !");
        require(
            alreadyRedeemed + amount <= maxAmount,
            "tokens minted will go over user limit"
        );
        require(price * amount <= msg.value, "JeanCode: Insuficient funds");

        emit RaffleMint(msg.sender, amount, price);

        raffleRedeemed[msg.sender] = raffleRedeemed[msg.sender] + amount;
        for (uint256 i = 0; i < amount; i++) {
        raffleRedeemedCount = raffleRedeemedCount++;
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function redeemPrivateSale(uint64 amount, bytes32[] calldata proof)
        external
        payable
        whenNotPaused
    {
        require(amount > 0, "need to mint at least one token");
        require(workflow != WorkflowStatus.SoldOut, "JeanCode: SOLD OUT!");
        require(
            workflow == WorkflowStatus.Presale,
            "JeanCode: private sale is not started yet iii"
        );

        bool isOnWhitelist = _verifyPrivate(_leaf(msg.sender, 1), proof);
        require(
            isOnWhitelist,
            "address not verified on the private sale whitelist"
        );
        require(
            WHITELIST_SUPPLY >= whitelistRedeemedCount + amount,
            "cannot mint tokens. will go over private supply limit"
        );

        uint256 price = WHITELIST_PRICE;
        uint128 maxAmount = 1;
        uint256 alreadyRedeemed = privateRedeemed[msg.sender];
        uint256 supply = _tokenSupply.current() + amount;

        require(
            alreadyRedeemed + amount <= maxAmount,
            "JeanCode: You can't mint more than 1 tokens!"
        );
        require(supply <= MAX_SUPPLY, "Sold out !");
        require(price * amount <= msg.value, "JeanCode: Insuficient funds");

        whitelistRedeemedCount = whitelistRedeemedCount + amount;
        emit PrivateMint(msg.sender, amount, price);

        uint256 initial = 1;
        uint256 condition = amount;
        if (_tokenSupply.current() + amount == MAX_SUPPLY) {
            workflow = WorkflowStatus.SoldOut;
        }
        privateRedeemed[msg.sender] = privateRedeemed[msg.sender] + condition;
        for (uint256 i = initial; i <= condition; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function publicSaleMint(uint64 amount)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(amount > 0, "need to mint at least one token");
        require(workflow != WorkflowStatus.SoldOut, "JeanCode: SOLD OUT!");
        require(
            workflow == WorkflowStatus.Sale,
            "JeanCode: public sale is not started yet"
        );

        uint256 price = PRICE;
        uint256 maxAmount = 5;
        uint256 alreadyRedeemed = publicRedeemed[msg.sender];
        uint256 supply = _tokenSupply.current() + amount;
        require(
            alreadyRedeemed + amount <= maxAmount,
            "JeanCode: You can't mint more than 5 tokens!"
        );
        require(supply <= MAX_SUPPLY, "JeanCode: Sold out !");
        require(price * amount <= msg.value, "JeanCode: Insuficient funds");

        publicRedeemedCount = publicRedeemedCount + amount;
        emit PublicMint(msg.sender, amount, price);

        uint256 initial = 1;
        uint256 condition = amount;
        if (_tokenSupply.current() + amount == MAX_SUPPLY) {
            workflow = WorkflowStatus.SoldOut;
        }
        publicRedeemed[msg.sender] = publicRedeemed[msg.sender] + condition;
        for (uint256 i = initial; i <= condition; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function gift(uint64 _mintAmount) public onlyOwner {
        require(_mintAmount > 0, "JeanCode: need to mint at least 1 NFT");

        uint256 supply = _tokenSupply.current() + _mintAmount;
        require(supply <= MAX_SUPPLY, "JeanCode: Sold out !");

        uint256 condition = _mintAmount;
        if (_tokenSupply.current() + _mintAmount== MAX_SUPPLY) {
            workflow = WorkflowStatus.SoldOut;
        }

        for (uint256 i = 1; i <= condition; i++) {
            _tokenSupply.increment();
            _safeMint(msg.sender, _tokenSupply.current());
        }
    }

    function giveaway(address[] memory giveawayAddressTable) public onlyOwner {
        uint256 _mintAmount = giveawayAddressTable.length;
        require(giveawayAddressTable.length > 0, "JeanCode:at least 1 NFT");

        uint256 supply = _tokenSupply.current() + _mintAmount;
        require(supply <= MAX_SUPPLY, "JeanCode: Sold out !");

        if (_tokenSupply.current() + _mintAmount== MAX_SUPPLY) {
            workflow = WorkflowStatus.SoldOut;
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _tokenSupply.increment();
            _safeMint(giveawayAddressTable[i], _tokenSupply.current());
        }
    }

    /***************************
     * Owner Protected Functions
     ***************************/

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function totalSupply() external view returns (uint256) {
        uint256 supply = _tokenSupply.current();
        return supply;
    }

    function setWhitelist(bytes32 whitelist_) public onlyOwner {
        raffleWhitelist = whitelist_;
    }

    //TODO add timestamps
    function setRaffleSaleEnabled() public onlyOwner returns (WorkflowStatus) {
        workflow = WorkflowStatus.Raffle;
        return workflow;
    }

    function setPrivateSaleEnabled() public onlyOwner returns (WorkflowStatus) {
        workflow = WorkflowStatus.Presale;
        return workflow;
    }

    function setPublicSaleEnabled() public onlyOwner returns (WorkflowStatus) {
        workflow = WorkflowStatus.Sale;
        return workflow;
    }

    function getWorkflowStatus() public view returns (WorkflowStatus) {
        return workflow;
    }

    function _leaf(address account, uint256 amount)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account, amount));
    }

    function _verifyRaffle(bytes32 leaf, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, raffleWhitelist, leaf);
    }

    function _verifyPrivate(bytes32 leaf, bytes32[] memory proof)
        internal
        view
        returns (bool)
    {
        return MerkleProof.verify(proof, privateWhitelist, leaf);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /*************************************************************
     * The following functions are overrides required by Solidity.
     *************************************************************/

    function _toString(uint256 v) internal pure returns (string memory str) {
        if (v == 0) {
            return "0";
        }
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint256 j = 0; j < i; j++) {
            s[j] = reversed[i - 1 - j];
        }
        str = string(s);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        if (revealed == false) {
            return notRevealedUri;
        }

        string memory currentBaseURI = baseURI;
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, _toString(tokenId)))
                : "";
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function reveal(string memory revealedBaseURI) public onlyOwner {
        baseURI = revealedBaseURI;
        revealed = true;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }
}