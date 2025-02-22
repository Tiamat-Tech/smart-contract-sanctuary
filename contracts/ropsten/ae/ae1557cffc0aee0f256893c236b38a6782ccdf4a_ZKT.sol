pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./airdropVerifier.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Largely inspired by https://github.com/Uniswap/merkle-distributor/blob/master/contracts/interfaces/IMerkleDistributor.sol
contract ZKT is ERC20, Verifier {
    uint256 public merkleRoot;
    mapping(uint256 => bool) public claimedNullifiers;
    string public messageClaimString = 'zk-airdrop';
    uint256 messageClaimHash = 0x52a0832a7b7b254efb97c30bb6eaea30ef217286cba35c8773854c8cd41150de;
    event Claim(address indexed claimant, uint256 amount);

    /**
     * @dev Constructor.
     * @param freeSupply The number of tokens to issue to the contract deployer.
     * @param airdropSupply The number of tokens to reserve for the airdrop.
     * @param _merkleRoot Merkle Root of the Airdrop addresses.
     */
    constructor(
        uint256 freeSupply,
        uint256 airdropSupply,
        uint256 _merkleRoot
    ) public ERC20("Zero Knowledge Token", "ZKT") {
        _mint(msg.sender, freeSupply);
        _mint(address(this), airdropSupply);
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev Claims airdropped tokens.
     * @param a ZK merkle proof alpha proving the claim is valid.
     * @param b ZK merkle proof beta proving the claim is valid.
     * @param c ZK merkle proof charlie proving the claim is valid.
     * @param signals ZK merkle proof signals proving the claim is valid.
     */
    function claimTokens(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[6] memory signals
    ) external {
        // TODO indices
        require(
            signals[0] == merkleRoot,
            "Merkle Root does not match contract"
        );
        require(
            !claimedNullifiers[signals[5]],
            "Nullifier has already been claimed"
        );
        require(
            signals[4] == uint256(msg.sender),
            "Sender address does not match zk input sender address"
        );
        require(signals[1] == 0x000000000000000000000000000000000000000000235c8773854c8cd41150de, "Message hash invalid"); // TODO
        require(signals[2] == 0x0000000000000000000000000000000000000000000c2edbaba8c3bc85ca1b2e, "Message hash invalid"); // TODO
        require(signals[3] == 0x000000000000000000000000000000000000000000052a0832a7b7b254efb97c, "Message hash invalid"); // TODO
        require(verifyProof(a, b, c, signals), "Invalid Proof");
        claimedNullifiers[signals[0]] = true;
        emit Claim(msg.sender, 10**18);
        _transfer(address(this), msg.sender, 10**18);
    }
}