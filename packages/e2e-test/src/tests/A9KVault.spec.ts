import { formatEther, parseEther } from 'viem'
import { beforeAll, describe, expect, it } from 'vitest'
import { testClientByChain } from '@/utils/clients'
import { privateKeyToAccount } from 'viem/accounts'
import {
  createInteropSentL2ToL2Messages,
  decodeRelayedL2ToL2Messages,
} from '@eth-optimism/viem'
import { WETHAbi } from '@/abi/WETHAbi'
import { A9KVaultAbi } from '@/abi/A9KVaultAbi'

// Test suite for A9KVault
describe('A9KVault Cross-Chain Test', async () => {
  const vaultAddress = '0x42979f06e423b7a2C36703A0fa576AC35D7B6bde'

  const userPrivateKey =
    '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a'
  const userAccount = privateKeyToAccount(userPrivateKey)

  const ownerPrivateKey =
    '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'
  const ownerAccount = privateKeyToAccount(ownerPrivateKey)

  const depositAmount = parseEther('100')

  // Init the vault contract
  const vaultContract = {
    address: vaultAddress,
    abi: A9KVaultAbi,
  } as const

  beforeAll(async () => {
    // Verify the user address
    expect(userAccount.address).toEqual(
      '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    )

    // Verify the owner address
    expect(ownerAccount.address).toEqual(
      '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
    )

    // Verify chain IDs
    expect(testClientByChain.supersimL2A.chain.id).toBe(901)
    expect(testClientByChain.supersimL2B.chain.id).toBe(902)

    // Get the address of the WETH contract from the vault contract
    const wethAddress = await testClientByChain.supersimL2A.readContract({
      ...vaultContract,
      functionName: 'superchainWeth',
    })

    // Init the WETH contract
    const wethContract = {
      address: wethAddress as `0x${string}`,
      abi: WETHAbi,
    } as const

    // Log the user balance before wrapping ETH
    console.log(
      `User ETH balance before wrapping: ${formatEther(
        await testClientByChain.supersimL2A.getBalance({
          address: userAccount.address,
        }),
      )}`,
    )

    // Log the user WETH balance before wrapping
    const userWethBalanceBefore =
      (await testClientByChain.supersimL2A.readContract({
        ...wethContract,
        functionName: 'balanceOf',
        args: [userAccount.address],
      })) as bigint

    console.log(
      `User WETH balance before wrapping: ${formatEther(userWethBalanceBefore)}`,
    )

    // Wrap 100 user ETH to mint WETH on supersimL2A
    const wrapTx = await testClientByChain.supersimL2A.writeContract({
      account: userAccount,
      ...wethContract,
      functionName: 'deposit',
      value: depositAmount,
    })

    // Wait for the deposit transaction to be mined
    await testClientByChain.supersimL2A.waitForTransactionReceipt({
      hash: wrapTx,
    })

    console.log(
      `User ETH balance after wrapping: ${formatEther(
        await testClientByChain.supersimL2A.getBalance({
          address: userAccount.address,
        }),
      )}`,
    )

    // Log the user WETH balance after wrapping
    const userWethBalanceAfter =
      (await testClientByChain.supersimL2A.readContract({
        ...wethContract,
        functionName: 'balanceOf',
        args: [userAccount.address],
      })) as bigint

    console.log(
      `User WETH balance after wrapping: ${formatEther(userWethBalanceAfter)}`,
    )

    // Approve vault to spend WETH
    const approveTx = await testClientByChain.supersimL2A.writeContract({
      account: userAccount,
      ...wethContract,
      functionName: 'approve',
      args: [vaultAddress, depositAmount],
    })

    // Wait for the approve transaction to be mined
    await testClientByChain.supersimL2A.waitForTransactionReceipt({
      hash: approveTx,
    })

    expect(userWethBalanceAfter).toBe(userWethBalanceBefore + depositAmount)
  })

  it('should deposit on supersimL2A and rebalance to supersimL2B', async () => {
    // Setup stuff
    // Get the address of the WETH contract from the vault contract
    const wethAddress = (await testClientByChain.supersimL2A.readContract({
      ...vaultContract,
      functionName: 'superchainWeth',
    })) as `0x${string}`

    // Init the WETH contract
    const wethContract = {
      address: wethAddress as `0x${string}`,
      abi: WETHAbi,
    } as const

    // ================================ //

    // Step 1: Deposit users WETH into the vault on supersimL2A

    // Get the users shares before deposit
    const startingBalance = (await testClientByChain.supersimL2A.readContract({
      ...vaultContract,
      functionName: 'balanceOf',
      args: [userAccount.address],
    })) as bigint

    console.log(`User shares before deposit: ${formatEther(startingBalance)}`)

    // Get the balance of WETH in the vault on supersimL2A
    const vaultWethBalanceBefore =
      (await testClientByChain.supersimL2A.readContract({
        ...wethContract,
        functionName: 'balanceOf',
        args: [vaultAddress],
      })) as bigint

    console.log(
      `Vault WETH balance before deposit: ${formatEther(vaultWethBalanceBefore)}`,
    )

    // Send the transaction to deposit the users WETH into the vault
    const depositTx = await testClientByChain.supersimL2A.writeContract({
      account: userAccount,
      ...vaultContract,
      functionName: 'deposit',
      args: [depositAmount, userAccount.address],
    })

    // Wait for the deposit transaction to be mined
    await testClientByChain.supersimL2A.waitForTransactionReceipt({
      hash: depositTx,
    })

    // Verify: User receives shares
    const userShares = (await testClientByChain.supersimL2A.readContract({
      ...vaultContract,
      functionName: 'balanceOf',
      args: [userAccount.address],
    })) as bigint
    expect(userShares).toBe(startingBalance + depositAmount)

    console.log(`User shares after deposit: ${formatEther(userShares)}`)

    // Get the balance of WETH in the users account
    const userWethBalance = (await testClientByChain.supersimL2A.readContract({
      ...wethContract,
      functionName: 'balanceOf',
      args: [userAccount.address],
    })) as bigint
    console.log(
      `User WETH balance after vault deposit: ${formatEther(userWethBalance)}`,
    )

    // Get the balance of WETH in the vault on supersimL2A
    const vaultWethBalance = (await testClientByChain.supersimL2A.readContract({
      ...wethContract,
      functionName: 'balanceOf',
      args: [vaultAddress],
    })) as bigint
    console.log(
      `Vault WETH balance after deposit: ${formatEther(vaultWethBalance)}`,
    )
    expect(vaultWethBalance).toBe(vaultWethBalanceBefore + depositAmount)

    // Get the total supply of the vault
    const totalSupply = (await testClientByChain.supersimL2A.readContract({
      ...vaultContract,
      functionName: 'totalSupply',
    })) as bigint
    expect(totalSupply).toBe(vaultWethBalanceBefore + depositAmount)

    // First get the ownwer of the vault
    const owner = await testClientByChain.supersimL2A.readContract({
      ...vaultContract,
      functionName: 'owner',
    })

    console.log(`Vault owner: ${owner}`)

    // Step 2: Owner calls rebalanceWithdraw to move WETH to supersimL2B

    const rebalanceTx = await testClientByChain.supersimL2A.writeContract({
      account: ownerAccount,
      ...vaultContract,
      functionName: 'rebalanceWithdraw',
      args: [vaultWethBalance, testClientByChain.supersimL2B.chain.id],
      gas: 5000000n,
    })

    // Wait for the rebalance transaction to be mined
    const receipt =
      await testClientByChain.supersimL2A.waitForTransactionReceipt({
        hash: rebalanceTx,
      })

    // // Verify: Vault on supersimL2A has 0 WETH after rebalance
    const vaultWethBalanceAfter =
      (await testClientByChain.supersimL2A.readContract({
        ...wethContract,
        functionName: 'balanceOf',
        args: [vaultAddress],
      })) as bigint
    expect(vaultWethBalanceAfter).toBe(0n)

    const movedAssetsOpMainnet =
      (await testClientByChain.supersimL2A.readContract({
        ...vaultContract,
        functionName: 'movedAssets',
      })) as bigint
    expect(movedAssetsOpMainnet).toBe(0n)

    // Wait for 50 seconds
    await new Promise((resolve) => setTimeout(resolve, 50000))

    // // Verify: Vault on supersimL2B has WETH after rebalance
    const wethBaseBalance = (await testClientByChain.supersimL2B.readContract({
      ...wethContract,
      functionName: 'balanceOf',
      args: [vaultAddress],
    })) as bigint
    expect(wethBaseBalance).toBe(depositAmount)

    const movedAssetsBase = (await testClientByChain.supersimL2B.readContract({
      ...vaultBase,
      functionName: 'movedAssets',
    })) as bigint
    expect(movedAssetsBase).toBe(initialWeth)

    const totalSupplyBase = (await testClientByChain.supersimL2B.readContract({
      ...vaultBase,
      functionName: 'totalSupply',
    })) as bigint
    expect(totalSupplyBase).toBe(0n)
  }, 120000)
})
