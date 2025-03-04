export const A9KVaultAbi = [
  {
    type: 'function',
    name: 'deposit',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
    ],
    outputs: [{ name: 'shares', type: 'uint256' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'rebalanceWithdraw',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'targetChainId', type: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'completeRebalance',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      {
        name: '_id',
        type: 'tuple',
        components: [
          { name: 'origin', type: 'address' },
          { name: 'blockNumber', type: 'uint256' },
          { name: 'logIndex', type: 'uint256' },
          { name: 'timestamp', type: 'uint256' },
          { name: 'chainId', type: 'uint256' },
        ],
      },
      { name: '_sentMessage', type: 'bytes' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'totalSupply',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'totalAssets',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'superchainWeth',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'movedAssets',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'event',
    name: 'Deposit',
    inputs: [
      { name: 'caller', type: 'address', indexed: true },
      { name: 'owner', type: 'address', indexed: true },
      { name: 'assets', type: 'uint256', indexed: false },
      { name: 'shares', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'Rebalanced',
    inputs: [
      { name: 'assets', type: 'uint256', indexed: false },
      { name: 'targetChainId', type: 'uint256', indexed: false },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'RebalancedDeposit',
    inputs: [
      { name: 'assets', type: 'uint256', indexed: false },
      { name: 'receiver', type: 'address', indexed: false },
    ],
    anonymous: false,
  },
]
