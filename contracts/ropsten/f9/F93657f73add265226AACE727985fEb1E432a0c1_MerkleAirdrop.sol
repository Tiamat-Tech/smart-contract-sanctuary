// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";

contract MerkleAirdrop is Ownable, ReentrancyGuard {
    /* STATE VARIABLES */

    bytes32[] public merkleRoots;

    IERC20 public tokenContract;

    mapping(uint256 => mapping(address => bool)) public isSpent;

    /* MODIFIERS */
    /* EVENTS */

    event AirdropTransfer(address addr, uint256 num, uint256 rootInd);

    /* FUNCTIONS */

    constructor(IERC20 _tokenContract) {
        tokenContract = _tokenContract;
    }

    /* EXTERNAL FUNCTIONS */

    function addRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoots.push(_merkleRoot);
    }

    function claimRestOfTokensAndSelfdestruct()
        external
        onlyOwner
        nonReentrant
        returns (bool)
    {
        address _owner = owner();
        uint256 _tokenBalance = tokenContract.balanceOf(address(this));
        require(_tokenBalance >= 0);
        require(
            tokenContract.transfer(_owner, _tokenBalance),
            "MerkleAirdrop: Transfer failed"
        );
        delete merkleRoots;
        selfdestruct(payable(_owner));
        return true;
    }

    function claimTokens(IERC20 _token, uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(address(_token) != address(0), "MerkleAirdrop: Wrong token");
        uint256 tokenBalance = _token.balanceOf(address(this));
        require(tokenBalance > 0, "MerkleAirdrop: Token balane equals zero");
        require(amount < tokenBalance, "MerkleAirdrop: Wrong amount");
        if (amount == 0) amount = tokenBalance;
        require(
            _token.transfer(owner(), amount),
            "MerkleAirdrop: Transfer failed"
        );
    }

    function getTokensByMerkleProof(
        bytes32[] calldata _proof,
        address _who,
        uint256 _amount,
        uint256 rootInd
    ) external nonReentrant returns (bool) {
        require(
            isSpent[rootInd][_who] != true,
            "MerkleAirdrop: This user has already benn used"
        );
        require(_amount > 0, "MerkleAirdrop: Wring amount");

        if (
            !_checkProof(
                _proof,
                _leafFromAddressAndNumTokens(_who, _amount),
                rootInd
            )
        ) {
            return false;
        }

        isSpent[rootInd][_who] = true;

        require(
            tokenContract.transfer(_who, _amount),
            "MerkleAirdrop: Transfer failed"
        );

        emit AirdropTransfer(_who, _amount, rootInd);
        return true;
    }

    /* EXTERNAL VIEW FUNCTIONS */

    function contractTokenBalance() external view returns (uint256) {
        return tokenContract.balanceOf(address(this));
    }

    function numOfRoots() external view returns (uint256) {
        return merkleRoots.length;
    }

    /* PUBLIC FUNCTIONS */
    /* INTERNAL FUNCTIONS */
    /* PRIVATE FUNCTIONS */
    /* PRIVATE PURE FUNCTIONS */

    function _leafFromAddressAndNumTokens(address _a, uint256 _n)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_a, _n));
    }

    /* PRIVATE VIEW FUNCTIONS */

    function _checkProof(
        bytes32[] calldata proof,
        bytes32 _hash,
        uint256 rootInd
    ) private view returns (bool) {
        bytes32 el;
        bytes32 h = _hash;

        for (uint256 i = 0; i < proof.length; i += 1) {
            el = proof[i];

            if (h < el) {
                h = keccak256(abi.encodePacked(h, el));
            } else {
                h = keccak256(abi.encodePacked(el, h));
            }
        }

        return h == merkleRoots[rootInd];
    }
}