// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../common/Constants.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC721.sol";
import "solmate/tokens/ERC1155.sol";

contract TokenType {
    /**
     * @notice Determines the type of bridge based on the given token address.
     * @dev This function returns the bridge type depending on the token address provided.
     *      It supports identifying native tokens (ETH), ERC-20, ERC-721, and ERC-1155 tokens.
     * @param token_ The address of the token to determine the bridge type for.
     * @param isVault It is true when creating a Vault and false when creating a Controller
     * @return A bytes32 identifier representing the bridge type. Possible return values:
     *         - `NATIVE_VAULT` for ETH_ADDRESS.
     *         - `NATIVE_CONTROLLER` for a unknown controller
     *         - `ERC20_VAULT` or `ERC20_CONTROLLER` for ERC-20 tokens.
     *         - `ERC721_VAULT` or `ERC721_CONTROLLER` for ERC-721 tokens.
     *         - `ERC1155_VAULT` or `ERC721_CONTROLLER` for ERC-1155 tokens.
     *         - An empty string if none of the conditions are met (will not occur if the token is valid).
     */
    function _getBridgeType(
        address token_,
        bool isVault
    ) internal view returns (bytes32) {
        if (isVault) {
            if (token_ == ETH_ADDRESS) {
                return NATIVE_VAULT;
            } else if (isERC20(token_)) {
                return ERC20_VAULT;
            } else if (isERC721(token_)) {
                return ERC721_VAULT;
            } else if (isERC1155(token_)) {
                return ERC1155_VAULT;
            } else {
                return "";
            }
        } else {
            if (isERC20(token_)) {
                return ERC20_CONTROLLER;
            } else if (isERC721(token_)) {
                return ERC721_CONTROLLER;
            } else if (isERC1155(token_)) {
                return ERC1155_CONTROLLER;
            } else {
                return NATIVE_CONTROLLER;
            }
        }
    }

    function isERC20(address token) internal view returns (bool) {
        try ERC20(token).totalSupply() {
            return ERC20(token).balanceOf(address(this)) == 0; // Simple check
        } catch {
            return false;
        }
    }

    function isERC721(address token) internal view returns (bool) {
        try ERC721(token).supportsInterface(type(ERC721).interfaceId) {
            return ERC721(token).ownerOf(0) == address(0); // Simple check
        } catch {
            return false;
        }
    }

    function isERC1155(address token) internal view returns (bool) {
        try ERC1155(token).supportsInterface(type(ERC1155).interfaceId) {
            return ERC1155(token).balanceOf(address(this), 0) == 0; // Simple check
        } catch {
            return false;
        }
    }
}
