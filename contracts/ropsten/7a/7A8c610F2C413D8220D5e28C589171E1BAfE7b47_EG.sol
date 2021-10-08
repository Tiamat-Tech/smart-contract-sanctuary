pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EG is ERC721 {
    uint256 constant SALE_PRICE = 100000000000000000; // 0.1 ether

    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("EG", "EG") {}

    mapping(uint256 => bytes32) public _seeds;
    mapping(uint256 => bytes32[]) private _transferSeeds;

    function referenceImplementation(uint256 tokenId) view public returns (string memory code_) {
        require(_exists(tokenId), "ERC721: owner query for nonexistent token");

        string memory transferSeedsString = "[";

        for (uint i = 0; i < _transferSeeds[tokenId].length; i++) {
            transferSeedsString = string(abi.encodePacked(
                    transferSeedsString,
                    "'",
                    bytes32ToString(_transferSeeds[tokenId][i]),
                    "'",
                    ","
                ));
        }

        transferSeedsString = string(abi.encodePacked(
                transferSeedsString,
                "]"
            ));

        string memory seed = bytes32ToString(_seeds[tokenId]);


        return string(abi.encodePacked(
                "const seed = '",
                seed,
                "';\nconst transferSeeds = ",
                transferSeedsString,
                "\nnew p5();\n\nconst seedI = parseInt(seed.slice(0, 10))\n\nrandomSeed(seedI)\nnoiseSeed(seedI)\nconst numOfNodes = round(randomGaussian(6, 2))\n\nlet linePallette = [];\nlet backgroundColor;\nlet colors = [];\nlet nodes = [];\nlet nodeXOff = [];\nlet nodeYOff = [];\nlet transferIs = [];\n\nfor (let i = 0; i < transferSeeds.length; i++) {\n    transferIs[i] = parseInt(transferSeeds[i].slice(0, 10))\n}\n\nfunction setup() {\n    const bounds = min(window.innerWidth, window.innerHeight)\n\n    createCanvas(bounds, bounds);\n\n    backgroundPallette = [\n        color(87, 86, 87),\n        color(1, 31, 38),\n        color(60, 54, 75),\n        color(68, 74, 70),\n        color(104, 27, 73)\n    ]\n\n\n    linePallette = [\n        color(238, 150, 121),\n        color(66, 110, 117),\n        color(204, 102, 0),\n        color(0, 102, 153),\n        color(242, 73, 87),\n        color(25, 115, 106),\n        color(242, 226, 5),\n        color(217, 204, 30),\n        color(237, 180, 164),\n        color(192, 59, 55),\n        color(191, 216, 206),\n        color(223, 215, 199),\n        color(60, 94, 136),\n    ]\n\n    backgroundColor = random(backgroundPallette)\n    nodes = []\n    for (let i = 0; i < numOfNodes; i++) {\n        nodes[i] = []\n        colors[i] = random(linePallette)\n        nodeXOff[i] = 0.001\n        nodeYOff[i] = 0.001\n    }\n\n    for (let i = 0; i < transferSeeds.length; i++ ) {\n        const ti = transferIs[i]\n        addEdge(ti)\n    }\n}\n\nfunction addEdge(txnSeed) {\n    let node = floor(map(random(txnSeed), 0, txnSeed, 0, nodes.length))\n    let toNode = node;\n\n    while(toNode === node) {\n        toNode = floor(random(nodes.length));\n    }\n\n    nodes[node].push(toNode)\n}\n\n\nfunction draw() {\n    const r1 = 1\n    const interval = 2 * PI / nodes.length;\n    const cx = width / 2;\n    const cy = height / 2;\n    const vl = cx - (2 * r1) - 100;\n    const positions = []\n    for (let i = 0; i < nodes.length; i++) {\n        const nc = rotateCoordinate(vl, 0, i * interval);\n        positions[i] = {x: cx + nc[0], y: cy + nc[1]}\n    }\n\n    background(backgroundColor);\n\n    for (var i = 0; i < nodes.length; i++) {\n        let node = nodes[i];\n\n        stroke(colors[i]);\n        fill(colors[i]);\n\n        for (let j = 0; j < node.length; j++) {\n            const oNode = node[j];\n\n            const x = positions[i].x;\n            const y = positions[i].y;\n            const ox = positions[oNode].x;\n            const oy = positions[oNode].y;\n\n            strokeWeight(1.5);\n            noFill();\n\n            beginShape();\n\n            curveVertex(x, y);\n\n            let prevX = x;\n            let prevY = y;\n\n            const numOfPoints = 100;\n            for (let k = 1; k < numOfPoints; k++) {\n                let intensity = map(numOfPoints / 2 - abs(numOfPoints / 2 - k), 0, numOfPoints / 2, 1, node.length * 10)\n                let newX = lerp(x, ox, k / numOfPoints)\n                let newY = lerp(y, oy, k / numOfPoints)\n                let dx = ox - x;\n                let dy = oy - y;\n                let angle = atan2(dy, dx)\n\n                let xFactor = sin(angle)\n                let yFactor = cos(angle)\n\n                let noiseX = noise(newY * nodeYOff[i], nodeYOff[i]);\n                let noiseY = noise(newX * nodeXOff[i], nodeXOff[i]);\n                let xnoiseScale = map(noiseX, 0, 1, -intensity, intensity)\n                let ynoiseScale = map(noiseY, 0, 1, -intensity, intensity)\n\n                curveVertex(newX + (xnoiseScale * xFactor), newY + (ynoiseScale * yFactor));\n                prevX = newX;\n                prevY = newY;\n            }\n\n            curveVertex(ox, oy);\n            nodeXOff[i] += 0.00001;\n            nodeYOff[i] += 0.00001;\n            endShape();\n        }\n    }\n\n}\n\nfunction rotateCoordinate(x, y, angle) {\n    const rc = [0, 0];\n    rc[0] = (int)(x * cos(angle) - y * sin(angle));\n    rc[1] = (int)(x * sin(angle) + y * cos(angle));\n    return rc;\n}\n"
            ));
    }

    function p5jsMinSha256() pure public returns (string memory code_) {
        return "10cd93ab7811ce2c8cca0666ae3e205bab8c7128f9b7acfe0ded3e78d4b27d63";
    }

    function mint() public payable returns (uint256) {
        require(msg.value == SALE_PRICE, "Must pay 0.1 eth to mint");
        require(_tokenIds.current() < 512, "Max supply is 512");

        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();

        _mint(msg.sender, newTokenId);

        bytes32 seed = _genSeed();
        _seeds[newTokenId] = seed;
        _transferSeeds[newTokenId] = [seed];

        return newTokenId;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) override internal virtual {
        super._transfer(from, to, tokenId);
        _transferSeeds[tokenId].push(_genSeed());
    }

    function _genSeed() internal view returns (bytes32 _seed) {
        return keccak256(abi.encodePacked(
                block.number,
                blockhash(block.number - 1),
                msg.sender
            ));
    }

    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint ival = uint(_bytes32);
        string memory key = ival.toHexString();
        return key;
    }
}