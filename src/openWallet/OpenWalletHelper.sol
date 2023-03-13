pragma solidity ^0.8.0;

import "src/interfaces/UserOperation.sol";

library OpenWalletHelper {
    // small fix to handle userOp hash can be used for attack when offset location is not checked
    // info : https://github.com/eth-infinitism/account-abstraction/issues/237
    function checkUserOpOffset(UserOperation calldata userOp) internal pure returns(bool result) {
        bytes calldata sig = userOp.signature;
        bytes calldata cd = userOp.callData;
        bytes calldata initCode = userOp.initCode;
        bytes calldata paymasterAndData = userOp.paymasterAndData;
        assembly {
            if and(and(gt(sig.offset, cd.offset), gt(sig.offset, initCode.offset)), gt(sig.offset, paymasterAndData.offset)) {
                result := 1
            } 
        }
    }
}
