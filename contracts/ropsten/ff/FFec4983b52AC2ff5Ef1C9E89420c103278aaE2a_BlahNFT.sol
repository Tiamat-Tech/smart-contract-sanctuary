//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./BlahNFTScore.sol";

contract BlahNFT is BlahNFTScore {

    //TODO: test this more to make sure it's working
    function uploadMetadata(BlahNFTTypes.City[] memory _cities) external onlyOwner {
        for(uint i = 0; i < _cities.length; i++) {
            //if there is no data for this city already
            if(idToCities[_cities[i].id].countryFaction == 0) {
                //TODO: might need to set country faction here
                idToCities[_cities[i].id] = BlahNFTTypes.City(_cities[i].id, _cities[i].city, _cities[i].country, _cities[i].image, _cities[i].points, _cities[i].cityFaction, _cities[i].countryFaction);
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        BlahNFTTypes.City storage city = idToCities[tokenId];
        if(!hasUploadedMetadata(city)) {
            super._transfer(from, to, tokenId);
            city.cityFaction = getAddressFaction(to);
            addressToFaction[to] = city.cityFaction;
            return;
        }
        
        //choose faction for new address
        bool isNewOwner = addressToFaction[to] == 0;
        uint8 faction;
        if(isNewOwner) {
            faction = getOverallLosingFaction();
        } else {
            faction = addressToFaction[to];
        }
        super._transfer(from, to, tokenId);
        //update our data after the transfer has succeeded
        addressToFaction[to] = faction;

        if(addressToFaction[from] != addressToFaction[to]) {
            //recount country score
            (uint redPoints, uint greenPoints, uint bluePoints) = calculateCountryScore(city.country);
            uint8 winningFaction = getWinningFaction(redPoints, greenPoints, bluePoints);
            //set current city to new faction
            city.cityFaction = faction;
            //recount after change
            (redPoints, greenPoints, bluePoints) = calculateCountryScore(city.country);
            uint8 winningFactionAfter = getWinningFaction(redPoints, greenPoints, bluePoints);
            if(winningFaction != winningFactionAfter) {
                //set country owner change
                setCountryWinningFaction(city.country, winningFactionAfter);
                //TODO: emmit that a country just changed
            }
        }
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        BlahNFTTypes.City memory city = idToCities[_tokenId];
        console.log('tokenId', _tokenId);
        console.log('city', city.city);
        
        string memory image = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '<svg width="2000" height="2000"><rect width="100%" height="100%" fill="',
                        factionToColor(city.countryFaction),
                        '" /><image href="',
                        city.image,
                        '" height="2000" width="2000"/></svg>'
                    )
                )
            )
        );
        
        string memory attributes = string(
            abi.encodePacked(
                '{"trait_type": "city",',
                '"value": "', city.city,
                '"},{"trait_type": "country",',
                '"value": "', city.country,
                '"},{"trait_type": "points",',
                '"value": ', uintToByteString(city.points, 2),
                '},{"trait_type": "city faction",',
                '"value": "', factionToColorName(city.cityFaction),
                '"},{"trait_type": "country faction",',
                '"value": "', factionToColorName(city.countryFaction),
                '"}'
            )
        );
        if(!hasUploadedMetadata(city)) {
            attributes = string(
                abi.encodePacked(
                    '{"trait_type": "city faction",',
                    '"value": "', factionToColorName(city.cityFaction),
                    '"}'
                )
            );
        }
        string memory imageString = string(abi.encodePacked('data:image/svg+xml;base64,', image));
        string memory nameString = city.city;
        if(!hasUploadedMetadata(city)) {
            imageString = placeHolderImage;
            nameString = string(abi.encodePacked("City ", uintToByteString(_tokenId, 4)));
        }
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{',
                            '"name": "', nameString,
                            '", "tokenId": ', uintToByteString(_tokenId, 4),
                            ', "image": ', '"', imageString,
                            '", "description": "City Clash is a NFT game with 3 factions all on chain.",',
                            '"attributes": [',
                                attributes,
                            ']',
                        '}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(abi.encodePacked("data:application/json;base64,", json));
        console.log("\n--------------------");
        console.log(finalTokenUri);
        console.log("--------------------\n");
        return finalTokenUri;
    }

    function factionToColorName(uint _faction) private pure returns (string memory str) {
        if(_faction == 1) {
            return "red";
        } else if(_faction == 2) {
            return "green";
        } else if(_faction == 3) {
            return "blue";
        }
    }

    function factionToColor(uint _faction) private pure returns (string memory str) {
        if(_faction == 1) {
            return "#f7411d";  //red
        } else if(_faction == 2) {
            return "#46dd2c";     //green
        } else if(_faction == 3) {
            return "#27ace5";      //blue
        }
    }

    /*
    Convert uint to byte string, padding number string with spaces at end.
    Useful to ensure result's length is a multiple of 3, and therefore base64 encoding won't
    result in '=' padding chars.
    */
    function uintToByteString(uint _a, uint _fixedLen) internal pure returns (bytes memory _uintAsString) {
        uint j = _a;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(_fixedLen);
        j = _fixedLen;
        if (_a == 0) {
            bstr[0] = "0";
            len = 1;
        }
        while (j > len) {
            j = j - 1;
            bstr[j] = bytes1(' ');
        }
        uint k = len;
        while (_a != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_a - _a / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _a /= 10;
        }
        return bstr;
    }

    function withdraw() public onlyOwner {
        (bool success,) = msg.sender.call{value : address(this).balance}('');
        require(success, "Withdrawal failed");
    }
}