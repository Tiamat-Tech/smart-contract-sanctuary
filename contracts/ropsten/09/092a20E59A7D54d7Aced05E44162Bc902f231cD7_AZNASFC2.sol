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

    uint256 public maxYellowGiantSupply = 1000;
    uint256 public maxYellowGiantReserve = 100;
    uint256 public maxYellowGiantTeamReserve = 70;
    uint256 public maxYellowGiantsPerTx = 5;

    uint256 public yellowGiantPrice = 10000000000000000; //0.01 ETH
    bool public saleActive = false;
    bool public reserveActive = false;
    string private _setBaseURI;

    // Custom data struct
    struct winners {
        address addr;
        uint256 mintPrice;
        uint8 mintCount;
    }
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

    // MINT YELLOW GIANTS FOR PUBLIC
    function mintYellowGiant(uint256 amount) external payable {
        require(
            saleActive,
            "The rescue hasn't started yet. Hold your hooves..."
        );
        require(amount > 0, "Amount must be greater than 0.");
        require(
            amount <= maxYellowGiantsPerTx,
            "Only 10 Yellow Giants can be rescued at a time."
        );
        require(
            totalSupply().add(amount) <=
                maxYellowGiantSupply.sub(maxYellowGiantReserve),
            "There are no more Yellow Giants left to be rescued."
        );
        require(
            msg.value >= yellowGiantPrice.mul(amount),
            "The amount of ether sent was incorrect."
        );

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = totalSupply();
            if (tokenId < maxYellowGiantSupply) {
                _safeMint(msg.sender, tokenId);
            }
        }
    }

    // MINT YELLOW GIANTS FOR TEAM
    function mintTeamYellowGiants(uint256 amount, address to) public onlyOwner {
        require(reserveActive, "Reserve state is not active.");
        require(amount > 0, "Amount must be greater than 0.");
        require(
            amount <= maxYellowGiantTeamReserve,
            "Minted all of the Yellow Giants set for the team."
        );
        require(
            amount <= maxYellowGiantReserve,
            "Minted all of the Yellow Giants set for reserves."
        );

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = totalSupply();
            if (tokenId < maxYellowGiantSupply) {
                _safeMint(to, tokenId);
            }
        }

        maxYellowGiantReserve = maxYellowGiantReserve.sub(amount);
        maxYellowGiantTeamReserve = maxYellowGiantTeamReserve.sub(amount);
    }

    // MINT YELLOW GIANTS FOR PRE-LAUNCH GIVEAWAYS
    // function mintPreLaunchGiveaways(uint amount, address to) public onlyOwner {
    //     require(reserveActive, "Reserve state is not active.");
    //     require(amount > 0, "Amount must be greater than 0.");
    //     require(amount <= maxYellowGiantReserve, "Minted all of the Yellow Giants set for pre-launch giveaways.");

    // for (uint i = 0; i < amount; i++) {
    //     uint256 tokenId = totalSupply();
    //     if (tokenId < maxYellowGiantSupply) {
    //         _safeMint(to, tokenId);
    //     }
    // }
    //     maxYellowGiantReserve = maxYellowGiantReserve.sub(amount);
    // }
    function mintPreLaunchGiveaways(address to) public {
        require(reserveActive, "Reserve state is not active.");
        require(
            1 <= maxYellowGiantReserve,
            "Pre-launch giveaways limit reached."
        );
        require(isAllowedToMint(to), "Free mint already claimed");

        uint256 tokenId = totalSupply();
        if (tokenId < maxYellowGiantSupply) {
            _safeMint(to, tokenId);
        }

        maxYellowGiantReserve = maxYellowGiantReserve.sub(1);
        updateRedeemStatus(to);
    }

    // MINT YELLOW GIANTS FOR REMAINING GIVEAWAYS
    // (Function to mint remaining unclaimed NFTs)
    function mintPostLaunchGiveaways(uint256 amount, address to)
        public
        onlyOwner
    {
        require(reserveActive, "Reserve state is not active.");
        require(amount > 0, "Amount must be greater than 0.");
        require(
            amount <= maxYellowGiantReserve,
            "Minted all of the Yellow Giants set for giveaways and scavenger hunts."
        );

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = totalSupply();
            if (tokenId < maxYellowGiantSupply) {
                _safeMint(to, tokenId);
            }
        }

        maxYellowGiantReserve = maxYellowGiantReserve.sub(amount);
    }

    // SET YELLOW GIANT MINT PRICE
    function setYellowGiantPrice(uint256 price) public onlyOwner {
        yellowGiantPrice = price;
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

    function updateRedeemStatus(address _addr) private {
        winnerAddresses[_addr] = false;
    }

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

    // function mintForPromotionalWinners(address _addr, bytes32 hashedAddress, bytes memory signature)
    //     external
    //     payable
    // {
    //     require(reserveActive, "Reserve state is not active.");

    //     address signerPublicKey = recoverSigner(hashedAddress, signature);
    //     if (signerPublicKey == trustedPublicKey){
    //         uint256 tokenId = totalSupply();
    //     if (tokenId < maxYellowGiantSupply) {
    //         _safeMint(_addr, tokenId);
    //     }
    //     maxYellowGiantReserve = maxYellowGiantReserve.sub(1);
    //     }  
    // }

    function isValidData(uint8 _number, uint256 _mintPrice, string memory _address, bytes memory sig) public view returns(bool){
        bytes32 hashedAddress = keccak256(abi.encodePacked(_number, _mintPrice, _address));
        return (recoverSigner(hashedAddress, sig) == trustedPublicKey);
    }
}