// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./Base.sol";
import "../common/TokenType.sol";
import "../interfaces/IConnector.sol";
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
        bridgeType = _getBridgeType(token_);
    }

    /**
     * @notice Bridges tokens between chains.
     * @dev This function allows bridging tokens between different chains.
     * @param receiver_ The address to receive the bridged tokens.
     * @param amount_ The amount of tokens to bridge.
     * @param msgGasLimit_ The gas limit for the execution of the bridging process.
     * @param connector_ The address of the connector contract responsible for the bridge.
     * @param extraData_ The extra data passed to hook functions.
     * @param options_ Additional options for the bridging process.
     * @param tokenIdERC721_ The token ID for ERC721 tokens (if applicable).
     * @param tokenIdERC1155_ The token ID for ERC1155 tokens (if applicable).
     */
    function bridge(
        address receiver_,
        uint256 amount_,
        uint256 msgGasLimit_,
        address connector_,
        bytes calldata extraData_,
        bytes calldata options_,
        uint256 tokenIdERC721_,
        uint256 tokenIdERC1155_
    ) external payable nonReentrant {
        (
            TransferInfo memory transferInfo,
            bytes memory postHookData
        ) = _beforeBridge(
                connector_,
                TransferInfo(receiver_, amount_, extraData_)
            );

        _receiveTokens(amount_, tokenIdERC721_, tokenIdERC1155_);

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
            uint256 unlockAmount,
            bytes32 messageId,
            bytes memory extraData,
            uint256 tokenIdERC721_,
            uint256 tokenIdERC1155_
        ) = abi.decode(payload_, (address, uint256, bytes32, bytes, uint256, uint256));

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

        _transferTokens(transferInfo.receiver, transferInfo.amount, tokenIdERC721_, tokenIdERC1155_);

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
        // TODO: Ensure retry has all the required information, including the tokenIdERC721, tokenIdERC1155
        _transferTokens(transferInfo.receiver, transferInfo.amount, 0, 0);

        _afterRetry(connector_, messageId_, postHookData);
    }

    function _transferTokens(
        address receiver_,
        uint256 amount_,
        uint256 tokenIdERC721_,
        uint256 tokenIdERC1155_
    ) internal {
        if (amount_ == 0) return;

        if (bridgeType == NATIVE_VAULT) {
            SafeTransferLib.safeTransferETH(receiver_, amount_);
        } else if (bridgeType == ERC20_VAULT) {
            ERC20(token).safeTransfer(receiver_, amount_);
        } else if (bridgeType == ERC721_VAULT) {
            ERC721(token).safeTransferFrom(address(this), receiver_, tokenIdERC721_);
        } else if (bridgeType == ERC1155_VAULT) {
            ERC1155(token).safeTransferFrom(address(this), receiver_, tokenIdERC1155_, amount_, "");
        } else {
            revert("Unsupported bridge type");
        }
    }

    function _receiveTokens(
        uint256 amount_,
        uint256 tokenIdERC721_,
        uint256 tokenIdERC1155_
    ) internal {
        if (amount_ == 0) return;

        if (bridgeType == NATIVE_VAULT) {
            // Native tokens don't need a receive function
        } else if (bridgeType == ERC20_VAULT) {
            ERC20(token).safeTransferFrom(msg.sender, address(this), amount_);
        } else if (bridgeType == ERC721_VAULT) {
            ERC721(token).safeTransferFrom(msg.sender, address(this), tokenIdERC721_);
        } else if (bridgeType == ERC1155_VAULT) {
            ERC1155(token).safeTransferFrom(msg.sender, address(this), tokenIdERC1155_, amount_, "");
        } else {
            revert("Unsupported bridge type");
        }
    }
}
