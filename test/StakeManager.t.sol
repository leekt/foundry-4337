pragma solidity ^0.8.0;

import "src/mock/MockStakeManager.sol";
import "forge-std/Test.sol";
contract StakeManagerTest is Test {
    MockStakeManager stakeManager;
    address random = address(0xdeadbeef);
    function setUp() external {
        stakeManager = new MockStakeManager();
    }

    function testHalmosDeposit(uint112 value) public {
        uint256 balance = stakeManager.balanceOf(random);
        value = uint112(bound(value,  1, type(uint64).max));
        stakeManager.depositTo{value: value}(random);
        assertEq(stakeManager.balanceOf(random), balance + value);
    }
}
