pragma solidity ^0.8.0;

import "src/mock/MockStakeManager.sol";
import "forge-std/Test.sol";
contract StakeManagerTest is Test {
    MockStakeManager stakeManager;
    address random = address(0xdeadbeef);
    function setUp() external {
        stakeManager = new MockStakeManager();
    }

    function testHalmosStakeManager(uint112 value) public {
        value = uint112(bound(value,  1, type(uint64).max));
        stakeManager.depositTo{value: value}(random);
    }
}
