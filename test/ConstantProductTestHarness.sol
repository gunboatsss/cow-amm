// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseComposableCoWTest} from "lib/composable-cow/test/ComposableCoW.base.t.sol";

import {ConstantProduct, GPv2Order, IUniswapV2Pair, IERC20} from "../src/ConstantProduct.sol";

abstract contract ConstantProductTestHarness is BaseComposableCoWTest {
    ConstantProduct constantProduct;
    address internal orderOwner = addressFromString("order owner");

    address private USDC = addressFromString("USDC");
    address private WETH = addressFromString("WETH");
    address private DEFAULT_PAIR = addressFromString("default USDC/WETH pair");
    address private DEFAULT_RECEIVER = addressFromString("default receiver");
    bytes32 private DEFAULT_APPDATA = keccak256(bytes("unit test"));

    struct DefaultTokens {
        IERC20 weth;
        IERC20 usdc;
    }

    function setUp() public virtual override(BaseComposableCoWTest) {
        super.setUp();

        constantProduct = new ConstantProduct();
    }

    function setUpDefaultPair() internal returns (IUniswapV2Pair pair) {
        vm.mockCall(DEFAULT_PAIR, abi.encodeWithSelector(IUniswapV2Pair.token0.selector), abi.encode(USDC));
        vm.mockCall(DEFAULT_PAIR, abi.encodeWithSelector(IUniswapV2Pair.token1.selector), abi.encode(WETH));
        // Reverts for everything else
        //vm.mockCallRevert(DEFAULT_PAIR, hex"", abi.encode("Called unexpected function on mock pair"));
        pair = IUniswapV2Pair(DEFAULT_PAIR);
        require(pair.token0() != pair.token1(), "Pair setup failed: should use distinct tokens");
        require(pair.token0() != pair.token1(), "Pair setup failed: should use distinct tokens");
    }

    function setUpDefaultData() internal returns (ConstantProduct.Data memory) {
        setUpDefaultPair();
        return getDefaultData();
    }

    function getDefaultData() internal view returns (ConstantProduct.Data memory) {
        return ConstantProduct.Data(IUniswapV2Pair(DEFAULT_PAIR), DEFAULT_RECEIVER, DEFAULT_APPDATA);
    }

    function getDefaultOrder() internal view returns (GPv2Order.Data memory) {
        ConstantProduct.Data memory data = getDefaultData();

        return GPv2Order.Data(
            IERC20(data.referencePair.token0()), // IERC20 sellToken;
            IERC20(data.referencePair.token1()), // IERC20 buyToken;
            data.receiver, // address receiver;
            0, // uint256 sellAmount;
            0, // uint256 buyAmount;
            uint32(block.timestamp) + constantProduct.MAX_ORDER_DURATION() / 2, // uint32 validTo;
            data.appData, // bytes32 appData;
            0, // uint256 feeAmount;
            GPv2Order.KIND_SELL, // bytes32 kind;
            true, // bool partiallyFillable;
            GPv2Order.BALANCE_ERC20, // bytes32 sellTokenBalance;
            GPv2Order.BALANCE_ERC20 // bytes32 buyTokenBalance;
        );
    }

    function setUpDefaultReserves(address owner) internal {
        ConstantProduct.Data memory defaultData = setUpDefaultData();
        vm.mockCall(
            defaultData.referencePair.token0(),
            abi.encodeWithSelector(IERC20.balanceOf.selector, owner),
            abi.encode(1337)
        );
        vm.mockCall(
            defaultData.referencePair.token1(),
            abi.encodeWithSelector(IERC20.balanceOf.selector, owner),
            abi.encode(1337)
        );
    }

    function addressFromString(string memory s) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(s)))));
    }
}
