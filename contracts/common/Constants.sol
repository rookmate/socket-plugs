// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

address constant ETH_ADDRESS = address(
    0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
);

bytes32 constant NATIVE_CONTROLLER = keccak256("NATIVE_CONTROLLER");
bytes32 constant ERC1155_CONTROLLER = keccak256("ERC1155_CONTROLLER");
bytes32 constant ERC721_CONTROLLER = keccak256("ERC721_CONTROLLER");
bytes32 constant ERC20_CONTROLLER = keccak256("ERC20_CONTROLLER");

bytes32 constant LIMIT_HOOK = keccak256("LIMIT_HOOK");
bytes32 constant LIMIT_EXECUTION_HOOK = keccak256("LIMIT_EXECUTION_HOOK");
bytes32 constant LIMIT_EXECUTION_YIELD_HOOK = keccak256(
    "LIMIT_EXECUTION_YIELD_HOOK"
);
bytes32 constant LIMIT_EXECUTION_YIELD_TOKEN_HOOK = keccak256(
    "LIMIT_EXECUTION_YIELD_TOKEN_HOOK"
);

bytes32 constant ERC1155_VAULT = keccak256("ERC1155_VAULT");
bytes32 constant ERC721_VAULT = keccak256("ERC721_VAULT");
bytes32 constant ERC20_VAULT = keccak256("ERC20_VAULT");
bytes32 constant NATIVE_VAULT = keccak256("NATIVE_VAULT");
