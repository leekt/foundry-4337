pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "src/core/EntryPoint.sol";

import "src/TestSender.sol";

contract TestEntrypoint is Test {

    EntryPoint entrypoint;

    TestSender sender;

    address payable beneficiary;

    address senderOwner;

    address eoaRecipient;

    address payable bundler;

    function setUp() external {
        entrypoint = new EntryPoint();
        sender = new TestSender();
        beneficiary = mockAddress("beneficiary");
        senderOwner = mockAddress("senderOwner");
        eoaRecipient = mockAddress("EOA");
        bundler = mockAddress("bundler");
    }
    
    function mockAddress(string memory _name) public pure returns(address payable) {
        return payable(vm.addr(uint256(keccak256(abi.encodePacked("TestEntrypoint", _name)))));
    }

    function testHandleOp() external {
        vm.deal(address(sender), 1e18);
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = fillUserOp(eoaRecipient, 1, "");
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

    function testMultipleHandleOp(uint256 _length) external {
        //vm.assume(_length < 100);
        UserOperation[] memory ops = new UserOperation[](_length);

        entrypoint.depositTo{value:1e18*_length}(address(sender));
        vm.deal(address(sender), 1e18 * _length);

        for(uint256 i = 0; i < _length; i++) {
            ops[i] = fillUserOp(eoaRecipient, 1, "");
        }
        entrypoint.handleOps(
            ops,
            beneficiary
        );
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
        op.verificationGasLimit = 80000;
        op.preVerificationGas = 50000;
        op.maxFeePerGas = 50000;
        op.maxPriorityFeePerGas = 50001;
    }
}
