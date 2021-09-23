// Specifies the version of Solidity, using semantic versioning.
// Learn more: https://solidity.readthedocs.io/en/v0.5.10/layout-of-source-files.html#pragma
pragma solidity ^0.6.7;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";

// Defines a contract named `HelloWorld`.
// A contract is a collection of functions and data (its state). Once deployed, a contract resides at a specific address on the Ethereum blockchain. Learn more: https://solidity.readthedocs.io/en/v0.5.10/structure-of-a-contract.html
contract EarthquakeInsurance is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    mapping(bytes32 => uint256) public counts;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    constructor() public {
        setPublicChainlinkToken();
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
    }

    function uintToString(uint v) pure public returns (string memory str) {
        uint maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = byte(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i + 1);
        for (uint j = 0; j <= i; j++) {
            s[j] = reversed[i - j];
        }
        str = string(s);
    }

        /**
     * Create a Chainlink request to retrieve API response, find the target
     * data.
     */
    function requestNumRecentEarthquakesInArea(string memory latitude, string memory longitude, string memory maxRadiusKm, string memory minMagnitude, uint256 contractLengthDays) public returns (bytes32 requestId)
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        assert (contractLengthDays <= 400);
        uint256 startTime = now - (contractLengthDays * 10 * 86400);
        string memory startTimeStr = uintToString(startTime);

        string memory url = string(abi.encodePacked("https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&starttime=", startTimeStr, "&latitude=", latitude, "&longitude=", longitude, "&maxradiuskm=", maxRadiusKm, "&minmagnitude=", minMagnitude));

        // Set the URL to perform the GET request on
        request.add("get", url);

        // Set the path to find the desired data in the API response, where the response format is:
        // {"metadata":
        //   {"count": xxx}
        //  }
        request.add("path", "metadata.count");

        // Sends the request
        return sendChainlinkRequestTo(oracle, request, fee);
    }

    event GotCount(bytes32 _requestId, uint256 _count);

    /**
     * Receive the response in the form of uint256
     */
    function fulfill(bytes32 _requestId, uint256 _count) public recordChainlinkFulfillment(_requestId)
    {
        counts[_requestId] = _count;
        emit GotCount(_requestId, _count);
    }

}