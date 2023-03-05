// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TestReceiver {
    uint256 public received;
    function mock() external payable {
        received += msg.value;
    }
}
