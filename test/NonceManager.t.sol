pragma solidity ^0.8.12;

import "src/core/NonceManager.sol";
import "forge-std/Test.sol";

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

    function testNonce() external {
        uint192 key = 27584976186092338320989424935973191168167347064672362496;
        uint256 nonce = nonceManager.getNonce(address(this), key);
        uint256 startAt = nonce;
        nonceManager.incrementNonce(key);
        nonce = nonceManager.getNonce(address(this), key);
        assertEq(nonce, startAt + 1);
        nonceManager.incrementNonce(key);
        nonce = nonceManager.getNonce(address(this), key);
        assertEq(nonce, startAt + 2);
    }
}
