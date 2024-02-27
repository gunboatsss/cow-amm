// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {console} from "forge-std/Script.sol";
import {DSTest} from "forge-std/StdAssertions.sol";
import {IERC20} from "lib/composable-cow/lib/@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "lib/openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV2Pair} from "lib/uniswap-v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {Strings} from "lib/openzeppelin/contracts/utils/Strings.sol";

import {BalancerWeightedPoolPriceOracle} from "src/oracles/BalancerWeightedPoolPriceOracle.sol";
import {UniswapV2PriceOracle} from "src/oracles/UniswapV2PriceOracle.sol";
import {IPriceOracle} from "src/interfaces/IPriceOracle.sol";

import {Utils} from "script/libraries/Utils.sol";

contract SetupOrder is Utils {
    enum PriceOracleType {
        BalancerWeightedPool,
        UniswapV2
    }

    string public constant BALANCER_WEIGHTED_POOL_CONTRACT = "BalancerWeightedPoolPriceOracle";
    string public constant UNISWAP_V2_CONTRACT = "UniswapV2PriceOracle";

    struct State {
        PriceOracleType priceOracleType;
        IPriceOracle priceOracle;
        bytes priceOracleData;
        IERC20 token0;
        string token0Symbol;
        IERC20 token1;
        string token1Symbol;
        uint256 minTradedToken0;
        bytes32 appData;
    }

    string public constant TOKEN_0_ENV = "TOKEN_0";
    string public constant TOKEN_1_ENV = "TOKEN_1";
    string public constant MIN_TRADED_TOKEN_0_ENV = "MIN_TRADED_TOKEN_0";
    string public constant APP_DATA_ENV = "APP_DATA";

    string public constant PRICE_ORACLE_ENV = "PRICE_ORACLE";
    string public constant BALANCER_WEIGHTED_POOL_ID_ENV = "BALANCER_WEIGHTED_POOL_ID";
    string public constant UNISWAPV2_POOL_ENV = "UNISWAPV2_POOL";

    function run() public {
        State memory state = stateFromEnv();
        prettyPrintState(state);

        buildJson(state);
    }

    function buildJson(State memory state) internal returns (string memory) {
        string memory meta = "{}";
        vm.serializeString(meta, "name", "Transactions Batch");
        vm.serializeString(
            meta,
            "description",
            string.concat("CoW AMM order creation for pair ", state.token0Symbol, "/", state.token1Symbol)
        );

        string transaction = "{}";
        vm.serializeString(transaction, "version", "1.0");
        vm.serializeString(transaction, "chainId", Strings.toString(block.chainId));
        vm.serializeUint(transaction, "createdAt", block.timestamp * 1000);
        return meta;
    }

    function prettyPrintState(State memory state) internal {
        console.log(
            "Price oracle: %s (at address %s)",
            priceOracleTypeToContractName(state.priceOracleType),
            address(state.priceOracle)
        );
        console.log("Price oracle data: %s", toHexString(state.priceOracleData));

        console.log("Token 0: %s (at address %s)", state.token0Symbol, address(state.token0));
        console.log("Token 1: %s (at address %s)", state.token1Symbol, address(state.token1));
        // Hack: We take advantage of the internals of Foundry to avoid having
        // to define our own function to pretty print token amounts with decimal
        // separators.
        uint256 token0Decimals = IERC20Metadata(address(state.token0)).decimals();
        emit DSTest.log_named_decimal_uint(
            string.concat("Min traded value (", state.token0Symbol, ")"), state.minTradedToken0, token0Decimals
        );

        console.log("App data: %s", toHexString(state.appData));
    }

    function stateFromEnv() internal view returns (State memory) {
        PriceOracleType priceOracleType = priceOracleTypeFromContractName(vm.envString(PRICE_ORACLE_ENV));
        IPriceOracle priceOracle = priceOracleFromNetworksJson(priceOracleType);
        bytes memory priceOracleData = getPriceOracleData(priceOracleType);
        IERC20 token0 = IERC20(vm.envAddress(TOKEN_0_ENV));
        string memory token0Symbol = IERC20Metadata(address(token0)).symbol();
        IERC20 token1 = IERC20(vm.envAddress(TOKEN_1_ENV));
        string memory token1Symbol = IERC20Metadata(address(token1)).symbol();
        uint256 minTradedToken0 = vm.envUint(MIN_TRADED_TOKEN_0_ENV);
        bytes32 appData = vm.envBytes32(APP_DATA_ENV);
        return State(
            priceOracleType,
            priceOracle,
            priceOracleData,
            token0,
            token0Symbol,
            token1,
            token1Symbol,
            minTradedToken0,
            appData
        );
    }

    function priceOracleFromNetworksJson(PriceOracleType priceOracleType) internal view returns (IPriceOracle) {
        return IPriceOracle(addressFromNetworksJson(priceOracleTypeToContractName(priceOracleType), block.chainid));
    }

    function addressFromNetworksJson(string memory contractName, uint256 chainId) internal view returns (address) {
        string memory json = vm.readFile("./networks.json");
        return
            abi.decode(vm.parseJson(json, string.concat(".", contractName, ".", Strings.toString(chainId))), (address));
    }

    function priceOracleTypeFromContractName(string memory oracleType) internal view returns (PriceOracleType) {
        if (Utils.isEqual(oracleType, BALANCER_WEIGHTED_POOL_CONTRACT)) {
            return PriceOracleType.BalancerWeightedPool;
        } else if (Utils.isEqual(oracleType, UNISWAP_V2_CONTRACT)) {
            return PriceOracleType.UniswapV2;
        } else {
            console.log("Invalid price oracle type: %s=%s", PRICE_ORACLE_ENV, oracleType);
            revert("Unknown price oracle type");
        }
    }

    function priceOracleTypeToContractName(PriceOracleType oracleType) internal pure returns (string memory) {
        if (oracleType == PriceOracleType.BalancerWeightedPool) {
            return BALANCER_WEIGHTED_POOL_CONTRACT;
        } else if (oracleType == PriceOracleType.UniswapV2) {
            return UNISWAP_V2_CONTRACT;
        } else {
            revert("Unknown price oracle type");
        }
    }

    function getPriceOracleData(PriceOracleType oracleType) internal view returns (bytes memory) {
        if (oracleType == PriceOracleType.BalancerWeightedPool) {
            return abi.encode(BalancerWeightedPoolPriceOracle.Data(vm.envBytes32(BALANCER_WEIGHTED_POOL_CONTRACT)));
        } else if (oracleType == PriceOracleType.UniswapV2) {
            return abi.encode(UniswapV2PriceOracle.Data(IUniswapV2Pair(vm.envAddress(UNISWAPV2_POOL_ENV))));
        } else {
            revert("Unknown price oracle type");
        }
    }
}
