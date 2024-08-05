// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMintableERC721 {
    function mint(address to_, uint256 tokenId_) external;

    function burn(uint256 tokenId_) external;
}
