// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/interfaces/IAccount.sol";
import "src/core/Helpers.sol";
import "src/interfaces/IEntryPoint.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
contract TestSender is IAccount {
    IEntryPoint public immutable entryPoint;

    address public owner;

    mapping(uint256 => bool) public nonceUsed;

    bool public sigFailed;

    constructor(IEntryPoint _entryPoint) {
        entryPoint = _entryPoint;
    }

    function setOwner(address _owner) external {
        owner = _owner;
    }

    receive() external payable {
    }

    function setStatus(bool _sigFailed) external {
        sigFailed = _sigFailed;
    }

    function getUserOpHash(UserOperation calldata userOp) public view returns(bytes32) {
        return keccak256(
            abi.encodePacked(
                block.chainid,
                address(entryPoint),
                address(this),
                userOp.nonce,
                userOp.initCode,
                userOp.callData,
                userOp.callGasLimit,
                userOp.verificationGasLimit,
                userOp.preVerificationGas,
                userOp.maxFeePerGas,
                userOp.maxPriorityFeePerGas,
                userOp.paymasterAndData
            )
        );
    }
    function validateUserOp(UserOperation calldata userOp, bytes32, uint256 amount)
    external returns (uint256 validationData) {
        bytes32 userOpHash = getUserOpHash(userOp);
        bytes calldata signature = userOp.signature;
        bytes32 r = bytes32(signature[0x120:0x140]);
        bytes32 s = bytes32(signature[0x140:0x160]);
        uint8 v = uint8(signature[0x17f]);
        require(!nonceUsed[userOp.nonce], "nonce used");
        nonceUsed[userOp.nonce] = true;
        bytes32 digest = ECDSA.toEthSignedMessageHash(userOpHash);
        require(ECDSA.recover(digest, v, r, s) == owner, "invalid signature");
        (bool success, bytes memory ret) = msg.sender.call{value: amount}("");
        if(!success) {
            revert(string(ret));
        }
        return _packValidationData(sigFailed, 0, 0);
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