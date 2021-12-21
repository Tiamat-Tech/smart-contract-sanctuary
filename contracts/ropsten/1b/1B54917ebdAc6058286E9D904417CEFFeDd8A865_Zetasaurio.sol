// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/*
      .".".".
    (`       `)               _.-=-.
     '._.--.-;             .-`  -'  '.
    .-'`.o )  \           /  .-_.--'  `\
   `;---) \    ;         /  / ;' _-_.-' `
     `;"`  ;    \        ; .  .'   _-' \
      (    )    |        |  / .-.-'    -`
       '-.-'     \       | .' ` '.-'-\`
        /_./\_.|\_\      ;  ' .'-'.-.
        /         '-._    \` /  _;-,
       |         .-=-.;-._ \  -'-,
       \        /      `";`-`,-"`)
        \       \     '-- `\.\
         '.      '._ '-- '--'/
           `-._     `'----'`;
               `"""--.____,/
                      \\  \
                      // /`
                  ___// /__
                (`(`(---"-`)
*/
contract Zetasaurio is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public baseURI = "";

    uint256 public saleStart;
    uint256 public presaleStart;
    uint256 public presaleEnd;
    uint256 public cost = 0.06 ether;
    uint256 public constant maxSupply = 10000;
    uint256 public constant batchMintLimit = 5;
    uint256 public constant presaleMintPerAddressLimit = 3;

    mapping(address => bool) public hasPresaleAccess;
    mapping(address => uint256) public mintedPerAddress;

    address public devWallet = 0x2c0892045b2C28C188C0F87374210Faf833EA70b;

    constructor() ERC721("Zetasaurio", "ZS") {}

    /**
     * @dev Base URI for computing {tokenURI} in {ERC721} parent contract.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    /**
     * To change cost between presale stages
     */
    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    /**
     * Just in case of emergency.
     */
    function setDevWallet(address _devWallet) public onlyOwner {
        devWallet = _devWallet;
    }

    function schedulePresale(uint256 _start, uint256 _end) public onlyOwner {
        presaleStart = _start;
        presaleEnd = _end;
    }

    function scheduleSale(uint256 _start) public onlyOwner {
        saleStart = _start;
    }

    function presaleIsActive() public view returns (bool) {
        return presaleStart <= block.timestamp && block.timestamp <= presaleEnd;
    }

    function saleIsActive() public view returns (bool) {
        return saleStart != 0 && saleStart <= block.timestamp;
    }

    function grantPresaleAccess(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            hasPresaleAccess[_users[i]] = true;
        }
    }

    function revokePresaleAccess(address[] calldata _users) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            hasPresaleAccess[_users[i]] = false;
        }
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;

        require(payable(devWallet).send((balance * 10) / 100));
        require(payable(msg.sender).send((balance * 90) / 100));
    }

    /**
     * Reserve zetas for team and giveaways.
     */
    function reserve(uint256 _amount) public onlyOwner {
        uint256 supply = totalSupply();

        for (uint256 i = 1; i <= _amount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function mint(uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();

        require(saleIsActive() || presaleIsActive(), "Sale is not active");
        require(_mintAmount > 0, "Must mint at least one NFT");
        require(supply + _mintAmount <= maxSupply, "Supply left is not enough");
        require(_mintAmount <= batchMintLimit, "Can't mint these many NFTs at once");

        if (msg.sender != owner()) {
            require(msg.value >= cost * _mintAmount, "Not enough funds to purchase");

            if (presaleIsActive()) {
                require(hasPresaleAccess[msg.sender], "Presale access denied");
                require(
					mintedPerAddress[msg.sender] + _mintAmount < presaleMintPerAddressLimit,
                    "Not enough presale mintings left"
                );
            }
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            mintedPerAddress[msg.sender]++;
            _safeMint(msg.sender, supply + i);
        }
    }
}