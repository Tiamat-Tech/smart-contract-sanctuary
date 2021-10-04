// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract PopGang is ERC1155 {
    struct DLL {
        uint256 next;
        uint256 prev;
        uint256 group;
        uint256 val;
        bool initialized;
    }

    event Increment(uint256 group, uint256 new_count);

    uint256 constant GUARD = 0;
    uint256 public constant popPerToken = 100;
    uint256 public head = GUARD;
    uint256 public tail = GUARD;
    uint256 public length = 0;
    mapping(uint256 => DLL) public data; //group => dll. sorted descendingly from head to tail
    mapping(address => mapping(uint256 => uint256)) public pops; //address => group => pops
    mapping(address => uint256[]) public pop_groups; //address => group[]
    mapping(address => uint256) public last_block;
    address owner;

    constructor() ERC1155("https://pop.thegang.tech/assets/{id}.json") {
        owner = msg.sender;
    }

    function initializeDLL(DLL storage dll, uint256 group) private {
        require(!dll.initialized);
        require(group!=GUARD);
        dll.initialized = true;
        dll.val = 1;
        dll.group = group;
    }

    function getGroupCount(uint256 group) public view returns(uint256){
        require(group != GUARD);
        return data[group].val;
    }

    function inc(uint256 group) public {
        require(group != GUARD, "group 0 is reserved");
        require(block.number > last_block[msg.sender], "Right idea.");

        //update personal pop history
        if (pops[msg.sender][group] == 0) {
            pop_groups[msg.sender].push(group);
        }
        pops[msg.sender][group] += 1;
        
        //give out the reward
        if (pops[msg.sender][group] % popPerToken == 0) {
            _mint(msg.sender, group, 1, "");
        }

        //update last block
        last_block[msg.sender] = block.number;

        //update the dll
        uint newVal = updateDll(group);
        emit Increment(group, newVal);
    }

    function updateDll(uint256 group) private returns (uint256) {
        require(group != GUARD);
        //update group pops history
        DLL storage dll = data[group];
        if (isEmpty()) {
            // first setup
            // set the initial value
            // set head & tail
            // set length
            initializeDLL(dll, group);
            dll.next = GUARD;
            dll.prev = GUARD;
            head = group;
            tail = group;
            length = 1;
        } else {
            dll.val += 1;
            if (dll.initialized) {
                // if found and initialized
                if (head == group) {
                    // if head
                    // do nothing no move needed
                } else {
                    // non head
                    //percolate to find a new place
                    DLL storage old_prev = data[dll.prev];
                    DLL storage current_node = old_prev;

                    //optimize two case
                    //not moving
                    //winning against head
                    DLL storage head_node = data[head];
                    if (current_node.val >= dll.val) {
                        // not moving
                        //nothing needs to be done
                    } else if (dll.val > head_node.val) {
                        // winning against head
                        // if it's a tail update the tail
                        if (group == tail) {
                            // it's not both head and tail
                            // thus prev is non GUARD
                            tail = dll.prev;
                        }
                        //remove from dll
                        old_prev.next = dll.next;
                        //put it in front
                        head = group;
                        head_node.prev = group;
                        dll.prev = GUARD;
                        dll.next = head_node.group;
                    } else {
                        //need to move but not head replacement
                        bool should_quit = false;
                        // if it's a tail update the tail
                        if (group == tail) {
                            // it's not both head and tail
                            // thus prev is non GUARD
                            tail = dll.prev;
                        }
                        //remove from dll
                        old_prev.next = dll.next;
                        //might be able to save a few operations here
                        //by skipping dll.prev
                        while (!should_quit) {
                            if (current_node.val >= dll.val) {
                                //the equal is important
                                //found the place
                                uint256 prev_next = current_node.next;
                                //current_node.next is guarantee to not be dll
                                //not moving case is taken care of.
                                DLL storage prev_next_node = data[prev_next];
                                //insert it in the middle
                                current_node.next = group;
                                dll.next = prev_next;
                                dll.prev = current_node.group;
                                prev_next_node.prev = group;
                                should_quit = true;
                            } else {
                                //here we don't need to check if we reach head.
                                //because of we aren't winning against head
                                current_node = data[current_node.prev];
                            }
                        }
                    }
                }
            } else {
                //not found
                // new one initialize and add to tail
                // update length
                initializeDLL(dll, group);
                DLL storage old_tail = data[tail];
                dll.prev = tail;
                old_tail.next = group;
                tail = group;
                length += 1;
            }
        }
        return dll.val;
    }

    function isEmpty() public view returns (bool) {
        return head == GUARD && tail == GUARD;
    }

    function getTopK(uint256 k)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        require(k > 0, "k must be positive");
        uint256 ret_length = k > length ? length : k;
        uint256[] memory groups = new uint256[](ret_length);
        uint256[] memory counts = new uint256[](ret_length);
        uint256 current = head;
        for (uint256 i = 0; i < ret_length && current != GUARD; i++) {
            DLL storage current_node = data[current];
            groups[i] = current_node.group;
            counts[i] = current_node.val;
            current = current_node.next;
        }
        return (groups, counts);
    }
}