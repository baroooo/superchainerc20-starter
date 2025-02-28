// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from 'forge-std/Script.sol';
import {Vm} from 'forge-std/Vm.sol';
import {A9KVault} from '../src/A9KVault.sol';
import {IWETH98} from '@interop-lib/interfaces/IWETH98.sol';
import {PredeployAddresses} from '@interop-lib/libraries/PredeployAddresses.sol';

// Create an address to own the vaults on both chains

contract Start is Script {
  A9KVault a9kVault =
    A9KVault(payable(0xD492e9a955C90C29ce2D30cd71b7C3303dBe7ADE));
  IWETH98 weth;

  uint256 opMainnetFork;
  uint256 baseFork;
  uint256 opMainnetChainId;
  uint256 baseChainId;

  // Vault params
  address treasury = address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
  address owner = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

  // Test Accounts
  address user = address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
  address vaultAddress = address(0x17F3C0517aEBE63F3DCE365daE8df5C7B422FAcc);

  uint256 userPKey =
    0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
  address ownerPKey = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

  uint256 depositAmount = 10 ether;

  function run() public {
    // Create forks
    opMainnetFork = vm.createSelectFork('http://localhost:9545'); // op_chain_a
    vm.startBroadcast();
    opMainnetChainId = block.chainid;
    console.log('OP Mainnet Chain ID:', opMainnetChainId);
    vm.stopBroadcast();

    baseFork = vm.createSelectFork('http://localhost:9546'); // op_chain_b
    vm.startBroadcast();
    baseChainId = block.chainid;
    console.log('Base Chain ID:', baseChainId);
    vm.stopBroadcast();

    // Switch to the user then approve
    vm.selectFork(opMainnetFork);
    vm.startBroadcast(userPKey);

    weth = IWETH98(payable(PredeployAddresses.WETH));

    // Get users weth allowance for the vault
    uint256 userWethAllowance = weth.allowance(user, address(a9kVault));
    console.log('User WETH allowance before approve:', userWethAllowance);

    // Approve vault to spend WETH
    weth.approve(address(a9kVault), depositAmount);

    // Get users weth allowance for the vault
    userWethAllowance = weth.allowance(user, address(a9kVault));
    console.log('User WETH allowance after approve:', userWethAllowance);
    vm.stopBroadcast();

    // ==================================== //
    // Step 1: Deposit wETH into the vault on op_chain_a
    console.log(
      'Chain ID before rebalanceWithdraw on op_chain_a:',
      block.chainid
    );

    vm.selectFork(opMainnetFork);
    vm.startBroadcast(userPKey);

    uint256 userWethAllowanceAgain = weth.allowance(user, address(a9kVault));
    console.log('User WETH allowance again:', userWethAllowanceAgain);

    uint256 sharesBefore = a9kVault.balanceOf(user);
    console.log('Shares before deposit:', sharesBefore);

    a9kVault.deposit(depositAmount, user);

    uint256 sharesAfter = a9kVault.balanceOf(user);
    console.log('Shares after deposit:', sharesAfter);

    vm.stopBroadcast();
  }
}
