pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./Interfaces/ICowNFT.sol";
import "./Interfaces/ICowToken.sol";
import "./Interfaces/IMultiToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MultiToken is IMultiToken, Ownable{

    ICowNFT public cowNFT;
    ICowToken public cowToken;
    uint256 multiTokenID;  //maybe not even necessary

    

    event transferredToMulti(address recipient, uint256 amount);
    event transferredFromMulti(address recipient, uint256 amount);

    

    struct multiToken {
        uint256 NFTtokenID;  //maybe an array of tokenIDs, that way each address only has one multiToken
        uint256 tokens;
        address owner;
    }

    mapping(address => mapping(uint256 => multiToken)) public tokenVault;
    mapping(address => uint256) public multiTokens;
    mapping(address => uint256) public userMultiTokenBalance;
    

    constructor(address _cowNFT, address _cowToken){
        cowNFT = ICowNFT(_cowNFT);
        cowToken = ICowToken(_cowToken);
        multiTokenID = 1;
        
    } 
    

       //Possibly hardcode tokenAddress to be the multi address, or have it as a state variable
    function transferToMulti(uint256 amount) override public {
        cowToken.transferFrom(msg.sender, address(this), amount);
        
        multiTokens[msg.sender] += amount;
        emit transferredToMulti(msg.sender, amount);
        
    }

    function transferFromMulti(uint256 amount) override public {
        require(multiTokens[msg.sender] >= amount, "Insuffecient tokens in MultiToken contract");
        cowToken.approve(address(this), amount);
        cowToken.transferFrom(address(this), msg.sender, amount);
        multiTokens[msg.sender] -= amount;
        emit transferredFromMulti(msg.sender, amount);
    }
   

    //**Implement more checking functionality to ensure there is no loss of tokens */
 
    function tieCombo(string memory _NLIS, uint256 _amount) override public {  //maybe make private
        
        multiToken memory _multiToken;
        uint256 _tokenId =  cowNFT.NLISToTokenID(_NLIS);
        require(_amount <= multiTokens[msg.sender], "User does not own enough CowCoin!");

        require(cowNFT.isOwnerOf(msg.sender, _tokenId), "Must be owner of cowNFT to combine");

        _multiToken = multiToken(_tokenId, _amount, msg.sender);

        multiTokens[msg.sender] -= _amount;  //safemath

        userMultiTokenBalance[msg.sender]++;       
 
        tokenVault[msg.sender][multiTokenID] = _multiToken;

        multiTokenID++;
    }

    function getMultiAssets(address owner, uint256 tokenID) public override view returns(uint256, uint256) {
        return (tokenVault[owner][tokenID].NFTtokenID, tokenVault[owner][tokenID].tokens);
    }

    function getUserTokenPool(address user) public override view returns(uint256) {
        return multiTokens[user];
    }

    function userPool(address user) public override view returns(uint256, uint256) {
        uint256 counter = 0;
        uint256 returnSum = 0;
        uint256 totalSum = 0;
        for(counter; counter < multiTokenID; counter++) {
            if (tokenVault[user][counter].NFTtokenID != 0) {
                returnSum += tokenVault[user][counter].tokens;
            }
        }

        totalSum = multiTokens[msg.sender] + returnSum;

        return (returnSum, totalSum);

    }

    function allMultiTokens(address user) public override view returns(uint256[] memory) {
        uint256 totalBalance= userMultiTokenBalance[user];

        if (totalBalance == 0) {
            return new uint256[](0);
        }

        uint256[] memory resultMulti = new uint256[](totalBalance);
        uint256 totalMSupply = multiTokenID;
        uint256 resultIndex = 0;

        uint256 multiID;

        for (multiID = 1; multiID <= totalMSupply; multiID++) {
        
            if (tokenVault[user][multiID].owner == user) {
                resultMulti[resultIndex] = multiID;
                resultIndex++;
            }
        }

        return resultMulti;

    }

}