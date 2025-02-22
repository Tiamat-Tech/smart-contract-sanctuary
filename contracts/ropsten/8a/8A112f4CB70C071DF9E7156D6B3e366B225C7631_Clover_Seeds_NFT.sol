pragma solidity 0.8.11;

// SPDX-License-Identifier: MIT

import "./SafeMath.sol";
import "./IContract.sol";
import "./ERC721Upgradeable.sol";
import "./ERC721URIStorageUpgradeable.sol";
import "./PausableUpgradeable.sol";
import "./OwnableUpgradeable.sol";
import "./ERC721BurnableUpgradeable.sol";
import "./Initializable.sol";

contract Clover_Seeds_NFT is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, PausableUpgradeable, OwnableUpgradeable, ERC721BurnableUpgradeable {
    using SafeMath for uint256;
    
    uint256 private _cap = 333e3;

    mapping (address => bool) public minters;

    address public Clover_Seeds_Picker;
    address public Clover_Seeds_Stake;

    function initialize() initializer public {
        __ERC721_init("Clover SEED$ NFT", "CSNFT");
        __ERC721URIStorage_init();
        __Pausable_init();
        __Ownable_init();
        __ERC721Burnable_init();
    }
    
    modifier onlyMinter() {
        require(minters[msg.sender], "Restricted to minters.");
        _;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addMinter(address account) public onlyOwner {
        minters[account] = true;
    }

    function removeMinter(address account) public onlyOwner {
        minters[account] = false;
    }

    function Approve(address to, uint256 tokenId) public {
        _approve(to, tokenId);
    }

    function setApprover(address _approver) public onlyOwner {
        isApprover[_approver] = true;
    }

    function safeMint(address to, uint256 tokenId) public onlyMinter {
        require(totalSupply().add(tokenId) <= _cap, "SEED NFT: All token minted...");
        _safeMint(to, tokenId);

        IContract(Clover_Seeds_Token).addAsNFTBuyer(to);

        uint256 id = IContract(Clover_Seeds_Picker).getLuckyNumber();

        if (id >= 50 && id < 56 && tokenId <= 3e3) {
            to = IContract(Clover_Seeds_Stake).getLuckyWalletForCloverField();
        }
        
        if (id >= 50 && id < 56 && tokenId > 3e3 && tokenId <= 33e3) {
            to = IContract(Clover_Seeds_Stake).getLuckyWalletForCloverYard();
        }
        
        if (id >= 50 && id < 56 && tokenId > 33e3 && tokenId <= 333e3) {
            to = IContract(Clover_Seeds_Stake).getLuckyWalletForCloverPot();
        }
        
        if (msg.sender != Controller) {
            require(IContract(Controller).addMintedTokenId(tokenId), "SEED NFT: Unable to call addMintedTokenId..");
        }

        require(IContract(Clover_Seeds_Picker).randomLayer(tokenId), "SEED NFT: Unable to call randomLayer..");
        
    }

    function setClover_Seeds_Token(address SeedsToken) public onlyOwner {
        Clover_Seeds_Token = SeedsToken;
    }

    function set_cap(uint256 amount) public onlyOwner {
        _cap = amount;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    function addURI(uint256[] memory tokenId, string[] memory uri) public onlyOwner {
        require(tokenId.length == uri.length, "SEED NFT: Please enter equal tokenId & uri length..");
        
        for (uint256 i = 0; i < tokenId.length; i++) {
            _setTokenURI(tokenId[i], uri[i]);
        }
    }

    function setClover_Seeds_Picker(address _Clover_Seeds_Picker) public onlyOwner {
        Clover_Seeds_Picker = _Clover_Seeds_Picker;
    }

    function setController(address _controller) public onlyOwner {
        Controller = _controller;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}