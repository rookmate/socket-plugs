// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Base.sol";
import "../common/TokenType.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC721.sol";
import "solmate/tokens/ERC1155.sol";

/**
 * @title Controller
 * @notice A contract which enables bridging a token to its sibling chains.
 * @dev This contract implements IController to support message bridging through IMessageBridge compliant contracts.
 */
contract Controller is Base, TokenType {
    using SafeTransferLib for ERC20;

    uint256 public totalMinted;

    /**
     * @notice constructor for creating a new SuperTokenVault.
     * @param token_ token contract address which is to be bridged.
     */
    constructor(address token_) Base(token_) {
        bridgeType = _getBridgeType(token_, false);
    }

    /**
     * @notice Bridges tokens between chains.
     * @dev This function allows bridging tokens between different chains.
     * @param receiver_ The address to receive the bridged tokens.
     * @param amount_ The amount of tokens to bridge.
     * @param msgGasLimit_ The gas limit for the execution of the bridging process.
     * @param connector_ The address of the connector contract responsible for the bridge.
     * @param extraData_ The extra data passed to hook functions. The token ID for ERC721 or ERC1155 tokens (if applicable).
     * @param options_ Additional options for the bridging process.
     */
    function bridge(
        address receiver_,
        uint256 amount_,
        uint256 msgGasLimit_,
        address connector_,
        bytes calldata extraData_,
        bytes calldata options_
    ) external payable nonReentrant {
        (
            TransferInfo memory transferInfo,
            bytes memory postHookData
        ) = _beforeBridge(
                connector_,
                TransferInfo(receiver_, amount_, extraData_)
            );

        // to maintain socket dl specific accounting for super token
        // re check this logic for mint and mint use cases and if other minter involved
        _burn(msg.sender, amount_, extraData_);

        _afterBridge(
            msgGasLimit_,
            connector_,
            options_,
            postHookData,
            transferInfo
        );
    }

    /**
     * @notice Receives inbound tokens from another chain.
     * @dev This function is used to receive tokens from another chain.
     * @param siblingChainSlug_ The identifier of the sibling chain.
     * @param payload_ The payload containing the inbound tokens.
     */
    function receiveInbound(
        uint32 siblingChainSlug_,
        bytes memory payload_
    ) external payable override nonReentrant {
        (
            address receiver,
            uint256 lockAmount,
            bytes32 messageId,
            bytes memory extraData
        ) = abi.decode(payload_, (address, uint256, bytes32, bytes));

        // convert to shares
        TransferInfo memory transferInfo = TransferInfo(
            receiver,
            lockAmount,
            extraData
        );

        bytes memory postHookData;
        (postHookData, transferInfo) = _beforeMint(
            siblingChainSlug_,
            transferInfo
        );

        _mint(
            transferInfo.receiver,
            transferInfo.amount,
            transferInfo.extraData
        );

        _afterMint(lockAmount, messageId, postHookData, transferInfo);
    }

    /**
     * @notice Retry a failed transaction.
     * @dev This function allows retrying a failed transaction sent through a connector.
     * @param connector_ The address of the connector contract responsible for the failed transaction.
     * @param messageId_ The unique identifier of the failed transaction.
     */
    function retry(
        address connector_,
        bytes32 messageId_
    ) external nonReentrant {
        (
            bytes memory postHookData,
            TransferInfo memory transferInfo
        ) = _beforeRetry(connector_, messageId_);
        _mint(
            transferInfo.receiver,
            transferInfo.amount,
            transferInfo.extraData
        );

        _afterRetry(connector_, messageId_, postHookData);
    }

    /**
     * @notice Decodes a token ID from the given extra data.
     * @dev This function attempts to decode a uint256 token ID from the provided `extraData`.
     *      If `extraData` is empty, the function will revert
     *      If decoding fails due to incorrect data, it will also revert.
     * @param extraData The bytes data containing the encoded token ID.
     * @return tokenId The decoded token ID as a uint256.
     */
    function decodeTokenId(
        bytes memory extraData
    ) internal pure returns (uint256) {
        if (extraData.length == 0) {
            revert(
                "extraData is empty. Ensure you have an encoded tokenId in this field."
            );
        }

        return abi.decode(extraData, (uint256));
    }

    /**
     * @notice Burns tokens from a user based on the bridge type.
     * @dev This function performs different types of token burns depending on the bridge type:
     *      - For `ERC20_CONTROLLER`, it burns ERC20 tokens from the user.
     *      - For `ERC721_CONTROLLER`, it burns an ERC721 token from the user using the token ID from `extraData_`.
     *      - For `ERC1155_CONTROLLER`, it burns ERC1155 tokens from the user using the token ID from `extraData_` and the specified amount.
     *      Reverts if the bridge type is unsupported.
     * @param user_ The address of the user from whom the tokens are burned.
     * @param burnAmount_ The amount of tokens to burn. For ERC721, this is ignored, and for ERC1155, it represents the amount.
     * @param extraData_ Additional data used to decode the token ID for ERC721 and ERC1155 burns.
     */
    function _burn(
        address user_,
        uint256 burnAmount_,
        bytes memory extraData_
    ) internal virtual {
        if (bridgeType == ERC20_CONTROLLER) {
            totalMinted -= burnAmount_;
            IMintableERC20(token).burn(user_, burnAmount_);
        } /*else if (bridgeType == ERC721_CONTROLLER) {
            uint256 tokenId = decodeTokenId(extraData_);
            totalMinted -= 1;
            ERC721(token).safeTransferFrom(user_, address(this), tokenId);
            IMintableERC721(token).burn(tokenId);
        } else if (bridgeType == ERC1155_CONTROLLER) {
            uint256 tokenId = decodeTokenId(extraData_);
            totalMinted -= burnAmount_;
            ERC1155(token).safeTransferFrom(user_, address(this), tokenId, burnAmount_, "");
            IMintableERC1155(token).burn(address(this), tokenId, burnAmount_);
        } else {
            revert("Unsupported bridge type");
        }*/
    }

    /**
     * @notice Mints tokens to a user based on the bridge type.
     * @dev This function performs different types of token mints depending on the bridge type:
     *      - For `ERC20_CONTROLLER`, it mints ERC20 tokens to the user.
     *      - For `ERC721_CONTROLLER`, it mints an ERC721 token to the user using the token ID from `extraData_`.
     *      - For `ERC1155_CONTROLLER`, it mints ERC1155 tokens to the user using the token ID from `extraData_` and the specified amount.
     *      If `mintAmount_` is zero, no mint occurs.
     *      Reverts if the bridge type is unsupported.
     * @param user_ The address of the user to whom the tokens are minted.
     * @param mintAmount_ The amount of tokens to mint. For ERC721, this is ignored, and for ERC1155, it represents the amount.
     * @param extraData_ Additional data used to decode the token ID for ERC721 and ERC1155 mints.
     */
    function _mint(
        address user_,
        uint256 mintAmount_,
        bytes memory extraData_
    ) internal virtual {
        if (mintAmount_ == 0) return;

        if (bridgeType == ERC20_CONTROLLER) {
            totalMinted += mintAmount_;
            IMintableERC20(token).mint(user_, mintAmount_);
        } /*else if (bridgeType == ERC721_CONTROLLER) {
            uint256 tokenId = decodeTokenId(extraData_);
            totalMinted += 1;
            IMintableERC721(token).mint(user_, tokenId);
        } else if (bridgeType == ERC1155_CONTROLLER) {
            uint256 tokenId = decodeTokenId(extraData_);
            totalMinted += mintAmount_;
            IMintableERC1155(token).mint(user_, tokenId, mintAmount_, "");
        } else {
            revert("Unsupported bridge type");
        }*/
    }
}
