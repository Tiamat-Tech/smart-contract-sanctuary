// contracts/Tile.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Tile is ERC1155, Ownable {
    // we use vanity IDs in the form XXXYYY - as in 500315 represents tile (500, 315).
    // this makes it easier to use; even right from the opensea url you can see the x,y coords

    // an empty (length == 0) value for pixel_colors, hovertext, url, or data means this call isn't setting it
    // todo: this means we can't set field to empty - problem? I think its fine. But if we want to support this,
    // we can add a uint8 as a bitmask of what values we do want to actually 0 out/what values we actually want to set
    event SetInfo(
        address from,
        uint256 x,
        uint256 y,
        uint256 width,
        uint256 height,
        bytes pixel_colors,
        string hovertext,
        string url,
        bytes data // no official use, but allows any future updates or alternative frontend to include more info or new features
        // , uint8 set_zero_bitmask // which values we do actually intened to set to 0. mask: 1 = pixel_colors, 2 = hovertext, 4 = url, 8 = data
    );

    uint256 public constant interval = 5; // todo better name? size?
    uint256 public constant pixels = 1000000;
    uint256 public constant side_length = 1000;
    uint256 constant total_tiles = pixels / (interval * interval);
    uint256 public constant color_depth = 7;

    // whether each tile id has been minted already
    // todo: possible with just using _balances[id] but that is private.
    // probably best to leave it private and use this
    mapping(uint256 => bool) minted;

    // total minted so far
    uint256 public total_num_minted = 0;

    // price of each tile = (total_num_minted) * price_increment + price_start
    uint256 public constant price_increment = 2 wei; // todo: placeholder
    uint256 public constant price_start = 5 wei; // todo: placeholder

    // returns price in wei
    function price_after(uint256 total_sold) public pure returns (uint256) {
        return total_sold * price_increment + price_start;
    }

    function current_price_of(uint256 num_tiles) public view returns (uint256) {
        return
            ((price_after(total_num_minted) +
                price_after(total_num_minted + num_tiles - 1)) / 2) * num_tiles;
    }

    constructor()
        ERC1155("http://www.million-token-homepage.com//tile/{id}.json")
    {
        //todo - anything?
    }

    function purchase(uint256[] memory ids) public payable {
        address sender = msg.sender; // todo: allow purchasing for someone besides yourself? what to other contracts do

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tile = ids[i];

            // require all tiles are not already minted
            require(!minted[tile]);

            require((tile % 1000) % interval == 0);
            require((tile / 1000) % interval == 0);

            require((tile / 1000) < side_length);
            require((tile / 1000) < side_length);

            // we set to true here to ensure no duplicates in the array
            // If any of the require's fail, whole call will be reverted,
            // so this won't really take effect.
            // todo: coming from 'normal' programming this feels so jank lol,
            // is there better way to do this
            minted[tile] = true;
        }

        uint256 price = current_price_of(ids.length);
        require(msg.value >= price);

        uint256[] memory amounts = new uint256[](ids.length);

        // todo: possible to initalize array with all 1s?
        for (uint256 i = 0; i < amounts.length; i++) {
            amounts[i] = 1;
        }

        // todo: assert nothing fails, etc, in all calls and stuff
        _mintBatch(sender, ids, amounts, "");

        total_num_minted += ids.length;
    }

    function owns_pixels(
        uint256 x,
        uint256 y,
        uint256 width,
        uint256 height,
        address addr
    ) public view returns (bool) {
        require(width > 0);
        require(height > 0);
        uint256 start_col = x / interval;
        uint256 end_col = (x + width - 1) / interval;
        uint256 start_row = y / interval;
        uint256 end_row = (y + height - 1) / interval;

        for (uint256 row = start_row; row <= end_row; row++) {
            for (uint256 col = start_col; col <= end_col; col++) {
                uint256 id = col * interval * 1000 + row * interval;
                if (balanceOf(addr, id) != 1) {
                    return false;
                }
            }
        }
        return true;
    }

    function setInfo(
        uint256 x,
        uint256 y,
        uint256 width,
        uint256 height,
        bytes memory pixel_colors,
        string memory hovertext,
        string memory url,
        bytes memory data
    ) public {
        address operator = _msgSender();
        require(owns_pixels(x, y, width, height, operator));

        emit SetInfo(
            operator,
            x,
            y,
            width,
            height,
            pixel_colors,
            hovertext,
            url,
            data
        );
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}