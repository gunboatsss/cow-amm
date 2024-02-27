// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {Script, console} from "forge-std/Script.sol";

abstract contract Utils is Script {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";

    function addressEnvOrDefault(string memory envName, address defaultAddr) internal view returns (address) {
        try vm.envAddress(envName) returns (address env) {
            return env;
        } catch {
            return defaultAddr;
        }
    }

    function assertHasCode(address a, string memory context) internal view {
        require(a.code.length > 0, context);
    }

    function isEqual(string memory lhs, string memory rhs) internal pure returns (bool) {
        return keccak256(abi.encode(lhs)) == keccak256(abi.encode(rhs));
    }

    function toHexString(bytes memory value) internal pure returns (string memory) {
        uint256 stringLenght = 2 * value.length + 2;
        bytes memory buffer = new bytes(stringLenght);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 0; i < value.length; i++) {
            uint256 stringIndex = 2 * (i + 1);
            uint256 leftByteDigit = uint256(bytes32(value[i])) >> (256 - 4);
            buffer[stringIndex] = _SYMBOLS[leftByteDigit];
            uint256 rightByteDigit = (uint256(bytes32(value[i])) >> (256 - 8)) & 0x0f;
            buffer[stringIndex + 1] = _SYMBOLS[rightByteDigit];
        }
        return string(buffer);
    }

    function toHexString(bytes32 value) internal pure returns (string memory) {
        return toHexString(abi.encode(value));
    }
}
