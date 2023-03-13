pragma solidity ^0.8.0;

import "src/interfaces/IAccount.sol";
import "src/core/Helpers.sol";
import "src/interfaces/IEntryPoint.sol";
import "./OpenWalletHelper.sol";
import "src/core/Helpers.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";

struct AggregatorValidationData {
    uint48 validAfter;
    uint48 validUntil;
    uint64 nonceFrom;
    uint64 nonceTo;
}

struct WalletStorage {
    address owner;
    uint256 nonce;
    mapping(address => AggregatorValidationData) aggregatorValidationData;
}

enum CallType {
    Call,
    DelegateCall
}

contract AggregatedWallet is IAccount, EIP712 {
    error NotEntrypoint();
    error InvalidCallType();
    IEntryPoint public immutable entryPoint;
    constructor(IEntryPoint _entryPoint) EIP712("AggregatedWallet", "0.0.1") {
        entryPoint = _entryPoint;
    }

    modifier onlyEntrypoint() {
        if(msg.sender != address(entryPoint)) {
            revert NotEntrypoint();
        }
        _;
    }

    function getWalletStorage() internal pure returns(WalletStorage storage s) {
        bytes32 position = bytes32(uint256(keccak256("wallet.storage")) - 1);
        assembly {
            s.slot := position
        }
    }

    function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds) external onlyEntrypoint override returns (uint256 validationData) {
         // minimal check for signature offset validation. But this will not be enough for userOps that has more data than standard ones
        OpenWalletHelper.checkUserOpOffset(userOp);
        if(getWalletStorage().nonce++ != userOp.nonce ) { // nonce is incremented before validation
            return _packValidationData(true, 0, 0);
        }
        if(userOp.signature.length == 77) {  // 6 bytes for validUntil and validAfter, 65 bytes for signature
            uint48 validUntil = uint48(bytes6(userOp.signature[0:6]));
            uint48 validAfter = uint48(bytes6(userOp.signature[6:12]));
            bytes calldata sig = userOp.signature[12:77];
            address signer = ECDSA.recover(userOpHash, sig); // userOpHash already includes entrypoint and chain.id in it
            if(signer != getWalletStorage().owner) {
                validationData = _packValidationData(true, validUntil, validAfter);
            } else {
                validationData = _packValidationData(false, validUntil, validAfter);
            }
        } else {
            address aggregator = address(bytes20(userOp.signature[0:20]));
            uint48 validUntil = uint48(bytes6(userOp.signature[20:26]));
            uint48 validAfter = uint48(bytes6(userOp.signature[26:32]));
            uint64 nonceFrom = uint64(bytes8(userOp.signature[32:40]));
            uint64 nonceTo = uint64(bytes8(userOp.signature[40:48]));
            bytes calldata sig = userOp.signature[48:113];
            AggregatorValidationData storage aggregatorValidationData = getWalletStorage().aggregatorValidationData[aggregator];
            if(aggregatorValidationData.nonceFrom <= userOp.nonce && aggregatorValidationData.nonceTo > userOp.nonce) {
                //aggregator already verified for this nonce
                return _packValidationData(ValidationData({
                    aggregator : aggregator,
                    validUntil : validUntil,
                    validAfter : validAfter
                }));
            }
            bytes32 hash = _hashTypedDataV4(keccak256(abi.encode(
                keccak256("AggregatedUserOp(address aggregator,uint48 validUntil,uint48 validAfter,uint64 nonceFrom,uint64 nonceTo)"),
                aggregator,
                validUntil,
                validAfter,
                nonceFrom,
                nonceTo
            )));
            address signer = ECDSA.recover(hash, sig);
            if(signer != getWalletStorage().owner || nonceFrom != userOp.nonce || nonceTo <= userOp.nonce) {
                return _packValidationData(true, validUntil, validAfter);
            } else {
                aggregatorValidationData.validAfter = validAfter;
                aggregatorValidationData.validUntil = validUntil;
                aggregatorValidationData.nonceFrom = nonceFrom;
                aggregatorValidationData.nonceTo = nonceTo;
                validationData = _packValidationData(ValidationData({
                    aggregator : aggregator,
                    validUntil : validUntil,
                    validAfter : validAfter
                }));
            }
        }

        if(missingAccountFunds > 0) {
            msg.sender.call{value: missingAccountFunds}("");
        }
    }

    function execute(CallType callType, address _to, bytes calldata _data, uint256 _value) external onlyEntrypoint returns(bytes memory){
        if(callType == CallType.Call) {
            (bool success, bytes memory returndata) = _to.call{value: _value}(_data);
            if(!success) {
                assembly {
                    revert(add(32, returndata), mload(returndata))
                }
            }
            return returndata;
        } else if(callType == CallType.DelegateCall) {
            (bool success, bytes memory returndata) = _to.delegatecall(_data);
            if(!success) {
                assembly {
                    revert(add(32, returndata), mload(returndata))
                }
            }
            return returndata;
        }
        revert InvalidCallType();
    }

    // receive erc721
}