// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Wallets May Be Anonymous
// But The Behaviour Is Not
contract BadgeOfHonor is ERC1155, Ownable {
    string private constant BADASS = '<svg width="100" height="100"><circle cx="50" cy="50" r="40" stroke="green" stroke-width="4" fill="yellow" /></svg>';
    string private constant ASSHOLE = '<svg width="100" height="100"><circle cx="50" cy="50" r="40" stroke="red" stroke-width="4" fill="yellow" /></svg>';

    string[] svgs;
    uint256 badges;

    constructor() ERC1155("") {
        badges = 2;
    }

    uint256 private constant FEE_BASE = .00001 ether;

    function establish(uint256 id, string calldata svg) external onlyOwner {
        svgs[id] = svg;
        badges++;
    }

    function award(
        address to,
        uint256 badgeId,
        uint256 level
    ) external payable {
        require(level * FEE_BASE == msg.value, "InvalidETHAmount");
        require(badgeId < badges, "UnknownBadge");

        ERC1155._mint(to, badgeId, level, "");
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        operator;
        to;
        ids;
        amounts;
        data;
        require(from == address(0), "Wear Your Badge Proudly");
    }

    function uri(uint256 id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(id < badges, "UnknownTokenId");
        if (id == 0) return _wrap(BADASS);
        if (id == 1) return _wrap(ASSHOLE);

        return svgs[id];
    }

    function _wrap(string memory svgText) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    'data:application/json;utf8,{"name":"Badge Of Honor","image":"data:image/svg+xml;utf8,',
                    svgText,
                    '",',
                    '"license":"wtf is a license","creator":"Holy of Holies",',
                    '"description":"Wallets May Be Anon, But The Behavior Is Not"',
                    "}"
                )
            );
    }
}