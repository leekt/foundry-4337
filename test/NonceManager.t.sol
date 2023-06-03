pragma solidity ^0.8.12;

import "src/core/NonceManager.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

contract NonceManagerTest is Test {
    NonceManager nonceManager;

    function setUp() external {
        nonceManager = new NonceManager();
    }

    function testHalmosNonce(uint192 key) external {
        uint256 nonce = nonceManager.getNonce(address(this), key);
        uint256 startAt = nonce;
        nonceManager.incrementNonce(key);
        nonce = nonceManager.getNonce(address(this), key);
        assertEq(nonce, startAt + 1);
        nonceManager.incrementNonce(key);
        nonce = nonceManager.getNonce(address(this), key);
        assertEq(nonce, startAt + 2);
    }

    function testNonceGasUsage() external {
        uint192 key = 1;
        uint256 nonce = nonceManager.getNonce(address(this), key);
        bytes memory data = abi.encodeWithSelector(nonceManager.incrementNonce.selector, key);
        nonceManager.incrementNonce(key);
        uint256 gasUsed = gasleft();
        unchecked {
            for(uint256 i = 0; i < 1000; i++) {
                nonceManager.incrementNonce(key);
            }
        }
        gasUsed = gasUsed - gasleft();
        console.log("Gas used: ", gasUsed);
    }
}
