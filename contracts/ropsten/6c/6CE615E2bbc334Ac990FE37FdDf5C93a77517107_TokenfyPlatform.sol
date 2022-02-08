// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TokenfyPlatform is Ownable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    IERC20 public paymentToken;

    mapping(uint256 => uint256) public pricesPerType;
    mapping(uint256 => uint256) public pricesPerTypeETH;

    mapping(string => bool) public nonceUsed;

    address private signerAddress;
    address private payoutAddress;

    event ProjectCreated(uint256 id, uint256 projectType, address creator);

    constructor(address paymentTokenAddress, address payout, address signer) {
        paymentToken = IERC20(paymentTokenAddress);
        payoutAddress = payout;
        signerAddress = signer;
    }

    function createProjectETH(
        bytes memory sig, 
        bytes32 hash,
        string memory nonce,
        uint256 id, 
        uint256 projectType
    ) payable public {
        require(pricesPerTypeETH[projectType] > 0, "TokenfyPlatform: invalid type");
        require(msg.value == pricesPerTypeETH[projectType], "TokenfyPlatform: wrong price");
        require(matchAddresSigner(hash, sig), "TokenfyPlatform: invalid signer");
		require(hashTransaction(msg.sender, id, projectType, nonce) == hash, "TokenfyPlatform: hash check failed");
        require(!nonceUsed[nonce], "TokenfyPlatform: nonce already used");

        nonceUsed[nonce] = true;

        emit ProjectCreated(id, projectType, msg.sender);
    }

    function createProjectTKNFY(
        bytes memory sig, 
        bytes32 hash,
        string memory nonce,
        uint256 id, 
        uint256 projectType
    ) public {
        require(pricesPerType[projectType] > 0, "TokenfyPlatform: invalid type");
        require(matchAddresSigner(hash, sig), "TokenfyPlatform: invalid signer");
		require(hashTransaction(msg.sender, id, projectType, nonce) == hash, "TokenfyPlatform: hash check failed");
        require(!nonceUsed[nonce], "TokenfyPlatform: nonce already used");

        nonceUsed[nonce] = true;
        paymentToken.safeTransferFrom(msg.sender, payoutAddress, pricesPerType[projectType]);

        emit ProjectCreated(id, projectType, msg.sender);
    }

    function setPaymentToken(address newToken) external onlyOwner {
        paymentToken = IERC20(newToken);
    }

    function setPayoutAddress(address newAddress) external onlyOwner {
        payoutAddress = newAddress;
    }

    function setSigner(address newAddress) external onlyOwner {
        signerAddress = newAddress;
    }

    function setPricePerType(uint8 projectType, uint256 priceTKNFY, uint256 priceETH) external onlyOwner {
        pricesPerType[projectType] = priceTKNFY;
        pricesPerTypeETH[projectType] = priceETH;
    }

    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns(bool) {
		return signerAddress == hash.recover(signature);
	}

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

	function hashTransaction(address sender, uint256 id, uint256 projectType, string memory nonce) private pure returns(bytes32) {
		bytes32 hash = keccak256(
			abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", 
                keccak256(abi.encodePacked(sender, id, projectType, nonce))
            )
		);
		return hash;
	}

}