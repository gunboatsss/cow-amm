// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "lib/composable-cow/lib/@openzeppelin/contracts/interfaces/IERC20.sol";
import {Math} from "lib/composable-cow/lib/@openzeppelin/contracts/utils/math/Math.sol";
import {ConditionalOrdersUtilsLib as Utils} from "lib/composable-cow/src/types/ConditionalOrdersUtilsLib.sol";
import {IConditionalOrderGenerator, IConditionalOrder, IERC165} from "lib/composable-cow/src/BaseConditionalOrder.sol";
import {GPv2Order} from "lib/composable-cow/lib/cowprotocol/src/contracts/libraries/GPv2Order.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "forge-std/console.sol";

contract ConstantProduct is IConditionalOrderGenerator {
    uint32 public constant MAX_ORDER_DURATION = 5 * 60;

    struct Data {
        IUniswapV2Pair referencePair;
        address receiver;
        bytes32 appData;
    }

    /**
     * @inheritdoc IConditionalOrderGenerator
     */
    function getTradeableOrder(address owner, address, bytes32, bytes calldata staticInput, bytes calldata)
        public
        view
        override
        returns (GPv2Order.Data memory order)
    {
        // Note: we are not interested in the gas efficiency of this function
        // because it is not supposed to be called by a call in the blockchain.
        IERC20 token0;
        IERC20 token1;
        uint256 uniswapReserve0;
        uint256 uniswapReserve1;
        {
            ConstantProduct.Data memory data = abi.decode(staticInput, (Data));

            order = GPv2Order.Data(
                IERC20(address(0)),
                IERC20(address(0)),
                data.receiver,
                0,
                0,
                Utils.validToBucket(MAX_ORDER_DURATION),
                data.appData,
                0,
                GPv2Order.KIND_SELL,
                true,
                GPv2Order.BALANCE_ERC20,
                GPv2Order.BALANCE_ERC20
            );

            token0 = IERC20(data.referencePair.token0());
            token1 = IERC20(data.referencePair.token1());
            (uniswapReserve0, uniswapReserve1,) = data.referencePair.getReserves();
        }
        uint256 selfReserve0 = token0.balanceOf(owner);
        uint256 selfReserve1 = token1.balanceOf(owner);

        IERC20 sellToken;
        IERC20 buyToken;
        uint256 sellAmount;
        uint256 buyAmount;
        uint256 sellBalance;
        // Note: sell amount rounds down,
        if (uniswapReserve0 * selfReserve1 < uniswapReserve1 * selfReserve0) {
            sellToken = token0;
            sellBalance = selfReserve0;
            buyToken = token1;
            // Note: it isn't needed to use more sophisticated multiplication like Math.mulDiv because Uniswap reserves are uint112.
            sellAmount = selfReserve0 / 2 - Math.ceilDiv((uniswapReserve0 * selfReserve1), (2 * uniswapReserve1));
            buyAmount = (uniswapReserve1 * selfReserve0) / (2 * uniswapReserve0) - selfReserve1 / 2;
        } else {
            sellToken = token1;
            sellBalance = selfReserve1;
            buyToken = token0;
            sellAmount = selfReserve1 / 2 - Math.ceilDiv((uniswapReserve1 * selfReserve0), (2 * uniswapReserve0));
            buyAmount = (uniswapReserve0 * selfReserve1) / (2 * uniswapReserve1) - selfReserve0 / 2;
        }

        order.sellToken = sellToken;
        order.buyToken = buyToken;
        order.sellAmount = sellAmount;
        order.buyAmount = buyAmount;
    }

    /**
     * @inheritdoc IConditionalOrder
     * @dev As an order generator, the `GPv2Order.Data` passed as a parameter is ignored / not validated.
     */
    function verify(
        address owner,
        address,
        bytes32,
        bytes32,
        bytes32,
        bytes calldata staticInput,
        bytes calldata,
        GPv2Order.Data calldata order
    ) external view override {
        // Wrapper function handles stack too deep issues because of unused input parameters.
        _verify(owner, staticInput, order);
    }

    function _verify(address owner, bytes calldata staticInput, GPv2Order.Data calldata order) internal view {
        ConstantProduct.Data memory data = abi.decode(staticInput, (Data));
        IERC20 sellToken = IERC20(data.referencePair.token0());
        IERC20 buyToken = IERC20(data.referencePair.token1());
        uint256 sellReserve = sellToken.balanceOf(owner);
        uint256 buyReserve = buyToken.balanceOf(owner);
        //console.log("In contract: %s - %s ?", address(sellToken), address(buyToken));
        if (order.sellToken != sellToken) {
            require(order.sellToken == buyToken, "bad sell token");
            (sellToken, buyToken) = (buyToken, sellToken);
            (sellReserve, buyReserve) = (buyReserve, sellReserve);
        }
        require(order.buyToken == buyToken, "bad buy token");

        if (order.receiver != data.receiver) {
            revert("receiver - ERROR");
        }
        // Motivation: avoid spamming the orderbook, force order refresh.
        if (order.validTo > block.timestamp + MAX_ORDER_DURATION) {
            revert("validTo - ERROR");
        }
        if (order.appData != data.appData) {
            revert("appData - ERROR");
        }
        if (order.feeAmount != 0) {
            revert("feeAmount - ERROR");
        }
        if (order.buyTokenBalance != GPv2Order.BALANCE_ERC20) {
            revert("buyTokenBalance - ERROR");
        }
        if (order.sellTokenBalance != GPv2Order.BALANCE_ERC20) {
            revert("sellTokenBalance - ERROR");
        }
        // y ≥ Y*x/(X-2x) => (X-2x) * y ≥ Y*x
        if ((sellReserve - 2 * order.sellAmount) * order.buyAmount < buyReserve * order.sellAmount) {
            revert("amm - ERROR");
        }

        // No checks on:
        //bytes32 kind;
        //bool partiallyFillable;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IConditionalOrderGenerator).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
