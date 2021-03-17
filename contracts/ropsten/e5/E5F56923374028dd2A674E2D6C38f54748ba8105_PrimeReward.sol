pragma solidity 0.7.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface IGpsStatementVerifier {
    function isValid(bytes32 _factHash) external returns(bool); 
}

contract PrimeReward is ERC721 {

    uint public cairoOutputProgramHash;
    IGpsStatementVerifier public verifier;

    uint solutionsCounter;
    mapping(uint => bool) claimed;

    constructor(
        uint _cairoOutputProgramHash,
        IGpsStatementVerifier _verifier
    ) ERC721("Prime Reward", "PRW") {
        cairoOutputProgramHash = _cairoOutputProgramHash;
        verifier = _verifier;
    }

    function claimReward(uint solution) external {

        uint[] memory s = new uint[](1);
        s[0] = solution;

        bytes32 _factHash = keccak256(abi.encodePacked(
            cairoOutputProgramHash,
            keccak256(abi.encodePacked(s))
        ));

        require(verifier.isValid(_factHash), "Invalid solution");
        require(!claimed[solution]);
        claimed[solution] = true;

        _mint(msg.sender, solutionsCounter++);
    }


}