// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ConstantProductTestHarness} from "../ConstantProductTestHarness.sol";

import {ConstantProduct, GPv2Order, IUniswapV2Pair, IERC20} from "../../src/ConstantProduct.sol";

import "forge-std/console.sol";

abstract contract VerifyTest is ConstantProductTestHarness {
    function verifyWrapper(address owner, ConstantProduct.Data memory staticInput, GPv2Order.Data memory order)
        internal
        view
    {
        constantProduct.verify(
            owner,
            addressFromString("sender"),
            keccak256(bytes("order hash")),
            keccak256(bytes("domain separator")),
            keccak256(bytes("context")),
            abi.encode(staticInput),
            bytes("offchain input"),
            order
        );
    }

    function testDefaultDoesNotRevert() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();

        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testCanInvertTokens() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        (defaultOrder.sellToken, defaultOrder.buyToken) = (defaultOrder.buyToken, defaultOrder.sellToken);

        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testRevertsIfInvalidTokenCombination() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);
        IERC20 badToken = IERC20(addressFromString("bad token"));
        vm.mockCall(
            address(badToken),
            abi.encodeWithSelector(IERC20.balanceOf.selector, orderOwner),
            abi.encode(1337)
        );
        IERC20 badTokenExtra = IERC20(addressFromString("extra bad token"));
        vm.mockCall(
            address(badTokenExtra),
            abi.encodeWithSelector(IERC20.balanceOf.selector, orderOwner),
            abi.encode(1337)
        );

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        IERC20[2][8] memory invalidCombinations = [
            [defaultOrder.sellToken, defaultOrder.sellToken],
            [defaultOrder.buyToken, defaultOrder.buyToken],
            [badToken, badToken],
            [defaultOrder.sellToken, badToken],
            [defaultOrder.buyToken, badToken],
            [badToken, defaultOrder.sellToken],
            [badToken, defaultOrder.buyToken],
            [badToken, badTokenExtra]
        ];
        for (uint256 i = 0; i < invalidCombinations.length; i += 1) {
            defaultOrder.sellToken = invalidCombinations[i][0];
            defaultOrder.buyToken = invalidCombinations[i][1];
            
            vm.expectRevert();
            verifyWrapper(orderOwner, defaultData, defaultOrder);
        }
    }

    function testRevertsIfDifferentReceiver() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        defaultOrder.receiver = addressFromString("bad receiver");

        vm.expectRevert();
        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testRevertsIfExpiresFarInTheFuture() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        defaultOrder.validTo = uint32(block.timestamp) + constantProduct.MAX_ORDER_DURATION() + 1;

        vm.expectRevert();
        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testRevertsIfDifferentAppData() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        defaultOrder.appData = keccak256(bytes("bad app data"));

        vm.expectRevert();
        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testRevertsIfNonzeroFee() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        defaultOrder.feeAmount = 1;

        vm.expectRevert();
        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testRevertsIfSellTokenBalanceIsNotErc20() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        defaultOrder.sellTokenBalance = GPv2Order.BALANCE_EXTERNAL;

        vm.expectRevert();
        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }

    function testRevertsIfBuyTokenBalanceIsNotErc20() public {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        setUpDefaultReserves(orderOwner);

        GPv2Order.Data memory defaultOrder = getDefaultOrder();
        defaultOrder.buyTokenBalance = GPv2Order.BALANCE_EXTERNAL;

        vm.expectRevert();
        verifyWrapper(orderOwner, defaultData, defaultOrder);
    }
}
