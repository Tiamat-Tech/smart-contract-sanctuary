// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract Proxy {
    // Code position in storage is keccak256("PROXIABLE") = "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"
    constructor(bytes memory constructData, address contractLogic) public {
        // save the code address
        assembly { // solium-disable-line
            sstore(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7, contractLogic)
        }
        (bool success, bytes memory result) = contractLogic.delegatecall(constructData); // solium-disable-line
        require(success, "Construction failed");
    }

    fallback() external payable {
        assembly { // solium-disable-line
            let contractLogic := sload(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7)
            calldatacopy(0x0, 0x0, calldatasize())
            let success := delegatecall(sub(gas(), 10000), contractLogic, 0x0, calldatasize(), 0, 0)
            let retSz := returndatasize()
            returndatacopy(0, 0, retSz)
            switch success
            case 0 {
                revert(0, retSz)
            }
            default {
                return(0, retSz)
            }
        }
    }
}

contract Proxiable {
    // Code position in storage is keccak256("PROXIABLE") = "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"

    function updateCodeAddress(address newAddress) internal {
        require(
            bytes32(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7) == Proxiable(newAddress).proxiableUUID(),
            "Not compatible"
        );
        assembly { // solium-disable-line
            sstore(0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7, newAddress)
        }
    }
    function proxiableUUID() public pure returns (bytes32) {
        return 0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7;
    }
}


contract SwampGold is Context, Ownable, ERC20  , Proxiable {

    mapping(uint256 => mapping(uint256 => bool)) toadzSeasonClaimedByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) flyzSeasonClaimedByTokenId;
    mapping(uint256 => mapping(uint256 => bool)) polzSeasonClaimedByTokenId;

    uint256 season = 0;

    struct CyrptoContractInfo {
        address lootContractAddress;
        IERC721Enumerable lootContract;
        uint256 tokenAmount;
        uint256 tokenStartId;
        uint256 tokenEndId;
    }
    
    CyrptoContractInfo toadz;
    CyrptoContractInfo flyz;
    CyrptoContractInfo polz;
 
    function init() internal{
        
        address toadzContractAddress = 0xE5524aAD7BEf1e1bF711C55d63D9Bf9C8e2a5C2C;
        address flyzContractAddress = 0x1Fd612bFBe4c47dC462C8A8F032d0dC9dA75185a;
        address polzContractAddress = 0x13f2954330B4A2AC0271C740f8e2f8879dbf772D;
        
        toadz.lootContractAddress = toadzContractAddress;
        toadz.lootContract = IERC721Enumerable(toadzContractAddress);
        toadz.tokenAmount =  8500 * (10**decimals());
        toadz.tokenStartId = 1;
        toadz.tokenEndId = 6969;
        
        flyz.lootContractAddress = flyzContractAddress;
        flyz.lootContract = IERC721Enumerable(flyzContractAddress);
        flyz.tokenAmount =  1500 * (10**decimals());
        flyz.tokenStartId = 1;
        flyz.tokenEndId = 6969;
        
        polz.lootContractAddress = polzContractAddress;
        polz.lootContract = IERC721Enumerable(polzContractAddress);
        polz.tokenAmount =  1000 * (10**decimals());
        polz.tokenStartId = 1;
        polz.tokenEndId = 9696;
        
    } 

    function claimToadzById(uint256 tokenId) external {

        require(
            _msgSender() == toadz.lootContract.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimToadz(tokenId, _msgSender());
    }

    function claimFlyzById(uint256 tokenId) external {

        require(
            _msgSender() == flyz.lootContract.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimFlyz(tokenId, _msgSender());
    }

    function claimPolzById(uint256 tokenId) external {

        require(
            _msgSender() == polz.lootContract.ownerOf(tokenId),
            "MUST_OWN_TOKEN_ID"
        );

        _claimPolz(tokenId, _msgSender());
    }
 
    function claimAllToadz() external {
        uint256 tokenBalanceOwner = toadz.lootContract.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimToadz(
                toadz.lootContract.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }
 
    function claimAllFlyz() external {
        uint256 tokenBalanceOwner = flyz.lootContract.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimFlyz(
                flyz.lootContract.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }
 
    function claimAllPolz() external {
        uint256 tokenBalanceOwner = polz.lootContract.balanceOf(_msgSender());

        require(tokenBalanceOwner > 0, "NO_TOKENS_OWNED");

        for (uint256 i = 0; i < tokenBalanceOwner; i++) {
            _claimPolz(
                polz.lootContract.tokenOfOwnerByIndex(_msgSender(), i),
                _msgSender()
            );
        }
    }

    function _claimToadz(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= toadz.tokenStartId && tokenId <= toadz.tokenEndId,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !toadzSeasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );

        toadzSeasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, toadz.tokenAmount);
    }

    function _claimFlyz(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= flyz.tokenStartId && tokenId <= flyz.tokenEndId,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !polzSeasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );

        polzSeasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, flyz.tokenAmount);
    }


    function _claimPolz(uint256 tokenId, address tokenOwner) internal {

        require(
            tokenId >= polz.tokenStartId && tokenId <= polz.tokenEndId,
            "TOKEN_ID_OUT_OF_RANGE"
        );

        require(
            !polzSeasonClaimedByTokenId[season][tokenId],
            "GOLD_CLAIMED_FOR_TOKEN_ID"
        );

        polzSeasonClaimedByTokenId[season][tokenId] = true;

        _mint(tokenOwner, polz.tokenAmount);
    }


    function daoMint(uint256 amountDisplayValue) external onlyOwner {
        _mint(owner(), amountDisplayValue * (10**decimals()));
    }
    
    function test() public {
        init();
    }

    constructor() Ownable() ERC20("Swamp Gold", "SGLD") {}
    
}