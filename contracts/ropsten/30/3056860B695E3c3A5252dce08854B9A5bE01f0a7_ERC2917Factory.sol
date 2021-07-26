pragma solidity >=0.7.0;

import "./ERC2917.sol";
import "../libraries/CloneFactory.sol";

contract ERC2917Factory is CloneFactory {
    ERC2917Impl[] public children;
    address masterContract;

    event ERC2917Created(address newERC2917Address, address masterContract);

    constructor(address _masterContract) {
        masterContract = _masterContract;
    }

    function onlyCreate() public {
        createClone(masterContract);
    }

    function createERC2917Impl(
        uint256 _interestsRate,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _impl,
        address _governor
    ) external {
        address clone = createClone(masterContract);
        ERC2917Impl child = ERC2917Impl(createClone(masterContract));
        child.initialize(
            _interestsRate,
            _name,
            _symbol,
            _decimals,
            _impl,
            _governor
        );
        children.push(child);
        emit ERC2917Created(clone, masterContract);
    }

    function getChildren() external view returns (ERC2917Impl[] memory) {
        return children;
    }

    function isERC2917(address _erc2917) public view returns (bool) {
        return isClone(masterContract, _erc2917);
    }

    // function incrementERC2917(address[] memory erc2917s) public returns (bool) {
    //     for (uint256 i = 0; i < erc2917s.length; i++) {
    //         require(isERC2917(erc2917s[i]), "Must all be erc2917s");
    //         ERC2917Impl(erc2917s[i]).increment();
    //     }
    // }
}