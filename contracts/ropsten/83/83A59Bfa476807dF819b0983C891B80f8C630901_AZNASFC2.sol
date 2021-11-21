//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract AZNASFC2 is ERC721, ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    
    uint256 public maxSupply = 5;
    uint256 public maxReserve = 2;
    uint256 public maxMintPerTx = 5;
    uint256 public commandoPrice = 1000000000000000; //0.001 ETH

    bool public saleActive = false;
    bool public reserveActive = false;
    string private _setBaseURI;
    mapping (address => mapping(uint256 => uint8)) public promotionWinners;
    address trustedPublicKey = 0x0deDa54Ac34c6ea809efEb6bd0331662e53b6E4B;

    constructor() ERC721("AZNASFC2", "AZNASFC2") {
        intializeWhiteList();
    }

    // RETRIEVE BASEURI
    function _baseURI() internal view virtual override returns (string memory) {
        return _setBaseURI;
    }

    // SET BASEURI
    function setBaseURI(string memory baseURI) public onlyOwner {   
        _setBaseURI = baseURI;
    }

    // (MY) VIEW BASEURI
    function getBaseURI() public view returns (string memory) {
        return _setBaseURI;
    }

    // MINT COMMANDOS FOR PUBLIC
    function mintCommando(uint256 amount) external payable {
        require(
            saleActive,
            "Sale is not yet active."
        );
        require(amount > 0, "Amount must be greater than 0.");
        require(
            amount <= maxMintPerTx,
            "Only 5 Commados can be minted per transaction."
        );
        // Cannot mint more than (maxSupply - maxReserve)
        require(
            totalSupply().add(amount) <= maxSupply.sub(maxReserve),
            "No more commandos left to mint."
        );
        require(
            msg.value >= commandoPrice.mul(amount),
            "The amount of ether sent was incorrect."
        );

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = totalSupply();
            if (tokenId < maxSupply) {
                _safeMint(msg.sender, tokenId);
            }
        }
    }

    // MINT YELLOW GIANTS FOR TEAM
    // function mintTeamYellowGiants(uint256 amount, address to) public onlyOwner {
    //     require(reserveActive, "Reserve state is not active.");
    //     require(amount > 0, "Amount must be greater than 0.");
    //     require(
    //         amount <= maxYellowGiantTeamReserve,
    //         "Minted all of the Yellow Giants set for the team."
    //     );
    //     require(
    //         amount <= maxYellowGiantReserve,
    //         "Minted all of the Yellow Giants set for reserves."
    //     );

    //     for (uint256 i = 0; i < amount; i++) {
    //         uint256 tokenId = totalSupply();
    //         if (tokenId < maxYellowGiantSupply) {
    //             _safeMint(to, tokenId);
    //         }
    //     }

    //     maxYellowGiantReserve = maxYellowGiantReserve.sub(amount);
    //     maxYellowGiantTeamReserve = maxYellowGiantTeamReserve.sub(amount);
    // }

    // function mintPreLaunchGiveaways(address to) public {
    //     require(reserveActive, "Reserve state is not active.");
    //     require(
    //         1 <= maxReserve,
    //         "Pre-launch giveaways limit reached."
    //     );
    //     require(isAllowedToMint(to), "Free mint already claimed");

    //     uint256 tokenId = totalSupply();
    //     if (tokenId < maxSupply) {
    //         _safeMint(to, tokenId);
    //     }

    //     maxReserve = maxReserve.sub(1);
    //     updateRedeemStatus(to);
    // }

    // MINT YELLOW GIANTS FOR REMAINING GIVEAWAYS
    // (Function to mint remaining unclaimed NFTs)
    // function mintPostLaunchGiveaways(uint256 amount, address to)
    //     public
    //     onlyOwner
    // {
    //     require(reserveActive, "Reserve state is not active.");
    //     require(amount > 0, "Amount must be greater than 0.");
    //     require(
    //         amount <= maxReserve,
    //         "Minted all of the Yellow Giants set for giveaways and scavenger hunts."
    //     );

    //     for (uint256 i = 0; i < amount; i++) {
    //         uint256 tokenId = totalSupply();
    //         if (tokenId < maxSupply) {
    //             _safeMint(to, tokenId);
    //         }
    //     }

    //     maxReserve = maxReserve.sub(amount);
    // }

    // SET YELLOW GIANT MINT PRICE
    function setCommandoPrice(uint256 price) public onlyOwner {
        commandoPrice = price;
    }

    // TOGGLE SALE STATE ON/OFF
    function toggleSale() public onlyOwner {
        saleActive = !saleActive;
    }

    // TOGGLE RESERVE STATE ON/OFF
    function toggleReserve() public onlyOwner {
        reserveActive = !reserveActive;
    }

    // WITHDRAW FUNDS FROM SMART CONTRACT
    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    mapping(address => bool) public winnerAddresses;

    function intializeWhiteList() internal {
        winnerAddresses[0xCa52a13e13cCA72aa1bEA917A871028d2030b1ce] = true;
        winnerAddresses[0x23377d974d85C49E9CB6cfdF4e0EED1C0Fc85E6A] = true;
        winnerAddresses[0x85F68F10d3c13867FD36f2a353eeD56533f1C751] = true;
    }

    /***** ****************/

    // Checks if the user address is entitled to mint price of zero ETH
    function isAllowedToMint(address _addr) internal view returns (bool) {
        if (getRedeemStatus(_addr)) {
            return true;
        } else {
            return false;
        }
    }

    // Determine if promotion winner has redeemed free mint
    function getRedeemStatus(address _addr) public view returns (bool) {
        return winnerAddresses[_addr];
    }

    // function updateRedeemStatus(address _addr) private {
    //     winnerAddresses[_addr] = false;
    // }

    // GET reserveActive STATE
    function getResearcState() public view onlyOwner returns (bool) {
        return reserveActive;
    }

    // Takes a signed message (signature) and return r, s and v
    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65);

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return (v, r, s);
    }

    // Takes a hashed-message AND signed message (signature) and return the public key of the signer of message
    function recoverSigner(bytes32 message, bytes memory sig)
        public
        pure
        returns (address)
    {
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    //_mintPrice in wei
    function promotionalMint(uint8 _number, uint256 _mintPrice, bytes memory signature)
        external
        payable
    {
        require(reserveActive, "Reserve state is not active.");
        require(_number <= maxMintPerTx, "Only 5 Commandos can be minted at a time.");
        require(
            _number <= maxReserve,
            "There are no more promotional commandos left to be minted."
        );

        // Check  promotional mint request is valid
        bool isValid = isValidData(_number, _mintPrice, msg.sender, signature);
        require(isValid, "This promotioanl request is not valid");
        require(
            msg.value >= _mintPrice.mul(_number),
            "The amount of ether sent was incorrect."
        );

        // Given that the promotional mint request is valid, has user already redeemed the promotion?
        require(winnerCanMint(msg.sender, _mintPrice), "Promotion has already been redeemed");

        for (uint256 i = 0; i < _number; i++) {
            uint256 tokenId = totalSupply();
            if (tokenId < maxSupply) {
                _safeMint(msg.sender, tokenId);
            }
        }

        maxReserve = maxReserve.sub(_number);
        upDatePromotionWinners(msg.sender, _mintPrice);
    }

    // isValidData must be called before this function is called
    // Checks if user has already redeemed promotion
    function winnerCanMint(address _addrs, uint256 _mintPrice) public view returns (bool) {
        if (promotionWinners[_addrs][_mintPrice] == 0){ // mint count is zero
            // User has not minted this promotional price of _mintPrice
            return true;
        }else{
            return false;
        }
    }


    function upDatePromotionWinners(address _addrs, uint256 _mintPrice) private {
        promotionWinners[_addrs][_mintPrice] = 1;
    }

    // Returns the promotional mint price and number of nfts minted at this price
    function getPromotionalWinners(address _addrs, uint256 _mintPrice) public view returns (uint256, uint8){
        return (_mintPrice, promotionWinners[_addrs][_mintPrice]);
    }

     // _mintPrice is in wei
     // _address is the human readable string
    function isValidData(uint8 _number, uint256 _mintPrice, address _address, bytes memory sig) public view returns(bool){
        bytes32 hashedAddress = keccak256(abi.encodePacked(_number, _mintPrice, _address));
        return (recoverSigner(hashedAddress, sig) == trustedPublicKey);
    }


}