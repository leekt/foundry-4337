// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/interfaces/IAccount.sol";
import "src/core/Helpers.sol";

import "forge-std/console.sol";
contract TestSender is IAccount {

    bool public sigFailed;

    uint48 public validUntil;

    uint48 public validAfter;

    receive() external payable {
    }

    function setStatus(bool _sigFailed, uint48 _validUntil, uint48 _validAfter) external {
        sigFailed = _sigFailed;
        validUntil = _validUntil;
        validAfter = _validAfter;
    }

    function validateUserOp(UserOperation calldata, bytes32, uint256 amount)
    external returns (uint256 validationData) {
        (bool success, bytes memory ret) = msg.sender.call{value: amount}("");
        return _packValidationData(sigFailed, validUntil, validAfter);
    }

    function execute(
        address payable _to,
        uint256 _value,
        bytes calldata _data
    ) external returns(bytes memory){
        (bool s, bytes memory r) = _to.call{value: _value}(_data);
        if(s) {
            return r;
        } else {
            revert(string(r));
        }
    }
}
