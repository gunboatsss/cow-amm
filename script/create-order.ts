import { ethers } from "npm:ethers@^6.11";

interface SimpleInput {
  internalType: string;
  name: string;
  type: string;
}

interface TupleInput extends SimpleInput {
  components: (TupleInput | SimpleInput)[];
}

type Input = TupleInput | SimpleInput;

interface SafeTransactionExplicitFunction {
  to: string;
  value: string;
  data: null;
  contractMethod: {
    inputs: Input[];
    name: string;
    payable: boolean;
  };
  contractInputsValues: Record<string, string>;
}

type SafeTransaction = SafeTransactionExplicitFunction;

interface TransactionBuilderFormat {
  version: string;
  chainId: string;
  createdAt: number;
  meta: {
    name: string;
    description: string;
    createdFromSafeAddress: string;
  };
  transactions: SafeTransaction[];
}

interface Token {
  decimal: number;
  symbol: number;
  address: string;
}

interface TxData {
  chainId: number;
  ammAddress: string;
  token0: Token;
  token1: Token;
}

function txBuilderJson(txData: TxData) {
  const json: TransactionBuilderFormat = {
    "version": "1.0",
    "chainId": txData.chainId.toString(),
    "createdAt": Date.now(),
    "meta": {
      "name": "Transactions Batch",
      "description": `Setup transaction for a CoW AMM trading ${txData.token0.symbol}/${txData.token0.symbol}`,
      "createdFromSafeAddress": txData.ammAddress,
    },
    "transactions": [
      
      {
        "to": "0xfdaFc9d1902f4e0b84f65F49f244b32b31013b74",
        "value": "0",
        "data": null,
        "contractMethod": {
          "inputs": [
            {
              "components": [
                {
                  "internalType": "contract IConditionalOrder",
                  "name": "handler",
                  "type": "address",
                },
                {
                  "internalType": "bytes32",
                  "name": "salt",
                  "type": "bytes32",
                },
                {
                  "internalType": "bytes",
                  "name": "staticInput",
                  "type": "bytes",
                },
              ],
              "internalType": "struct IConditionalOrder.ConditionalOrderParams",
              "name": "params",
              "type": "tuple",
            },
            { "internalType": "bool", "name": "dispatch", "type": "bool" },
          ],
          "name": "create",
          "payable": false,
        },
        "contractInputsValues": {
          "params":
            '["0x02B70bd29B5F78454FB63A89a292D7100e1d9b52","0x0000000000000000000000000000000000000000000000000000000000000000","0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000def1ca1fb7fbcdc777520aa7f396b4e015f497ab000000000000000000000000000000000000000000000000000e35fa931a0000000000000000000000000000588c956bc94f1399e3b4747ab207762241c5469000000000000000000000000000000000000000000000000000000000000000c0d661a16b0e85eadb705cf5158132b5dd1ebc0a49929ef68097698d15e2a4e3b40000000000000000000000000000000000000000000000000000000000000020de8c195aa41c11a0c4787372defbbddaa31306d2000200000000000000000181"]',
          "dispatch": "true",
        },
      },
    ],
  };
}
