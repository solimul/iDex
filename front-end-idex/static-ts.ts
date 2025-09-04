// fundme-contract.ts

export const MY_CONTRACT_ADDRESS = "0x9f0847148f231f3138d446952e151e694844d507";
export const NETWORK = "sepolia"
export const USDC_CONTRACT_ADDRESS = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";
export const WETH_CONTRACT_ADDRESS = "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9";

export const APPROVE_ABI = [,
    {
        "type": "function",
        "name": "approve",
        "inputs": [
          { "name": "spender", "type": "address" },
          { "name": "amount", "type": "uint256" }
        ],
        "outputs": [{ "name": "", "type": "bool" }]
    }
];

export const MY_CONTRACT_ABI = [
    {
        "type": "constructor",
        "inputs": [
          { "name": "_usdcToken", "type": "address", "internalType": "address" },
          { "name": "_ethToken", "type": "address", "internalType": "address" },
          {
            "name": "_minLiquidityPpm",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_maxWithdrawPct",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_withdrawCooldown",
            "type": "uint256",
            "internalType": "uint256"
          },
          { "name": "_swapFeePct", "type": "uint256", "internalType": "uint256" },
          {
            "name": "_protocolFeePct",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_maxPauseDuration",
            "type": "uint256",
            "internalType": "uint256"
          },
          { "name": "_testing", "type": "bool", "internalType": "bool" }
        ],
        "stateMutability": "nonpayable"
      },
      { "type": "fallback", "stateMutability": "payable" },
      { "type": "receive", "stateMutability": "payable" },
      {
        "type": "function",
        "name": "getAccruedProtocolFees",
        "inputs": [],
        "outputs": [
          { "name": "usdcF", "type": "uint256", "internalType": "uint256" },
          { "name": "ethF", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getAccruedSweepFees",
        "inputs": [],
        "outputs": [
          { "name": "usdcF", "type": "uint256", "internalType": "uint256" },
          { "name": "ethF", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getConfigForTest",
        "inputs": [],
        "outputs": [
          { "name": "", "type": "uint256", "internalType": "uint256" },
          { "name": "", "type": "uint256", "internalType": "uint256" },
          { "name": "", "type": "uint256", "internalType": "uint256" },
          { "name": "", "type": "uint256", "internalType": "uint256" },
          { "name": "", "type": "address", "internalType": "address" }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getContractAddressForTest",
        "inputs": [],
        "outputs": [
          { "name": "", "type": "address", "internalType": "address" },
          { "name": "", "type": "address", "internalType": "address" },
          { "name": "", "type": "address", "internalType": "address" },
          { "name": "", "type": "address", "internalType": "address" }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getERC20ContractAddress",
        "inputs": [
          { "name": "_tokenStr", "type": "string", "internalType": "string" }
        ],
        "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getExchangeRate",
        "inputs": [
          { "name": "_usdc", "type": "uint256", "internalType": "uint256" },
          { "name": "_eth", "type": "uint256", "internalType": "uint256" }
        ],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "pure"
      },
      {
        "type": "function",
        "name": "getLPBalanceByProvider",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getMyERC20ContractAddress",
        "inputs": [],
        "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getPoolExchangeRate",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getProtocolFeePct",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getReserves",
        "inputs": [],
        "outputs": [
          { "name": "usdc", "type": "uint256", "internalType": "uint256" },
          { "name": "eth", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "getSwapFeesPct",
        "inputs": [],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "i_owner",
        "inputs": [],
        "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "isApproved",
        "inputs": [
          { "name": "_tokenStr", "type": "string", "internalType": "string" },
          { "name": "_amount", "type": "uint256", "internalType": "uint256" }
        ],
        "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "isSeeded",
        "inputs": [],
        "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "pauseActivity",
        "inputs": [
          { "name": "_duration", "type": "uint256", "internalType": "uint256" },
          { "name": "_reason", "type": "string", "internalType": "string" }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "quoteOutAmount",
        "inputs": [
          { "name": "_amountIn", "type": "uint256", "internalType": "uint256" },
          { "name": "_tokenInStr", "type": "string", "internalType": "string" },
          { "name": "_tokenOutStr", "type": "string", "internalType": "string" }
        ],
        "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "registerContracts",
        "inputs": [
          {
            "name": "_poolAddress",
            "type": "address",
            "internalType": "address"
          },
          { "name": "_lpAddress", "type": "address", "internalType": "address" },
          {
            "name": "_protocolReward",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "_lpTokenAddress",
            "type": "address",
            "internalType": "address"
          }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "seedDex",
        "inputs": [
          { "name": "_usdc", "type": "uint256", "internalType": "uint256" },
          { "name": "_eth", "type": "uint256", "internalType": "uint256" }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "seeded",
        "inputs": [],
        "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "supplyLiquidity",
        "inputs": [
          { "name": "_usdc", "type": "uint256", "internalType": "uint256" },
          { "name": "_eth", "type": "uint256", "internalType": "uint256" }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "swap",
        "inputs": [
          { "name": "_amountIn", "type": "uint256", "internalType": "uint256" },
          { "name": "_quotedOut", "type": "uint256", "internalType": "uint256" },
          {
            "name": "_slippageBps",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "_tokenInString",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "_tokenOutString",
            "type": "string",
            "internalType": "string"
          }
        ],
        "outputs": [
          { "name": "outAmount", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "tokenMap",
        "inputs": [{ "name": "", "type": "string", "internalType": "string" }],
        "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "unpauseAllActivities",
        "inputs": [],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "viewProtocolRewardBalanceByToken",
        "inputs": [],
        "outputs": [
          { "name": "usdc", "type": "uint256", "internalType": "uint256" },
          { "name": "eth", "type": "uint256", "internalType": "uint256" }
        ],
        "stateMutability": "view"
      },
      {
        "type": "function",
        "name": "withdrawLiquidity",
        "inputs": [
          { "name": "_lp", "type": "uint256", "internalType": "uint256" }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "function",
        "name": "withdrawProtocolReawrd",
        "inputs": [
          { "name": "_amountUSDC", "type": "uint256", "internalType": "uint256" },
          { "name": "_amountETH", "type": "uint256", "internalType": "uint256" }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
      },
      {
        "type": "event",
        "name": "ActivitiesPaused",
        "inputs": [
          {
            "name": "until",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "reason",
            "type": "string",
            "indexed": false,
            "internalType": "string"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "ActivitiesUnpaused",
        "inputs": [],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "LiquidityDepositDone",
        "inputs": [
          {
            "name": "provider",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          },
          {
            "name": "usdcAmount",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "ethAmount",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "usdcToken",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          },
          {
            "name": "wethToken",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "LiquidityWithdrawlDone",
        "inputs": [
          {
            "name": "provider",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "NativeETHReceived",
        "inputs": [
          {
            "name": "from",
            "type": "address",
            "indexed": false,
            "internalType": "address"
          },
          {
            "name": "amount",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      },
      {
        "type": "event",
        "name": "SwapDone",
        "inputs": [
          {
            "name": "swapper",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          },
          {
            "name": "tokenIn",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          },
          {
            "name": "tokenOut",
            "type": "address",
            "indexed": true,
            "internalType": "address"
          },
          {
            "name": "amountIn",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "amountOut",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "swapFee",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "protocolFee",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          },
          {
            "name": "timestamp",
            "type": "uint256",
            "indexed": false,
            "internalType": "uint256"
          }
        ],
        "anonymous": false
      },
      { "type": "error", "name": "ReentrancyGuardReentrantCall", "inputs": [] },
      {
        "type": "error",
        "name": "error_ActivitiesPausedUntil",
        "inputs": [
          { "name": "until", "type": "uint256", "internalType": "uint256" }
        ]
      },
      { "type": "error", "name": "error_AmountIsZero", "inputs": [] },
      { "type": "error", "name": "error_BadQuote", "inputs": [] },
      {
        "type": "error",
        "name": "error_DepositRatioTooLow",
        "inputs": [
          { "name": "userRate", "type": "uint256", "internalType": "uint256" },
          { "name": "poolRate", "type": "uint256", "internalType": "uint256" }
        ]
      },
      {
        "type": "error",
        "name": "error_DoesNotHaveAllowanceToTransfer",
        "inputs": [
          {
            "name": "accessGrantor",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "accessRequiredBy",
            "type": "address",
            "internalType": "address"
          },
          { "name": "amount", "type": "uint256", "internalType": "uint256" }
        ]
      },
      {
        "type": "error",
        "name": "error_DoesNotHaveEnoughBalance",
        "inputs": [
          { "name": "sender", "type": "address", "internalType": "address" },
          { "name": "token", "type": "string", "internalType": "string" },
          { "name": "balance", "type": "uint256", "internalType": "uint256" },
          { "name": "amount", "type": "uint256", "internalType": "uint256" }
        ]
      },
      {
        "type": "error",
        "name": "error_ExternalToInternalTransferFailed",
        "inputs": [
          { "name": "from", "type": "address", "internalType": "address" },
          { "name": "to", "type": "address", "internalType": "address" },
          { "name": "token", "type": "string", "internalType": "string" },
          {
            "name": "tokenAddress",
            "type": "address",
            "internalType": "address"
          },
          { "name": "_amount", "type": "uint256", "internalType": "uint256" }
        ]
      },
      {
        "type": "error",
        "name": "error_InternalToExternalTransferFailed",
        "inputs": []
      },
      {
        "type": "error",
        "name": "error_InvalidLiquidityProvisionAddress",
        "inputs": []
      },
      { "type": "error", "name": "error_InvalidMyERC20Address", "inputs": [] },
      {
        "type": "error",
        "name": "error_InvalidPauseDuration",
        "inputs": [
          { "name": "asked", "type": "uint256", "internalType": "uint256" },
          { "name": "max", "type": "uint256", "internalType": "uint256" }
        ]
      },
      { "type": "error", "name": "error_InvalidPoolAddress", "inputs": [] },
      {
        "type": "error",
        "name": "error_InvalidToken",
        "inputs": [
          { "name": "givenToken", "type": "string", "internalType": "string" },
          { "name": "acceptedTokens", "type": "string", "internalType": "string" }
        ]
      },
      {
        "type": "error",
        "name": "error_LPAllowanceTooLow",
        "inputs": [
          { "name": "have", "type": "uint256", "internalType": "uint256" },
          { "name": "need", "type": "uint256", "internalType": "uint256" }
        ]
      },
      { "type": "error", "name": "error_LPBalanceTooLow", "inputs": [] },
      {
        "type": "error",
        "name": "error_MinLiquidityPpmTooHigh",
        "inputs": [
          { "name": "value", "type": "uint256", "internalType": "uint256" },
          { "name": "max", "type": "uint256", "internalType": "uint256" }
        ]
      },
      { "type": "error", "name": "error_NoETHBalance", "inputs": [] },
      {
        "type": "error",
        "name": "error_OnlyLPTokenHoldersCanAccessThisFunction",
        "inputs": []
      },
      {
        "type": "error",
        "name": "error_OnlyOwnerCanAccessThisFunction",
        "inputs": [
          { "name": "owner", "type": "address", "internalType": "address" },
          { "name": "sender", "type": "address", "internalType": "address" }
        ]
      },
      {
        "type": "error",
        "name": "error_PercentageOutOfRange",
        "inputs": [
          { "name": "field", "type": "string", "internalType": "string" },
          { "name": "value", "type": "uint256", "internalType": "uint256" },
          { "name": "max", "type": "uint256", "internalType": "uint256" }
        ]
      },
      { "type": "error", "name": "error_PoolAlreadySedded", "inputs": [] },
      { "type": "error", "name": "error_PoolHasNotBeenSeddedYet", "inputs": [] },
      {
        "type": "error",
        "name": "error_PostTransferBalanceMismatch",
        "inputs": []
      },
      { "type": "error", "name": "error_ProviderNotRegistered", "inputs": [] },
      {
        "type": "error",
        "name": "error_SameTokenCannotBeExchanged",
        "inputs": []
      },
      { "type": "error", "name": "error_SenderIsNotValid", "inputs": [] },
      {
        "type": "error",
        "name": "error_SlippageBpsTooHigh",
        "inputs": [
          { "name": "slippageBps", "type": "uint256", "internalType": "uint256" }
        ]
      },
      {
        "type": "error",
        "name": "error_SlippageTooHigh",
        "inputs": [
          {
            "name": "quotedOutAmount",
            "type": "uint256",
            "internalType": "uint256"
          },
          { "name": "outAmount", "type": "uint256", "internalType": "uint256" }
        ]
      },
      {
        "type": "error",
        "name": "error_TotaSupplyMismatchAfterMinting",
        "inputs": []
      },
      { "type": "error", "name": "error_UelpAmountIsZero", "inputs": [] },
      { "type": "error", "name": "error_WithdrawCooldownZero", "inputs": [] },
      {
        "type": "error",
        "name": "error_WithdrawalRequestTooEarly",
        "inputs": [
          {
            "name": "timeSinceLast",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "requiredWindow",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "type": "error",
        "name": "error_WithdrawalShareExceedsLimit",
        "inputs": [
          {
            "name": "requestedShare",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxAllowedShare",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
  ];

