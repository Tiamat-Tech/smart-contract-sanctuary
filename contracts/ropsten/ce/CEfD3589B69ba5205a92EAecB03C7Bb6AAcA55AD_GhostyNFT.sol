// contracts/GhostyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./Tools.sol";

contract GhostyNFT is ERC721Enumerable {

    mapping(uint256 => Feature[]) internal featureList;

    uint256 internal GHOSTIES = 10000;
    uint256 internal FREE_THRESHOLD = 0;
    uint256 internal MAXMINT = 5;
    uint256 internal mintPrice = 0.02 ether;

    address internal _owner;

    bytes12[]   featureCategories;
    uint[][6]   featureRarity;
    string      standardBorder;

    struct Feature {
        uint256   category;
        uint256   level;
        string    name;
        string    uniqueDisplay;
    }

    constructor() ERC721("GhostyNFT", "GHOSTY") {
        
        _owner = msg.sender;

        featureCategories.push('Background');
        featureRarity[0] = [2000, 2500, 3000, 3500, 4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500, 8000, 8500, 9000, 9500, 10000];


                           //ghosty           gremlin           eeyore            radioactive
                                  //old timer       zombie            TRON              legendary Gold
                                        //sunburnt        ghostbot          mummy             legendary Ethereal
        featureRarity[1] = [2300, 4300, 5800, 7100, 8100, 8600, 9000, 9400, 9800, 9985, 9995, 10000];
        featureCategories.push('Body');


                           //Normal           Spooks            Cap'n Jack        Snurkey
                                  //Happy           Winky             Mr. Monopoly      Elton
                                        //Squints         Lashes            Swim Team
        featureRarity[2] = [2000, 3500, 4800, 6000, 7000, 7900, 8600, 9200, 9600, 9900, 10000];
        featureCategories.push('Eyes');


                            //normal          grumpy            snaggle           zip your lid
                                  //frustrated      toothy            surprise          count dracula
                                      //smile             singing           boo
        featureRarity[3] = [2500, 3300, 5300, 5900, 7200, 7800, 8100, 8800, 9500, 9800, 10000];
        featureCategories.push('Mouth');



                           //none             bowler            cowboy
                                  //beanie          napster           royal
                                        //turkey leg      party ghost       jazzercise
        featureRarity[4] = [3000, 4800, 6000, 7200, 7800, 8200, 9000, 9800, 10000];
        featureCategories.push('Headwear');


                            //Not Animated
                                  //Floating
                                        //Vanish
        featureRarity[5] = [9400, 9800, 10000];
        featureCategories.push('Is Animated');
        
    }

    /*
    function getFeature(uint256 categoryIndex, uint256 featureIndex) internal view returns(Feature memory) {

        for (uint256 i = 0; i < featureList[categoryIndex].length; i++) {

            if (featureList[categoryIndex][i].level == featureIndex){
                return featureList[categoryIndex][i];
            }
        }

        revert();

    }

    
    function synthesizeFeature(uint256 featureIndex, uint256 diceRoll) internal view returns(Feature memory) {

        for (uint256 i = 0; i < featureRarity[featureIndex].length; i++) {

            if (diceRoll <= featureRarity[featureIndex][i]){
                return getFeature(featureIndex, i);
            }
        }

        revert();
    }
    */

    function synthesizeFeatureID(uint256 featureIndex, uint256 diceRoll) internal view returns(uint256) {

        for (uint256 i = 0; i < featureRarity[featureIndex].length; i++) {

            if (diceRoll <= featureRarity[featureIndex][i]){
                return i;
            }
        }

        revert();
    }

    /*
    function getTokenFeatures(uint256 _tokenId) internal view returns(Feature[] memory) {

        Feature[] memory theseFeatures = new Feature[](featureRarity.length);

        for (uint256 i = 0; i < featureRarity.length; i++) {
            theseFeatures[i] = synthesizeFeature(i, Tools.rollDice(_tokenId, featureCategories[i]));
        }

        return theseFeatures;

    }
    */

    function getTokenFeatureIDs(uint256 _tokenId) internal view returns(uint256[] memory) {

        uint256[] memory theseFeatures = new uint256[](featureRarity.length);

        for (uint256 i = 0; i < featureRarity.length; i++) {
            theseFeatures[i] = synthesizeFeatureID(i, Tools.rollDice(_tokenId, featureCategories[i]));
        }

        return theseFeatures;

    }

    function displayGhosty(uint256[] memory features) internal view returns(string memory){

        string memory background = featureList[0][features[0]].uniqueDisplay;
        string memory openingG = "<g>";

        if (features[1] >= 10){
            background = "222";
        } else if (features[1] == 9){
            background = "f5ffd4";
        }

        if (features[5] == 1){
            openingG = '<g class="f">';
        } else if (features[5] == 2){
            openingG = '<g class="v">';
        }

        string memory svgString = string(abi.encodePacked(
            '<svg style="shape-rendering: crispedges; width: 100%; height: 100%; background: #',
            background,
            '" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><style>g g g rect{width:1px;height:1px}.f{animation: f 6s ease-in-out infinite}.v{animation: v 10s ease-in-out infinite} @keyframes f{0%{transform:translate(0,0)}50%{transform:translate(1px,2px)}100%{transform:translate(0,0)}} @keyframes v{0%{opacity:1}20%{opacity:.05}100%{opacity:1}}</style>',
            openingG
        ));

        for (uint256 i = 1; i < features.length - 1; i++) {
            
            if (i == 1 && features[1] < 11 && features[1] != 9){
                svgString = string(abi.encodePacked(
                    svgString,
                    parseImageData(featureList[i][features[i]].uniqueDisplay),
                    parseImageData(standardBorder)
                ));
            } else {
                svgString = string(abi.encodePacked(
                    svgString,
                    parseImageData(featureList[i][features[i]].uniqueDisplay)
                ));
            }
        }

        svgString = string(abi.encodePacked(
            svgString,
            "</g></svg>"
        ));

        return svgString;

    }

    function parseImageData(string memory imageData) internal pure returns(string memory){

        bytes  memory bits = bytes(imageData);

        if (bits.length == 0) return "";

        string memory svgG;
        string memory svgGG;
        string memory resultingSVGData;
        string memory color;

        bool weHaveG  = false;
        bool weHaveGG = false;

        for (uint256 i = 0; i < bits.length; i++) {

            //#
            if (bits[i] == 0x23){
                
                color = string(abi.encodePacked(bits[i], bits[i + 1], bits[i + 2], bits[i + 3], bits[i + 4], bits[i + 5], bits[i + 6]));

                i = i + 6;

                resultingSVGData = string(
                    abi.encodePacked(
                        resultingSVGData,
                        '<g style="fill:', color, '">'
                    )
                );

            //-
            } else if (bits[i] == 0x2D){
                
                svgG = string(abi.encodePacked(
                    svgG,
                    '<rect x="',
                    bits[i + 1], bits[i + 2],
                    '" y="',
                    bits[i + 3], bits[i + 4],
                    '" width="',
                    bits[i + 5], bits[i + 6],
                    '" height="',
                    bits[i + 7], bits[i + 8],
                    '" />'
                ));

                i = i + 8;

                weHaveG = true;

            } else {

                svgGG = string(abi.encodePacked(
                    svgGG,
                    '<rect x="',
                    bits[i], bits[i + 1],
                    '" y="',
                    bits[i + 2], bits[i + 3],
                    '" />'
                ));

                i = i + 3;

                weHaveGG = true;
            }

            //next char is a new color, store G and GG
            if (i + 1 >= bits.length || bits[i + 1] == '#'){
                if (weHaveGG || weHaveG){

                    if (weHaveGG){

                        weHaveGG = false;

                        resultingSVGData = string(
                            abi.encodePacked(
                                resultingSVGData,
                                '<g>',
                                    svgGG,
                                '</g>'
                            )
                        );
                    }
                    if (weHaveG){

                        weHaveG = false;

                        resultingSVGData = string(
                            abi.encodePacked(
                                resultingSVGData,
                                svgG
                            )
                        );
                    }
                    resultingSVGData = string(
                        abi.encodePacked(
                            resultingSVGData,
                            '</g>'
                        )
                    );

                    svgGG = "";
                    svgG  = "";
                    
                }
            }
        }

        return resultingSVGData;
    }


    

    //public methods

    function mint(uint256 count) public payable {

        uint256 supply = totalSupply();
        require(supply < GHOSTIES, "No mas.");

        require(count <= MAXMINT, "Don't be greedy.");
        require(supply + count <= GHOSTIES, "Minting this many would exceed supply!");

        require(msg.value >= mintPrice * count, "Mas ETH.");

        for (uint256 i = 0; i < count; i++) {
            _safeMint(msg.sender, supply++);
        }
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory){

        require(_exists(_tokenId));

        uint256[] memory features = getTokenFeatureIDs(_tokenId);

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Tools.encode(
                    bytes(
                        string(
                            abi.encodePacked(
                                '{"name": "Ghosty #',
                                Tools.uintToString(_tokenId),
                                '", "description": "Ghosts that never die. A collection of 10,000 fully on-chain ghosts. No IPFS or external assets.", "image": "data:image/svg+xml;base64,', Tools.encode(bytes(displayGhosty(features))),
                                '","attributes":[]',
                                "}"
                            )
                        )
                    )
                )
            )
        );
    }





    function storeFeatures(uint256 featureCategoryId, string[][] calldata features) public onlyOwner {

        for (uint256 i = 0; i < features.length; i++) {
            featureList[featureCategoryId].push(
                Feature(featureCategoryId, i, features[i][0], features[i][1])
            );
        }
    }



    function storeBorder(string calldata standard) public onlyOwner {
        standardBorder = standard;
    }

    function withdraw() public onlyOwner {

        address payable to = payable(msg.sender);
        to.transfer(address(this).balance);
        
    }

    modifier onlyOwner() {
        require(_owner == msg.sender);
        _;
    }

}