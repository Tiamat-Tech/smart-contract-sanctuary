// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./libraries/Base64.sol";
import "./libraries/String.sol";

interface IConglomerateBuilder {
    function getURI(
        Rarity rarity,
        uint256 tokenId,
        uint256 offset,
        string[] memory colors
    ) external view returns (string memory);
}

enum Rarity {
    COMMON,
    RARE,
    EPIC,
    LEGENDARY
}

struct Job {
    string title;
    string job;
    string prefix;
    string market;
    string context;
    string suffix;
    string org;
}

contract ConglomerateBuilder is Ownable, IConglomerateBuilder {
    string[] private executiveTitles = [
        "CEO",
        "President",
        "Vice President",
        "Chairman",
        "Director",
        "Viceroy",
        "SVP",
        "Authority on",
        "Master of",
        "Technoking"
    ];

    string[] private professionalTitles = [
        "Senior",
        "Chief",
        "Associate",
        "Lead",
        "Junior",
        "District",
        "Resident"
    ];

    string[] private managerTitles = [
        "Executive",
        "Assistant",
        "Regional",
        "Head",
        "Veteran",
        "Worldwide"
    ];

    string[] private departments = [
        "R&D",
        "Operations",
        "Memes",
        "Finance",
        "Sales",
        "Engineering",
        "Production",
        "Management"
    ];

    string[] private prefixes = [
        "Tokenized",
        "Limited",
        "Pixelated",
        "Onchain",
        "Generative",
        "Solar Powered",
        "Looks Rare",
        "Edition of 1",
        "Complimentary",
        "Low Floor",
        "SEC Endorsed",
        "Sub 1 ETH",
        "Clean",
        "Degen",
        "Bootleg",
        "Rugged",
        "IRL",
        "WAGMI",
        "NGMI",
        "WLTC"
    ];

    string[] private contexts = [
        "GM Posts",
        "Hot JPGs",
        "Shiba Inu",
        "Shitposts",
        "Punks",
        "Winklevoss Twins",
        "NFT",
        "Viper Glasses",
        "Divine Robes",
        "Cool Cats",
        "Fidenza",
        "Loot Bags",
        "GaryVee",
        "Bluechip NFTs",
        "PFPs",
        "Turner",
        "Rug Radio",
        "Ringers",
        "Art Blocks",
        "8 Lines of Text",
        "Meebits",
        "Autoglyphs",
        "Penguins"
    ];

    string[] private markets = [
        "Memes",
        "Hoodies",
        "Tweets",
        "M&A",
        "Derivatives",
        "Commodities",
        "Attributes",
        "MoMA Items",
        "Futures",
        "Mutations",
        "Bots",
        "Mints",
        "Collabs",
        "Giveaways",
        "Drops",
        "Paid Groups",
        "Ideas",
        "Contracts",
        "Whitepapers",
        "Lightpapers",
        "Roadmaps"
    ];

    string[] private suffixes = [
        "Innovation",
        "Intelligence",
        "Strategy",
        "Talent",
        "Rarity Assurance",
        "Market",
        "Utility",
        "Oversight",
        "Automation",
        "Inspiration"
    ];

    string[] private jobs = [
        "Specialist",
        "Inspector",
        "Tester",
        "Insider",
        "Engineer",
        "Representative",
        "Technician",
        "Broker",
        "Advisor",
        "Supervisor",
        "Counselor",
        "Trendwatcher",
        "Negotiator",
        "Breeder",
        "Minter",
        "Flipper",
        "Visionary",
        "Facilitator",
        "Farmer",
        "Auctioneer",
        "Clerk",
        "Professional",
        "Ghostwriter",
        "Critic",
        "Officer",
        "Consultant",
        "Expert",
        "Coordinator",
        "Strategist",
        "Researcher",
        "Recruiter",
        "Ambassador",
        "Spellchecker",
        "Evaluator",
        "Analyst",
        "Assessor",
        "Instructor",
        "Scientist",
        "Attache",
        "Creator",
        "Designer",
        "Agent",
        "Paralegal",
        "Manipulator",
        "Solutionist",
        "Trader",
        "Hackerman",
        "Observer",
        "Board member",
        "Adventurer",
        "CT Influencer",
        "Hedger",
        "Floorer",
        "Accumulator",
        "Predictor",
        "Compounder",
        "Educator",
        "Enjoyer",
        "Believer",
        "GMer",
        "Airdropper"
    ];

    string[] private orgs = [
        "Society",
        "Guild",
        "Chamber",
        "Yacht Club",
        "Task Force",
        "Testing Facility",
        "Fund",
        "Lab",
        "Office",
        "Commission",
        "Committee",
        "Union",
        "Council",
        "Panel",
        "Services",
        "Board",
        "Discord"
    ];

    string constant svgStart =
        '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 600 600"> <style>.base{fill: black; font-family: sans-serif; font-weight: 700; letter-spacing: -0.02em;}.fill{font-size: 64px; fill-opacity: 0; animation-name: fill; animation-duration: 0.5s; animation-timing-function: ease-in; animation-fill-mode: forwards; animation-delay: 1s;}.outline{font-size: 64px; fill: none; paint-order: stroke; stroke: black; stroke-width: 2px; stroke-dasharray: 100%; stroke-dashoffset: 0; animation-name: outline; animation-duration: 2.5s; animation-timing-function: ease-in; animation-fill-mode: forwards;}.body{font-size: 24px;}@keyframes outline{from{stroke-dashoffset: 100%;}to{stroke-dashoffset: 0;}}@keyframes fill{from{fill-opacity: 0;}to{fill-opacity: 1;}}</style> <rect width="100%" height="100%" fill="';

    function getSVGStart(string memory color)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(svgStart, color, '"/>'));
    }

    string constant svgEnd =
        '<text x="50" y="521" class="base body">The JPEG</text> <text x="50" y="550" class="base body">Conglomerate</text> <text x="256" y="521" class="base body">Est.</text> <text x="256" y="550" class="base body">2030</text></svg>';

    function random(string memory phrase, uint256 tokenId)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(phrase, tokenId)));
    }

    function getRandomData(
        string[] memory data,
        string memory seed,
        uint256 tokenId
    ) public pure returns (string memory) {
        return data[random(seed, tokenId) % data.length];
    }

    function getSuffixOrOrg(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        if (random("SUFFIX_ORG_", tokenId) % 100 < 50) {
            return getRandomData(suffixes, "SUFFIX", tokenId);
        } else {
            return getRandomData(orgs, "ORGANIZATION", tokenId);
        }
    }

    function getLevel(Rarity rarity) private pure returns (string memory) {
        if (rarity == Rarity.LEGENDARY) {
            return "Executive";
        } else if (rarity == Rarity.EPIC) {
            return "Manager";
        } else {
            return "Professional";
        }
    }

    function getJoined(uint256 tokenId) private pure returns (string memory) {
        uint256 year = random("JOINED_", tokenId) % 5;

        return String.toString(2017 + year);
    }

    function getJSON(
        string memory data,
        string[] memory departmentsSource,
        string memory name,
        string memory title,
        uint256 tokenId,
        Rarity rarity,
        string memory color
    ) private pure returns (string memory) {
        return
            Base64.encode(
                bytes(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "Welcome to The JPEG Conglomerate! We are excited for you to be joining our company! Show this employee card every time you come to work.", "image": "data:image/svg+xml;base64,',
                        data,
                        '", "attributes": [{"trait_type": "Joined", "value": "',
                        getJoined(tokenId),
                        '"}, {"trait_type": "Department", "value": "',
                        getRandomData(departmentsSource, "DEPARTMENT", tokenId),
                        '"}, {"trait_type": "Title", "value": "',
                        title,
                        '"}, {"trait_type": "Level", "value": "',
                        getLevel(rarity),
                        '"}, {"trait_type": "Badge", "value": "',
                        color,
                        '"}]}'
                    )
                )
            );
    }

    function getURI(
        Rarity rarity,
        uint256 tokenId,
        uint256 offset,
        string[] memory colors
    ) external view override returns (string memory) {
        Job memory job = Job({
            title: getRandomData(
                rarity == Rarity.LEGENDARY
                    ? executiveTitles
                    : rarity == Rarity.EPIC
                    ? managerTitles
                    : professionalTitles,
                string(abi.encodePacked("TITLE", String.toString(offset))),
                tokenId
            ),
            job: getRandomData(
                jobs,
                string(abi.encodePacked("JOB", String.toString(offset))),
                tokenId
            ),
            prefix: getRandomData(
                prefixes,
                string(abi.encodePacked("PREFIX", String.toString(offset))),
                tokenId
            ),
            market: getRandomData(
                markets,
                string(abi.encodePacked("MARKET", String.toString(offset))),
                tokenId
            ),
            context: getRandomData(
                contexts,
                string(abi.encodePacked("CONTEXT", String.toString(offset))),
                tokenId
            ),
            suffix: getRandomData(
                suffixes,
                string(abi.encodePacked("SUFFIX", String.toString(offset))),
                tokenId
            ),
            org: getRandomData(
                orgs,
                string(
                    abi.encodePacked("ORGANIZATION", String.toString(offset))
                ),
                tokenId
            )
        });

        string memory name;

        string memory image;

        if (rarity == Rarity.LEGENDARY) {
            image = string(
                abi.encodePacked(
                    '<text x="50" y="126" class="base outline">',
                    job.title,
                    '</text><text x="50" y="202" class="base fill">',
                    job.context,
                    "</text>"
                )
            );

            name = string(abi.encodePacked(job.title, " ", job.context));
        } else if (rarity == Rarity.EPIC) {
            image = string(
                abi.encodePacked(
                    string(
                        abi.encodePacked(
                            '<text x="50" y="79" class="base body">',
                            job.title,
                            " ",
                            job.job,
                            "</text>"
                        )
                    ),
                    '<text x="50" y="286" class="base outline">',
                    job.context,
                    '</text><text x="50" y="361" class="base fill">',
                    job.suffix,
                    "</text>"
                )
            );

            name = string(
                abi.encodePacked(
                    job.title,
                    " ",
                    job.job,
                    " ",
                    job.context,
                    " ",
                    job.suffix
                )
            );
        } else if (rarity == Rarity.RARE) {
            string memory sufOrOrg = getSuffixOrOrg(tokenId);

            image = string(
                abi.encodePacked(
                    string(
                        abi.encodePacked(
                            '<text x="50" y="79" class="base body">',
                            job.title,
                            " ",
                            job.job,
                            "</text>"
                        )
                    ),
                    '<text x="50" y="247" class="base fill">',
                    job.context,
                    '</text><text x="50" y="323" class="base fill">',
                    job.market,
                    '</text><text x="50" y="399" class="base outline">',
                    sufOrOrg,
                    "</text>"
                )
            );

            name = string(
                abi.encodePacked(
                    job.title,
                    " ",
                    job.job,
                    " ",
                    job.context,
                    " ",
                    job.market,
                    " ",
                    sufOrOrg
                )
            );
        } else {
            image = string(
                abi.encodePacked(
                    string(
                        abi.encodePacked(
                            '<text x="50" y="79" class="base body">',
                            job.title,
                            " ",
                            job.job,
                            "</text>"
                        )
                    ),
                    '<text x="50" y="209" class="base fill">',
                    job.prefix,
                    '</text><text x="50" y="285" class="base fill">',
                    job.context,
                    '</text><text x="50" y="361" class="base outline">',
                    job.suffix,
                    '</text><text x="50" y="437" class="base outline">',
                    job.org,
                    "</text>"
                )
            );

            name = string(
                abi.encodePacked(
                    job.title,
                    " ",
                    job.job,
                    " ",
                    job.prefix,
                    " ",
                    job.context,
                    " ",
                    job.suffix,
                    " ",
                    job.org
                )
            );
        }

        string memory badge = getRandomData(colors, "COLOR", tokenId);

        string memory uri = string(
            abi.encodePacked(
                "data:application/json;base64,",
                getJSON(
                    getEncodedImage(badge, image),
                    departments,
                    name,
                    rarity == Rarity.LEGENDARY
                        ? job.title
                        : string(abi.encodePacked(job.title, " ", job.job)),
                    tokenId,
                    rarity,
                    badge
                )
            )
        );

        return uri;
    }

    function getEncodedImage(string memory badge, string memory image)
        internal
        pure
        returns (string memory)
    {
        return
            Base64.encode(
                bytes(
                    string(abi.encodePacked(getSVGStart(badge), image, svgEnd))
                )
            );
    }
}