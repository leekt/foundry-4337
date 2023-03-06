// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/TestSender.sol";
import "src/core/EntryPoint.sol";

contract TestScript is Script {
    uint256 constant gas = 10000000008;

    TestSender sender;
    EntryPoint entrypoint;
    function setUp() public {
        entrypoint = EntryPoint(payable(0x0576a174D229E3cFA37253523E645A78A0C91B57));
    }

    function run() public {
        uint256 privKey = vm.envUint("PRIVATE_KEY");
        address payable beneficiary = payable(vm.addr(vm.envUint("PRIVATE_KEY")));
        vm.startBroadcast(privKey);
        sender = new TestSender();
        uint256 _length = 5;
        UserOperation[] memory ops = new UserOperation[](_length);

        entrypoint.depositTo{value:1e16*_length}(address(sender));
        address(sender).call{value:10*_length}("");
        for(uint256 i = 0; i < _length; i++) {
            ops[i] = fillUserOp(beneficiary, 1, "");
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
        op.verificationGasLimit = 30000;
        op.preVerificationGas = 50000;
        op.maxFeePerGas = gas;
        op.maxPriorityFeePerGas = gas;
    }
}
