// SPDX-License-Identifier: MIT
pragma solidity =0.8.3;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import "./interfaces/IVotingStrategy.sol";

contract SingleSignVotingStrategy is IVotingStrategy, EIP712 {
  bytes32 private constant VOTING_TYPEHASH =
    keccak256(
      "Voting(address voter,address roadmap,uint256 proposalId,uint256 optionId,uint256 votingPower,bytes ipfsHash)"
    );

  address public trustedSigner;
  string internal urlInternal;

  constructor(address _trustedSigner, string memory _url)
    EIP712("MilestoneBasedVotingStrategy", "1")
  {
    trustedSigner = _trustedSigner;
    urlInternal = _url;
  }

  function url() external view override returns (string memory) {
    return urlInternal;
  }

  function isValid(
    Vote calldata vote,
    uint256[] calldata argumentsU256,
    bytes32[] calldata argumentsB32
  ) external view override returns (bool) {
    require(
      argumentsU256.length == 1,
      "ArgumentsU256 should contain 1 element (v)"
    );
    require(
      argumentsB32.length == 2,
      "ArgumentsB32 should contain 2 elements (r, s)"
    );
    uint8 v = (uint8)(argumentsU256[0]);
    bytes32 r = argumentsB32[0];
    bytes32 s = argumentsB32[1];

    bytes32 digest = getDigest(vote);
    return ECDSA.recover(digest, v, r, s) == trustedSigner;
  }

  function getDigest(Vote calldata vote) internal view returns (bytes32) {
    return
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            VOTING_TYPEHASH,
            vote.voter,
            vote.roadmap,
            vote.proposalId,
            vote.optionId,
            vote.votingPower,
            keccak256(vote.ipfsHash)
          )
        )
      );
  }

  //TODO remove temp
  function split(bytes memory signature) public pure returns(bytes32, bytes32, uint8) {
    bytes32 r;
    bytes32 s;
    uint8 v;

    // Check the signature length
    // - case 65: r,s,v signature (standard)
    // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
    if (signature.length == 65) {
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
    } else if (signature.length == 64) {
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let vs := mload(add(signature, 0x40))
            r := mload(add(signature, 0x20))
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
    } else {
        revert("ECDSA: invalid signature length");
    }

    return (r, s, v);
  }
}