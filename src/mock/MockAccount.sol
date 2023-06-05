// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "src/core/BaseAccount.sol";

contract MockAccount is BaseAccount {
    IEntryPoint public immutable entrypoint;

    constructor(IEntryPoint _entrypoint) {
        entrypoint = _entrypoint;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return entrypoint;
    }

    function _validateSignature(UserOperation calldata op, bytes32 hash) internal override returns(uint256){
        // do nothing
        return 0;
    }
}
