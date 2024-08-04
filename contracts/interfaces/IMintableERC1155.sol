// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMintableERC1155 {
    function mint(
        address to_,
        uint256 id_,
        uint256 amount_,
        bytes calldata data_
    ) external;

    function burn(address from_, uint256 id_, uint256 amount_) external;
}
