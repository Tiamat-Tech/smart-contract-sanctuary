// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./plugins/TokensHandler.sol";


contract ERents is ERC721Holder, ERC1155Holder, Ownable, ReentrancyGuard, TokensHandler {
    uint public id;
    uint public fee = 20;
    enum Status {
        LISTED,
        RENTED,
        CANCELLED
    }
    struct Rent {
        address owner;
        address currency;
        address client;
        address[] nftAddresses;
        uint[] nftIds;
        uint returningTime;
        uint valability;
        uint expiration;
        uint price;
        uint fee;
        uint32[] nftTypes;
        Status status;
    }
    mapping(uint => Rent) public rents;

    event NewRent(uint indexed id, Rent rent);
    event RentOngoing(uint indexed id, Rent rent);
    event RentCancelled(uint indexed id, Rent rent);
    event RentDone(uint indexed id, Rent rent);

    function setFee(uint _fee) external onlyOwner {
        require(_fee > 0,"Fee should be greater than 0");
        fee = _fee;
    }

    modifier isAccesible(uint rentId) {
        require(rentId < id, "Rent ID it not valid");
        require(rents[rentId].owner != address(0), "Rent is no longer accessible");
        _;
    }

    function create(address[] calldata _nftAddresses,uint[] calldata _nftIds,uint32[] calldata _nftTypes,uint _valability,uint _price,uint _fee, address _currency) external {
        require(_fee * 2 < _price && _valability > 0 && _fee > 0, "Valability must be atleast 1 day, rent fee must be greater than 0 and NFT price must be atleast 2x + 1 of fee");
        require(_nftAddresses.length > 0, "Cannot create an empty rent, please add items");
        rents[id].owner = msg.sender;
        rents[id].valability = _valability;
        rents[id].price = _price;
        rents[id].fee = _fee;
        rents[id].currency = _currency;
        rents[id].nftAddresses = _nftAddresses;
        rents[id].nftIds = _nftIds;
        rents[id].nftTypes = _nftTypes;
        rents[id].returningTime = 1 days;
        rents[id].status = Status.LISTED;

        // Transfer the items from sender to BRents smart contract
        transferTokens(msg.sender,address(this),_nftAddresses,_nftIds,_nftTypes);     

        emit NewRent(id, rents[id]);
        ++id;
    }

    function cancel(uint rentId) external isAccesible(rentId) nonReentrant {
        require(msg.sender == rents[rentId].owner, "You're not the owner of this rent");
        require(rents[rentId].client == address(0), "Sell has been completed, not possible to cancel");
        require(rents[rentId].status == Status.LISTED, "Rent cannot be currently cancelled");


        rents[rentId].status = Status.CANCELLED;

        // Transfer the items from BRents to sender
        transferTokens(address(this),msg.sender,rents[rentId].nftAddresses,rents[rentId].nftIds,rents[rentId].nftTypes);
        
        emit RentCancelled(rentId,rents[rentId]);
    }

    function rent(uint rentId) external payable isAccesible(rentId) nonReentrant {
        require(rents[rentId].expiration == 0 || ( rents[rentId].expiration > 0 && rents[rentId].expiration + rents[rentId].returningTime < block.timestamp ), "Rent is still ongoing, try again later");
        require((msg.value >= rents[rentId].price && rents[rentId].currency == address(0)) || (msg.value == 0 && rents[rentId].currency != address(0)), "Insert the correct tokens");
        require(rents[rentId].client == address(0), "This rent is already ongoing");
        require(rents[rentId].status == Status.LISTED, "Rent cannot be currently used");

        if ( rents[rentId].currency != address(0) )
            require(IERC20(rents[rentId].currency).transferFrom(
                msg.sender,
                address(this), 
                rents[rentId].price
            ), "Transfer of tokens failed");
      

        // Transfer the items from BRents to sender
        transferTokens(address(this),msg.sender,rents[rentId].nftAddresses,rents[rentId].nftIds,rents[rentId].nftTypes);

        rents[rentId].expiration = block.timestamp + rents[rentId].valability;
        rents[rentId].client = msg.sender;
        rents[rentId].status = Status.RENTED;
        
        emit RentOngoing(rentId,rents[rentId]);
    }

    function finish(uint rentId) external isAccesible(rentId) nonReentrant {
        require(msg.sender == rents[rentId].client || ( msg.sender == rents[rentId].owner && rents[rentId].expiration < block.timestamp), "You cannot access this");

        uint bmarketFee;

        if ( block.timestamp <= rents[rentId].expiration + rents[rentId].returningTime ){
            bmarketFee = rents[rentId].fee / fee;
            if ( rents[rentId].currency != address(0) ){
                require(IERC20(rents[rentId].currency).transferFrom(
                    address(this),
                    rents[rentId].client, 
                    rents[rentId].price - rents[rentId].fee
                ), "Transfer of tokens to client failed");
                require(IERC20(rents[rentId].currency).transferFrom(
                    address(this),
                    rents[rentId].owner, 
                    rents[rentId].fee - bmarketFee
                ), "Transfer of tokens to owner failed");
                require(IERC20(rents[rentId].currency).transferFrom(
                    address(this),
                    owner(), 
                    bmarketFee
                ), "Transfer of tokens to BMarket failed");
            }else{
                require(payable(rents[rentId].client).send(rents[rentId].price - rents[rentId].fee),"Transfer of ETH to client failed");
                require(payable(rents[rentId].owner).send(rents[rentId].fee - bmarketFee),"Transfer of ETH to receiver failed");
                require(payable(owner()).send(bmarketFee),"Transfer of ETH to BMarket failed");
            }
        }else{
            bmarketFee = rents[rentId].price / fee;
            if ( rents[rentId].currency != address(0) ){
                require(IERC20(rents[rentId].currency).transferFrom(
                    address(this),
                    rents[rentId].owner, 
                    rents[rentId].price - bmarketFee
                ), "Transfer of tokens to owner failed");
                require(IERC20(rents[rentId].currency).transferFrom(
                    address(this),
                    owner(), 
                    bmarketFee
                ), "Transfer of tokens to BMarket failed");
            }else{
                require(payable(rents[rentId].owner).send(rents[rentId].price - bmarketFee),"Transfer of ETH to receiver failed");
                require(payable(owner()).send(bmarketFee),"Transfer of ETH to BMarket failed");
            }
        }


        // Transfer the items from sender to BRents smart contract
        transferTokens(rents[rentId].client,address(this),rents[rentId].nftAddresses,rents[rentId].nftIds,rents[rentId].nftTypes);

        rents[rentId].client = address(0);

        rents[rentId].status = Status.LISTED;

        rents[rentId].expiration = 0;
        
        emit RentDone(rentId,rents[rentId]);
    }

}