// SPDX-License-Identifier: MIT
/*
* ##  ###  ###  ##   ## ##    ## ##    ## ##   ####               ## ##     ##     #### ##   ## ##   
* ##   ##    ## ##  ##   ##  ##   ##  ##   ##   ##               ##   ##     ##    # ## ##  ##   ##  
* ##   ##   # ## #  ##       ##   ##  ##   ##   ##               ##        ## ##     ##     ####     
* ##   ##   ## ##   ##       ##   ##  ##   ##   ##               ##        ##  ##    ##      #####   
* ##   ##   ##  ##  ##       ##   ##  ##   ##   ##               ##        ## ###    ##         ###  
* ##   ##   ##  ##  ##   ##  ##   ##  ##   ##   ##  ##           ##   ##   ##  ##    ##     ##   ##  
*  ## ##   ###  ##   ## ##    ## ##    ## ##   ### ###            ## ##   ###  ##   ####     ## ##   
*                                                                                                    
*                                    :=*%%%*:                                               
*                                  :#%%%%%%%%:                                              
*                                  *%%%%%%#%%#                                              
*                                   *%%%-==%%%                                              
*                         .::.       *%%+=-%%%.                .-=+*+=-.                    
*                     =*%%%%%%%#*=. :+%%%=-%%%+             :+#%%%#*#%%%*-                  
*                    #%%#=:::-+*%%%#%%%+:::-*%%%+:         +%%%*-.....:*%%%-                
*                  .#%%-........:+%%%*:--::=-:=#%%%+-     +%%*:.........=%%%*               
*                 .%%#:..........:%%+:::::::==::=+#%%-  :#%%-............-#%%#:             
*                 #%%=...........+%#:::::::::%-:::-%%+ :%%%=...............*%%%.            
*                -%%%:...........%%=:::::::::++::::%%%%%%%#................:#%%=            
*                #%%%...........:%%-:::-+::::-%-:::#%%%%%#:.................:#%%            
*               .%%%+...........:%%=:::-%-::::-+:::::*%%%:...................:%%*           
*               .%%%=........-=*#%%-:::=%#=::::=-::::%%%=.....................+%%:          
*               -%%%-...:-+*%%%%%*=::::=%%#+:::::::::%%%+=:...................:%%*          
*               -%%%-.=#%%#*+=-:::::::-#%%%%#+-::::-:-+*#%%%*+=-:..............#%%.         
*                *#*::%%%---::::::::=#%%##%%%%%+:::::::--::=*%%%%*-............-+=          
*                 ...:%%%:-::::::-+%%%%+:.-+#%%%#*+-::::-:=+-:-+#%%:.............           
*               .-=-.:%%%:::-=+*#%#+=:..=#=.=+++**#%%%#**++==++=:*%+............-#%*.       
*              :%%%#.:%%%:-*%%%#+-......*=%::*%*:...:=+**#%%%*==##%%............:%%%*       
*             .%%%#:.:%%%*%%#=:........:*+#...*#-.........:+%%%#+#%#.............+%%%       
*             +%%+...:%%%%*-............:-...................-+#%%%=.............-%%%:      
*             %%#.....:-:.......................................=#*..............:%%%-      
*            -%%-.....=***=...........................-*%%%*:.....................%%%-      
*      .###**#%%:....*%#+#%*.........................+%%+-=%%=........:-======-..:%%%-      
*       -==++#%%:...-%%.  %%-........................#%=   =%%-......:%%%%%%%#+..-%%%:      
*            -%%-...=%%   +%+........................%%-   =%%=.......::::.......+%%%       
*       =**##%%%#:..-%%.  #%=........................*%*.  +%%:.......=***+===:.-%%%+       
*       +*+=--+%%*...*%%+#%#.........................-%%%**%%-........:++*#%%%%:%%%#        
*             :%%%+..:*%%%#-..........................:+*%%+:...............::.=%%%.        
*              =%%%+....::....................................................:%%%:         
*               :#%%#-...............::::::::...............................-+%%+.          
*                 =%%%=........:=+#%%%%%%%%%%%%*+-........................-*%%%=            
*                  .*%%#=......=%%#**+++++++++*%%%%-....................-#%%%#:             
*                    :*%%%*-....::..............=**-................:=+#%%*=.               
*                      .=#%%%*-:................................:-+%%%%%+                   
*                         :*%%%%#+-.......................::=+*#%%%%#+:                     
*                           .:=+#%%%#****+++++++++****###%%%%##*+=:                         
*                                 :=+**#%%%%%%%%%%%##**+=--.                                
* 
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract UncoolCats is ERC721, ERC721Enumerable, Ownable {
    bool public saleIsActive = false;
    string private _baseURIextended;

    bool public isAllowListActive = false;
    uint256 public constant MAX_SUPPLY = 6969;
    uint256 public constant MAX_PUBLIC_MINT = 5;
    uint256 public constant PRICE_PER_TOKEN = 0.042 ether;

    mapping(address => uint8) private _allowList;

    // team withdraw address
    address teamAddress = 0x4e36b078BC8c75A52cfFAf60885c903AfB800892;

    constructor() ERC721("Uncool Cats", "UNCOOL") {

        // preallocated 5 cats for team, giveaways
        _safeMint( teamAddress, 0);
        _safeMint( teamAddress, 1);
        _safeMint( teamAddress, 2);
        _safeMint( teamAddress, 3);
        _safeMint( teamAddress, 4);
    }

    function setIsAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    function setAllowList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            _allowList[addresses[i]] = numAllowedToMint;
        }
    }

    function numAvailableToMint(address addr) external view returns (uint8) {
        return _allowList[addr];
    }

    // whitelist mint
    function mintAllowList(uint8 numberOfTokens) external payable {
        uint256 ts = totalSupply();
        require(isAllowListActive, "Allow list is not active");
        require(numberOfTokens <= _allowList[msg.sender], "Exceeded max available to purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");

        _allowList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }

    // public mint
    function mint(uint numberOfTokens) public payable {
        uint256 ts = totalSupply();
        require(saleIsActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}