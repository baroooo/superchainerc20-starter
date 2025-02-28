// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';
import {A9KVault} from '../src/A9KVault.sol';
import {IWETH98} from '@interop-lib/interfaces/IWETH98.sol';
import {ISuperchainWETH} from '@interop-lib/interfaces/ISuperchainWETH.sol';
import {IL2ToL2CrossDomainMessenger, Identifier} from '@interop-lib/interfaces/IL2ToL2CrossDomainMessenger.sol';
import {PredeployAddresses} from '@interop-lib/libraries/PredeployAddresses.sol';

contract A9KVaultTest is Test {
  A9KVault vaultOpMainnet;
  A9KVault vaultBase;
  uint256 opMainnetFork;
  uint256 baseFork;
  uint256 opMainnetChainId;
  uint256 baseChainId;

  address treasury = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
  address user = address(0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f);
  address owner = address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);
  uint256 initialWeth = 100 ether;

  address vaultAddress = address(0x17F3C0517aEBE63F3DCE365daE8df5C7B422FAcc);

  function setUp() public {
    vaultOpMainnet = A9KVault(payable(vaultAddress));
    vaultBase = A9KVault(payable(vaultAddress));

    opMainnetFork = vm.createSelectFork('http://localhost:9545'); // op_chain_a
    opMainnetChainId = block.chainid;
    console.log('OP Mainnet Chain ID:', opMainnetChainId);

    baseFork = vm.createSelectFork('http://localhost:9546'); // op_chain_b
    baseChainId = block.chainid;
    console.log('Base Chain ID:', baseChainId);

    vm.selectFork(opMainnetFork);
    assertEq(
        address(vaultOpMainnet),
        address(vaultBase),
        'Vault addresses should be the same on both chains'
    );

    // Mint ETH to user and deposit it into WETH contract
    IWETH98 weth = vaultOpMainnet.weth();
    deal(user, initialWeth); // Give user 100 ETH
    vm.prank(user);
    weth.deposit{value: initialWeth}(); // Deposit 100 ETH to mint 100 WETH

    // Approve vault to spend WETH
    vm.prank(user);
    weth.approve(address(vaultOpMainnet), initialWeth);
  }

  function testDepositAndRebalance() public {
    // Step 1: Deposit wETH into the vault on op_chain_a
    console.log("Chain ID before rebalanceWithdraw on op_chain_a:", block.chainid);
    
    vm.selectFork(opMainnetFork);
    vm.prank(user);
    vaultOpMainnet.deposit(initialWeth, user);

    // Verify: User receives shares
    assertEq(
      vaultOpMainnet.balanceOf(user),
      initialWeth,
      'User should receive shares equal to deposited assets'
    );
    assertEq(
      vaultOpMainnet.weth().balanceOf(user),
      0,
      "User's wETH balance should be 0 after deposit"
    );
    assertEq(
      vaultOpMainnet.weth().balanceOf(address(vaultOpMainnet)),
      initialWeth,
      'Vault on op_chain_a should have wETH balance'
    );
    assertEq(
      vaultOpMainnet.totalSupply(),
      initialWeth,
      'Total shares should equal deposited assets'
    );

    // Step 2: Owner calls rebalanceWithdraw to move wETH to op_chain_b
    vm.prank(vaultOpMainnet.owner());
    vaultOpMainnet.rebalanceWithdraw(initialWeth, baseChainId);

    // Verify: Vault on op_chain_a has 0 wETH after rebalance
    assertEq(
      vaultOpMainnet.weth().balanceOf(address(vaultOpMainnet)),
      0,
      'Vault on op_chain_a should have 0 wETH after rebalance'
    );
    assertEq(
      vaultOpMainnet.movedAssets(),
      0,
      'movedAssets on op_chain_a should be 0 after rebalance'
    );

    // Step 3: Simulate cross-chain message and call completeRebalance on op_chain_b
    vm.selectFork(baseFork);

    // Mock the SentMessage event parameters (in a real test, capture from the transaction receipt)
    Identifier memory id = Identifier({
      origin: PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
      blockNumber: block.number, // Mocked for demo
      logIndex: 0, // Mocked for demo
      timestamp: block.timestamp, // Mocked for demo
      chainId: baseChainId
    });
    bytes memory sentMessage = abi.encode(
      baseChainId,
      PredeployAddresses.SUPERCHAIN_WETH,
      1, // Mocked nonce
      address(vaultOpMainnet),
      abi.encodeCall(
        ISuperchainWETH.relayETH,
        (address(vaultOpMainnet), address(vaultBase), initialWeth)
      )
    );

    // Simulate SuperchainWETH.relayETH sending ETH to the vault
    vm.deal(address(vaultBase), initialWeth);

    // Call completeRebalance
    vm.prank(owner);
    vaultBase.completeRebalance(initialWeth, user, id, sentMessage);

    // Verify: Vault on op_chain_b has wETH after rebalance
    assertEq(
      vaultBase.weth().balanceOf(address(vaultBase)),
      initialWeth,
      'Vault on op_chain_b should have wETH after rebalance'
    );
    assertEq(
      vaultBase.movedAssets(),
      initialWeth,
      'movedAssets on op_chain_b should reflect rebalanced assets'
    );
    assertEq(
      vaultBase.totalSupply(),
      0,
      'Total shares on op_chain_b should be 0 (no new shares minted)'
    );

    // Note: Withdrawal test skipped due to cross-chain share redemption limitation
    // User holds shares on op_chain_a but assets are on op_chain_b, so they cannot withdraw without cross-chain share redemption
  }
}
