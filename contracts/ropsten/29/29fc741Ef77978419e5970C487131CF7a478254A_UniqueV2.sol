// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./unique.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract UniqueV2 is Unique, AccessControlUpgradeable, ReentrancyGuardUpgradeable{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address[] authorizedMarketplaces;
    
    event ModifiedMarketplace(address[] list);
    event MarketplaceListCleared();

    /* 
    * only using this for this version, will add these functions to initializer 
    * when we redeploy. Also RentrancyGuard and AccessControl can't be initializd in this version 
    * since "initilizer" is already initialized.
    */
    function setUpMinterRole(address _minter) external onlyOwner {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _minter);
        _setupRole(MINTER_ROLE, _msgSender());
    }

    function createMoment(
        address account, 
        string memory uri
    ) 
        external virtual override 
        onlyRole(MINTER_ROLE) 
        returns (uint256 id) 
    {
        uint256 _id = ids.current();
        ids.increment();
        _safeMint(account, _id);
        _setTokenURI(_id, uri);
        emit Created(account, _id);
        return _id;
    }

    function createMoments(
        address account,
        uint256 numberOfMoments,
        string[] memory uri
    ) 
        external virtual override
        onlyRole(MINTER_ROLE) 
        returns (uint256[] memory _ids) 
    {
        uint256[] memory _idsArray = new uint256[](numberOfMoments);

        for (uint i = 0; i < numberOfMoments; i++){
            _idsArray[i] = ids.current();
            ids.increment();         
        }
        _mintBatch(account, _idsArray, uri);

        emit CreatedBatch(account, _idsArray);
        return _idsArray;
    }

    function buyMoment(
        uint256 id
    ) 
        external payable virtual override 
        nonReentrant 
    {
        require(
            msg.value >= auction[id].price,
            "Minimum purchase price not met"
        );
        require(
            auction[id].status == Stages.ForSale,
            "Moment not for sale"
        );

        // mark the NFT no longer for sale once it has a buyer
        auction[id].status = Stages.SaleInProgress;
        auction[id].price = msg.value;
        auction[id].buyer = _msgSender();
        safeTransferFrom(ownerOf(id), _msgSender(), id);
        emit Purchased(id, _msgSender());
    }

    function setMarketplace(address[] calldata authorizedList) external virtual onlyOwner {
        for (uint i = 0; i < authorizedList.length; i++) {
            authorizedMarketplaces.push(authorizedList[i]);
        }
        emit ModifiedMarketplace(authorizedList);
    }
    
    function getMarketplace() external view virtual returns (address[] memory) {
        return authorizedMarketplaces;
    }

    function clearMarketplace() external virtual onlyOwner {
        delete authorizedMarketplaces;
        emit MarketplaceListCleared();
    }
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id
    ) 
        internal virtual override 
    {
        if(from != address(0) && to != address(0)) {
            // check if 'from' or 'to' address is an authorized marketplace address
            for (uint i = 0; i < authorizedMarketplaces.length; i++) {
                if (authorizedMarketplaces[i] == _msgSender()) 
                {
                    // short circuit royalty enforcement as it's handled by the marketplace
                    return;
                }
            }

            require(auction[id].buyer == to); 
            require(auction[id].status == Stages.SaleInProgress); 

            auction[id].buyer = address(0);
            uint256 price = auction[id].price;
            auction[id].price = 0;
            // calculate royalty fee in 1 basis point
            // 1 basis point = 0.01%
            uint256 fee = (price * rate) / 10000;
            // transfer fee to royalty address
            (bool success, ) = royaltyOwner.call{value: fee}("");
            require(success, "Royalty transfer failed");
            // transfer funds minus fee to seller
            (success, ) = payable(ownerOf(id)).call{value: price - fee}("");
            require(success, "Seller transfer failed");

            // reset auction sale so NFT is no longer for sale
            auction[id].status = Stages.NotForSale;
        }
    }   

    function supportsInterface(
        bytes4 interfaceId
    ) 
        public view virtual override(AccessControlUpgradeable, ERC721Upgradeable) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    } 

    function version() external pure virtual override returns (string memory) {
        return "2.0.0";
    }  

}