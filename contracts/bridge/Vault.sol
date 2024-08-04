// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Base.sol";
import "../common/TokenType.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/tokens/ERC721.sol";
import "solmate/tokens/ERC1155.sol";

/**
 * @title Vault
 * @notice A contract which enables bridging a token to its sibling chains.
 * @dev This contract implements ISuperTokenOrVault to support message bridging through IMessageBridge compliant contracts.
 */
contract Vault is Base, TokenType {
    using SafeTransferLib for ERC20;

    /**
     * @notice constructor for creating a new SuperTokenVault.
     * @param token_ token contract address which is to be bridged.
     */
    constructor(address token_) Base(token_) {
        bridgeType = _getBridgeType(token_, true);
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

        _receiveTokens(amount_, extraData_);

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
        bytes calldata payload_
    ) external payable override nonReentrant {
        (
            address receiver,
            uint256 unlockAmount,
            bytes32 messageId,
            bytes memory extraData
        ) = abi.decode(payload_, (address, uint256, bytes32, bytes));

        TransferInfo memory transferInfo = TransferInfo(
            receiver,
            unlockAmount,
            extraData
        );

        bytes memory postHookData;
        (postHookData, transferInfo) = _beforeMint(
            siblingChainSlug_,
            transferInfo
        );

        _transferTokens(
            transferInfo.receiver,
            transferInfo.amount,
            transferInfo.extraData
        );

        _afterMint(unlockAmount, messageId, postHookData, transferInfo);
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
        _transferTokens(
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
     * @notice Transfers tokens to a specified receiver based on the bridge type.
     * @dev This function performs different types of token transfers depending on the bridge type:
     *      - For `NATIVE_VAULT`, it transfers ETH.
     *      - For `ERC20_VAULT`, it transfers ERC20 tokens.
     *      - For `ERC721_VAULT`, it transfers an ERC721 token using the token ID from `extraData_`.
     *      - For `ERC1155_VAULT`, it transfers an ERC1155 token using the token ID from `extraData_` and the specified amount.
     *      If `amount_` is zero, no transfer occurs.
     *      Reverts if the bridge type is unsupported.
     * @param receiver_ The address to receive the tokens.
     * @param amount_ The amount of tokens to transfer. For ERC721 and ERC1155, this represents the amount of ERC1155 tokens or is ignored for ERC721.
     * @param extraData_ Additional data used to decode the token ID for ERC721 and ERC1155 transfers.
     */
    function _transferTokens(
        address receiver_,
        uint256 amount_,
        bytes memory extraData_
    ) internal {
        if (amount_ == 0) return;

        if (bridgeType == NATIVE_VAULT) {
            SafeTransferLib.safeTransferETH(receiver_, amount_);
        } else if (bridgeType == ERC20_VAULT) {
            ERC20(token).safeTransfer(receiver_, amount_);
        } else if (bridgeType == ERC721_VAULT) {
            uint256 tokenId = decodeTokenId(extraData_);
            ERC721(token).safeTransferFrom(address(this), receiver_, tokenId);
        } else if (bridgeType == ERC1155_VAULT) {
            uint256 tokenId = decodeTokenId(extraData_);
            ERC1155(token).safeTransferFrom(
                address(this),
                receiver_,
                tokenId,
                amount_,
                ""
            );
        } else {
            revert("Unsupported bridge type");
        }
    }

    /**
     * @notice Receives tokens from a sender based on the bridge type.
     * @dev This function performs different types of token reception depending on the bridge type:
     *      - For `ERC20_VAULT`, it receives ERC20 tokens from the sender.
     *      - For `ERC721_VAULT`, it receives an ERC721 token from the sender using the token ID from `extraData_`.
     *      - For `ERC1155_VAULT`, it receives ERC1155 tokens from the sender using the token ID from `extraData_` and the specified amount.
     *      If `amount_` is zero, no reception occurs.
     *      Reverts if the bridge type is unsupported.
     * @param amount_ The amount of tokens to receive. For ERC721, this is ignored, and for ERC1155, it represents the amount.
     * @param extraData_ Additional data used to decode the token ID for ERC721 and ERC1155 receptions.
     */
    function _receiveTokens(uint256 amount_, bytes memory extraData_) internal {
        if (amount_ == 0) return;

        if (bridgeType == NATIVE_VAULT) {
            // Native tokens don't need a receive function
        } else if (bridgeType == ERC20_VAULT) {
            ERC20(token).safeTransferFrom(msg.sender, address(this), amount_);
        } else if (bridgeType == ERC721_VAULT) {
            uint256 tokenId = decodeTokenId(extraData_);
            ERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
        } else if (bridgeType == ERC1155_VAULT) {
            uint256 tokenId = decodeTokenId(extraData_);
            ERC1155(token).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId,
                amount_,
                ""
            );
        } else {
            revert("Unsupported bridge type");
        }
    }
}
