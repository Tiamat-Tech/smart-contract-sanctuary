// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";

interface NftContract {
    function mint(address) external;
}

contract BarnyardFashionistasStore is Ownable {
    NftContract public bfNft =
        NftContract(0xBAB7dF6D042F4b83b62070b670Da929b62eD22d8);

    address private constant core1Address =
        0x3002E0E7Db1FB99072516033b8dc2BE9897178bA;
    uint256 private constant core1Shares = 84650;

    address private constant core2Address =
        0x452d40db156034223e8865F93d6a532aE62c4A99; 
    uint256 private constant core2Shares = 5000;

    address private constant core3Address =
        0xEbCEe6204eeEEf21e406C0A75734E70f342914e0; 
    uint256 private constant core3Shares = 5000;

    address private constant core4Address =
        0xcFE99FB901c76C7432E3CD823B38EF6ce055090b; 
    uint256 private constant core4Shares = 3000;

    address private constant core5Address =
        0xa808208Bb50e2395c63ce3fd41990d2E009E3053; 
    uint256 private constant core5Shares = 750;

    address private constant core6Address =
        0x1996FabEC51878e3Ff99cd07c6CaC9Ac668A22fD; 
    uint256 private constant core6Shares = 600;

    address private constant core7Address =
        0x30734A0adeCa7e07c3C960587d6502fC5EA0f8df; 
    uint256 private constant core7Shares = 500;
    
    address private constant core8Address =
        0x74E101B1E67Cd303A3ec896421ceCf894891ac25; 
    uint256 private constant core8Shares = 500;

    

    uint256 private constant baseMod = 100000;

    /**
        Numbers for Barnyard Fashionistas NftContract
     */
    // uint256 public constant maxFashionistas = 9999;
    uint256 public maxFashionistas = 9999;


    mapping(address => uint256) private whitelist;

    /**
        Team allocated Fashionistas
     */
    // Fashionistas which is minted by the owner
    uint256 public preMintedFashionistas = 0;
    // MAX Fashionistas which owner can mint
    uint256 public constant maxPreMintFashionistas = 300;

    /**
        Mint Pass
     */
    uint256 public newlyMintedFashionistasPresale = 0;

    mapping(address => uint256) public mintedFashionistasOf;


    /**
        Tracking Dweller Sales After Presale
     */
    uint256 public mintedFashionistasAfterPresale = 0;

    /**
        Scheduling
     */


    /**
        Ticket
     */
    uint256 public price = 0.071 ether;

    // mapping(address => ticket) public ticketsOf;
    // struct ticket {
    //     uint256 index; // Incl
    //     uint256 amount;
    // }

    /**
        Security
     */
    uint256 public constant maxMintPerTx = 30;

    /**
        Raffle
     */


    uint256 public mintedFashionistas = 0;


    event SetFashionistasNftContract(address bfNft);

    event MintWithWhitelist(address account, uint256 amount, uint256 changes);
    event SetRemainingFashionistas(uint256 remainingFashionistas);

    event mintFashionistas(address account, uint256 amount);
    event Withdraw(address to);


    bool public presaleOn = false;
    bool public mainSaleOn = false;

    constructor() {
    }

    modifier mainSaleOpened() {
        require( mainSaleOn, "Store is not opened" );

        _;
    }

    modifier presaleOpened() {
        require(presaleOn, "Store is not opened for Presale");

        _;
    }

    modifier onlyOwnerOrTeam() {
        require(
            core1Address == msg.sender || core2Address == msg.sender || core4Address == msg.sender || owner() == msg.sender,
            "caller is neither Team Wallet nor Owner"
        );
        _;
    }

    function setPrice(uint256 _newPrice) external onlyOwner {
        price = _newPrice;
    }

    function togglePresale() external onlyOwner {
        presaleOn = !presaleOn;
    }

    function toggleMainSale() external onlyOwner {
        mainSaleOn = !mainSaleOn;
    }

    function presaleBalance() public view returns(uint256) {
        return whitelist[msg.sender];
    }


    function setFashionistasNftContract(NftContract _bfNft) external onlyOwner {
        bfNft = _bfNft;
        emit SetFashionistasNftContract(address(_bfNft));
    }


    // Do not update newlyMintedFashionistas to prevent withdrawal
    // This needs to become the owner Free mint function. Ditch the time restrictions?
    function preMintFashionistas(address[] memory recipients) external onlyOwner {

        uint256 totalRecipients = recipients.length;

        require(
            totalRecipients > 0,
            "Number of recipients must be greater than 0"
        );
        require(
            preMintedFashionistas + totalRecipients <= maxPreMintFashionistas,
            "Exceeds max pre-mint Fashionistas"
        );

        require(
            mintedFashionistas + totalRecipients < maxFashionistas,
            "Exceeds max Fashionistas"
        );

        for (uint256 i = 0; i < totalRecipients; i++) {
            address to = recipients[i];
            require(to != address(0), "receiver can not be empty address");
            bfNft.mint(to);
        }

        preMintedFashionistas += totalRecipients;
        mintedFashionistas += totalRecipients;
    }




    // adds to whitelist with specified amounts
    function addToWhitelistAmounts(address[] memory _listToAdd, uint256[] memory _amountPerAddress) public onlyOwner {
        uint256 totalAddresses = _listToAdd.length;
        uint256 totalAmounts = _amountPerAddress.length;

        require(totalAddresses == totalAmounts, "Amounts of entered items do not match");

        for (uint256 i = 0; i < totalAddresses; i++) {
          whitelist[_listToAdd[i]] = _amountPerAddress[i];
        }
    }

    
    function mintPresale( uint256 _count) public payable presaleOpened{
        require(_count <= whitelist[msg.sender]);
        
        require(mintedFashionistas + _count <= maxFashionistas, "Max limit");
        require(msg.value >= (_count * price ), "Value below price");

        for (uint256 i = 0; i < _count; i++) {
          bfNft.mint(msg.sender);
        }

        newlyMintedFashionistasPresale += _count;
        mintedFashionistas += _count;

        whitelist[msg.sender] = whitelist[msg.sender] - _count;
    }



    // MAIN MINTING FUNCTION

    function mintMainSale(uint256 _amount) external payable mainSaleOpened {
   
        require(mintedFashionistas + _amount -1 < maxFashionistas, "exceeds max mint");

        uint256 totalPrice = price * _amount;
        require(totalPrice <= msg.value, "Not enough money");

        require(_amount - 1 < maxMintPerTx, "exceed max transaction");

        for (uint256 i = 0; i < _amount; i += 1) {
            bfNft.mint(msg.sender);
        }

        mintedFashionistasAfterPresale += _amount;
        mintedFashionistas += _amount;

        emit mintFashionistas(msg.sender, _amount);
    }



    function withdrawCore() external onlyOwnerOrTeam {
        uint256 balance = address(this).balance;
        require(balance > 0);

        _splitAll(balance);
    }

    //  **** ASK HOW MANY CAN DO SAFE
    function _splitAll(uint256 _amount) private {
        uint256 singleShare = _amount / baseMod;
        _withdraw(core1Address, singleShare * core1Shares);
        _withdraw(core2Address, singleShare * core2Shares);
        _withdraw(core3Address, singleShare * core3Shares);
        _withdraw(core4Address, singleShare * core4Shares);
        _withdraw(core5Address, singleShare * core5Shares);
        _withdraw(core6Address, singleShare * core6Shares);
        _withdraw(core7Address, singleShare * core7Shares);
        _withdraw(core8Address, singleShare * core8Shares);
    }

    function withdrawBU() external onlyOwnerOrTeam {
        uint256 balance = address(this).balance;
        require(balance > 0);

        _withdraw(core1Address, balance);
    }

    function _withdraw(address _address, uint256 _amount) private {
        payable(_address).transfer(_amount);
    }    

}