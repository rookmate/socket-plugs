// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "solmate/tokens/ERC1155.sol";
import "../utils/RescueBase.sol";
import "../interfaces/IHook.sol";

/**
 * @title Super1155
 * @notice An ERC1155 contract which enables bridging a token to its sibling chains.
 * @dev This contract implements ISuperTokenOrVault to support message bridging through IMessageBridge compliant contracts.
 */
contract Super1155 is ERC1155, RescueBase {
    uint256 private _tokenIdCounter;
    string public name;
    string public symbol;
    // for all controller access (mint, burn)
    bytes32 constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /**
     * @notice constructor for creating a new SuperToken.
     * @param name_ token name
     * @param symbol_ token symbol
     * @param owner_ owner of this contract
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address owner_
    ) ERC1155() AccessControl(owner_) {
        name = name_;
        symbol = symbol_;
        _grantRole(RESCUE_ROLE, owner_);
        _grantRole(CONTROLLER_ROLE, owner_);
    }

    function burn(
        address from,
        uint256 tokenId,
        uint256 amount_
    ) external onlyRole(CONTROLLER_ROLE) {
        _burn(from, tokenId, amount_);
    }

    function mint(
        address receiver_,
        uint256 amount_
    ) external onlyRole(CONTROLLER_ROLE) {
        _mint(receiver_, _tokenIdCounter, amount_, "");
        _tokenIdCounter = _tokenIdCounter + amount_;
    }

    function uri(uint256 id) public view override returns (string memory) {
        return "";
    }
}