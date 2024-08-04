// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "solmate/tokens/ERC721.sol";
import "../utils/RescueBase.sol";
import "../interfaces/IHook.sol";

/**
 * @title Super721
 * @notice An ERC721 contract which enables bridging a token to its sibling chains.
 * @dev This contract implements ISuperTokenOrVault to support message bridging through IMessageBridge compliant contracts.
 */
contract Super721 is ERC721, RescueBase {
    uint256 private _tokenIdCounter;
    // for all controller access (mint, burn)
    bytes32 constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    /**
     * @notice constructor for creating a new SuperToken.
     * @param name_ token name
     * @param symbol_ token symbol
     * @param initialSupplyHolder_ address to which initial supply will be minted
     * @param owner_ owner of this contract
     * @param initialSupply_ initial supply of super token
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address initialSupplyHolder_,
        address owner_,
        uint256 initialSupply_
    ) ERC721(name_, symbol_) AccessControl(owner_) {
        _grantRole(RESCUE_ROLE, owner_);
    }

    function burn(
        uint256 tokenId
    ) external onlyRole(CONTROLLER_ROLE) {
        _burn(tokenId);
    }

    function mint(
        address receiver_,
        uint256 amount_
    ) external onlyRole(CONTROLLER_ROLE) {
        _mint(receiver_, amount_);
        _tokenIdCounter = _tokenIdCounter + amount_;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return "";
    }
}
