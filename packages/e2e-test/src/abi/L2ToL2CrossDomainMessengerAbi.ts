export const L2ToL2CrossDomainMessengerAbi = [
  {
    type: 'event',
    name: 'SentMessage',
    inputs: [
      { name: 'destination', type: 'uint256', indexed: true },
      { name: 'target', type: 'address', indexed: true },
      { name: 'messageNonce', type: 'uint256', indexed: true },
      { name: 'sender', type: 'address', indexed: false },
      { name: 'message', type: 'bytes', indexed: false },
    ],
    anonymous: false,
  },
]
