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
        string[] memory colors,
        string[] memory months,
        string[] memory jobs
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
        "WLTC",
        "3,3"
    ];

    string[] private contexts = [
        "gms",
        "Hot JPGEs",
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
        "VeeFriends",
        "Bluechip NFTs",
        "PFPs",
        "Turner",
        "Rug Radio",
        "Ringers",
        "Art Blocks",
        "8 Lines of Text",
        "Meebits",
        "Autoglyphs",
        "Penguins",
        "Doodles",
        "Tungsten Cubes",
        "Runners",
        "$WOOL",
        "Toadz",
        "Kongz"
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
        "Roadmaps",
        "DAOs"
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
        "Discord",
        "DAO"
    ];

    string constant svgStart =
        '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 600 600"> <style>.base{fill: black; font-family: sans-serif; font-weight: 700; letter-spacing: -0.025em;}.fill{font-size: 60px; fill-opacity: 0; animation-name: fill; animation-duration: 0.5s; animation-timing-function: ease-in; animation-fill-mode: forwards;}.outline{font-size: 60px; fill: none; paint-order: stroke; stroke: black; stroke-width: 1.5px; stroke-dasharray: 100%; stroke-dashoffset: 0; animation-name: outline; animation-duration: 2s; animation-timing-function: ease-in; animation-fill-mode: forwards;}.body{font-size: 24px; letter-spacing: -0.02em;}@keyframes outline{from{stroke-dashoffset: 100%;}to{stroke-dashoffset: 0;}}@keyframes fill{from{fill-opacity: 0;}to{fill-opacity: 1;}}</style> <rect width="100%" height="100%" fill="';

    function getSVGStart(string memory color)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(svgStart, color, '"/>'));
    }

    string constant svgEnd =
        '<text x="50" y="516" class="base body">The JPEG</text><text x="50" y="545" class="base body">Megacorp</text><text x="210" y="516" class="base body">Est.</text> <text x="210" y="545" class="base body">2030</text>';

    function getSVGEnd(uint256 tokenId, string[] memory source)
        internal
        pure
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    svgEnd,
                    "<!-- Joined in ",
                    getRandomData(source, "MONTH", tokenId),
                    " ",
                    getJoined(tokenId),
                    " --></svg>"
                )
            );
    }

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
        string memory year = "2011";

        for (int256 i = 0; i < 2030; i = i + 100) {
            if (int256(tokenId) <= i && int256(tokenId) >= i - 100) {
                year = String.toString(
                    uint256(
                        2011 +
                            (i == int256(0) ? int256(0) : (i / int256(100)) - 1)
                    )
                );
            } else if (tokenId > 2000) {
                year = "2030";
            }
        }

        return year;
    }

    function getJSON(
        string memory data,
        string[] memory departmentsSource,
        string memory name,
        string memory title,
        uint256 tokenId,
        Rarity rarity,
        string[] memory colors
    ) private pure returns (string memory) {
        return
            Base64.encode(
                bytes(
                    abi.encodePacked(
                        '{"name": "',
                        name,
                        '", "description": "In 2030, the world has collapsed into a series of decentralized economies and countries governed by DAOs. The JPEG Megacorp has bought all the voting power of every DAO in existence and now controls the entire planet. Their robots and AIs have automated and replaced all the workforce. With a monopoly on jobs and every industry, the only way to survive is to work for them. There are only a few jobs left in the futuristic city of Neo-Miami, but the rivalry is fierce. What will you do?", "image": "data:image/svg+xml;base64,',
                        data,
                        '", "attributes": [{"trait_type": "Department", "value": "',
                        getRandomData(departmentsSource, "DEPARTMENT", tokenId),
                        '"}, {"trait_type": "Title", "value": "',
                        title,
                        '"}, {"trait_type": "Level", "value": "',
                        getLevel(rarity),
                        '"}, {"trait_type": "Badge", "value": "',
                        getRandomData(colors, "COLOR", tokenId),
                        '"}]}'
                    )
                )
            );
    }

    function getDefaultJob(
        Rarity rarity,
        uint256 offset,
        uint256 tokenId,
        string[] memory jobs
    ) internal view returns (Job memory job) {
        return
            Job({
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
                    string(
                        abi.encodePacked("CONTEXT", String.toString(offset))
                    ),
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
                        abi.encodePacked(
                            "ORGANIZATION",
                            String.toString(offset)
                        )
                    ),
                    tokenId
                )
            });
    }

    function getURI(
        Rarity rarity,
        uint256 tokenId,
        uint256 offset,
        string[] memory colors,
        string[] memory months,
        string[] memory jobs
    ) external view override returns (string memory) {
        Job memory job = getDefaultJob(rarity, offset, tokenId, jobs);

        string memory name;

        string memory image;

        if (rarity == Rarity.LEGENDARY) {
            image = string(
                abi.encodePacked(
                    '<text x="50" y="105" class="base outline">',
                    job.title,
                    '</text><text x="50" y="175" class="base fill">',
                    job.context,
                    "</text>"
                )
            );

            name = string(abi.encodePacked(job.title, " ", job.context));
        } else if (rarity == Rarity.EPIC) {
            image = string(
                abi.encodePacked(
                    '<text x="50" y="72" class="base body">',
                    job.title,
                    " ",
                    job.job,
                    '</text><text x="50" y="271" class="base outline">',
                    job.context,
                    '</text><text x="50" y="341" class="base fill">',
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
                    '<text x="50" y="72" class="base body">',
                    job.title,
                    " ",
                    job.job,
                    '</text><text x="50" y="236" class="base fill">',
                    job.context,
                    '</text><text x="50" y="306" class="base fill">',
                    job.market,
                    '</text><text x="50" y="376" class="base outline">',
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
                    '<text x="50" y="72" class="base body">',
                    job.title,
                    " ",
                    job.job,
                    '</text><text x="50" y="201" class="base fill">',
                    job.prefix,
                    '</text><text x="50" y="271" class="base fill">',
                    job.context,
                    '</text><text x="50" y="341" class="base outline">',
                    job.suffix,
                    '</text><text x="50" y="411" class="base outline">',
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

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    getJSON(
                        getEncodedImage(image, tokenId, months, colors),
                        departments,
                        name,
                        getTitle(rarity, job),
                        tokenId,
                        rarity,
                        colors
                    )
                )
            );
    }

    function getTitle(Rarity rarity, Job memory job)
        internal
        pure
        returns (string memory)
    {
        if (rarity == Rarity.LEGENDARY) {
            return job.title;
        } else {
            return string(abi.encodePacked(job.title, " ", job.job));
        }
    }

    function getEncodedImage(
        string memory image,
        uint256 tokenId,
        string[] memory months,
        string[] memory colors
    ) internal pure returns (string memory) {
        return
            Base64.encode(
                bytes(
                    string(
                        abi.encodePacked(
                            getSVGStart(
                                getRandomData(colors, "COLOR", tokenId)
                            ),
                            image,
                            getSVGEnd(tokenId, months)
                        )
                    )
                )
            );
    }
}