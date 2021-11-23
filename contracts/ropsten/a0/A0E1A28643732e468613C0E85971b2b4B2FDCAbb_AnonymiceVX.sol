// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

abstract contract MICE {
    function ownerOf(uint256 tokenId) public virtual view returns (address);
    function tokenOfOwnerByIndex(address owner, uint256 index) public virtual view returns (uint256);
    function balanceOf(address owner) external virtual view returns (uint256 balance);
}

abstract contract CHEETH {
    function getTokensStaked(address staker) public virtual view returns (uint256[] memory);
}

contract AnonymiceVX is ERC721Enumerable, Ownable {
    MICE private mice;
    CHEETH private cheeth;
    bool public saleIsActive = false;
    string private baseURI;
    uint256 public vxCost = 0 ;

    constructor(
        string memory name,
        string memory symbol,
        address miceContractAddress,
        address cheethContractAddress,
        uint256 mintCost
    ) ERC721(name, symbol){
        mice = MICE(miceContractAddress);
        cheeth = CHEETH(cheethContractAddress);
        vxCost = mintCost;
    }

    function isMinted(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function mintAnonymiceVX(uint256 miceTokenId) public payable isClaimable(miceTokenId) {
        require(saleIsActive, "Sale must be active to mint a AnonymiceVX");
        require(msg.value >= vxCost, "Not enough WEI to mint the VX");
        _safeMint(msg.sender, miceTokenId);
    }

    function safeMintAnonymiceVX(uint256 miceTokenId) public payable {
        require(saleIsActive, "Sale must be active to mint a AnonymiceVX");
        require(mice.ownerOf(miceTokenId) == msg.sender, "Must own the Anonymice for requested tokenId to claim a AnonymiceVX");
        require(msg.value >= vxCost, "Not enough WEI to mint the VX");
        _safeMint(msg.sender, miceTokenId);
    }

    function setMintCost(uint256 mintCost) public onlyOwner {
      require(mintCost>=0, "Cost must be higher or equal to 0");
      vxCost = mintCost ;
    }

    function getVaultBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function sendVaultBalance(uint256 _amount, address payable _receiver) public onlyOwner {
        require(address(this).balance>= _amount, "Not enought WEI");
        _receiver.transfer(_amount);
    }

    /**
     * @dev Used for check if an asset is claimable
     */
    modifier isClaimable(uint256 miceTokenId) {
        uint256 i ;
        uint256[] memory miceOwner ;
        bool flagClaim ;
        
        flagClaim = false ;
        i=0;

        if(mice.ownerOf(miceTokenId) == msg.sender)
            flagClaim = true ;

        if(flagClaim==false) {
            miceOwner = cheeth.getTokensStaked(msg.sender);
            for(i=0; i<miceOwner.length; i++) {
                if(miceOwner[i] == miceTokenId) {
                    flagClaim = true;
                }
            }
        }

        require(flagClaim, "Must own the Anonymice for requested tokenId to claim a AnonymiceVX");
        _;
    }
}