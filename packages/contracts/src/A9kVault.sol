// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC4626} from '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {AccessControl} from '@openzeppelin/contracts/access/AccessControl.sol';
import {PredeployAddresses} from '@interop-lib/libraries/PredeployAddresses.sol';
import {IWETH98} from '@interop-lib/interfaces/IWETH98.sol';
import {ISuperchainWETH} from '@interop-lib/interfaces/ISuperchainWETH.sol';
import {IL2ToL2CrossDomainMessenger, Identifier} from '@interop-lib/interfaces/IL2ToL2CrossDomainMessenger.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

/// @title A9K Vault
/// @notice A vault for holding wETH and rebalancing to SuperchainWETH for cross-chain transfer
/// @dev This contract is a modified version of ERC4626, with additional rebalancing functionality
/// @dev Users shares are minted on the chain where they deposit and remain there; assets may move to other chains via rebalancing.
/// @dev Cross-chain share redemption is not supported in this prototype and will be implemented in a future version.
contract A9KVault is ERC4626, AccessControl, ReentrancyGuard {
  bytes32 public constant REBALANCER_ROLE = keccak256('REBALANCER_ROLE');

  // TODO: These are just hardcoded for now, in future these will be a standard IERC20 and SuperERC20 pair
  IWETH98 public immutable weth = IWETH98(payable(PredeployAddresses.WETH)); // Standard wETH (0x...0006)
  ISuperchainWETH public immutable superchainWeth =
    ISuperchainWETH(payable(PredeployAddresses.SUPERCHAIN_WETH)); // SuperchainWETH (0x...0024)

  IL2ToL2CrossDomainMessenger public immutable messenger =
    IL2ToL2CrossDomainMessenger(
      PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER
    ); // L2ToL2CrossDomainMessenger (0x...0023)

  // Treasury address for collecting fees
  address public treasury;

  // Chain ID of this vault's deployment (e.g., OP Mainnet or Base)
  uint256 public chainId;

  // Total assets moved to this vault via rebalancing (not backing local shares)
  uint256 public movedAssets;

  constructor(
    address _treasury,
    uint256 _chainId,
    string memory _name,
    string memory _symbol
  ) ERC4626(IERC20(address(weth))) ERC20(_name, _symbol) {
    treasury = _treasury;
    chainId = _chainId;

    grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    // TODO: This should be Agent 9000. For now we're using the deployer
    grantRole(REBALANCER_ROLE, msg.sender);
  }

  /// @notice Allows users to deposit wETH into the vault
  /// @param assets The amount of wETH to deposit
  /// @param receiver The address to receive the shares
  /// @return shares The amount of shares received
  function deposit(
    uint256 assets,
    address receiver
  ) public override returns (uint256) {
    uint256 shares = super.deposit(assets, receiver);
    emit Deposit(msg.sender, receiver, assets, shares);
    return shares;
  }

  /// @notice Allows users to withdraw wETH from the vault in exchange for shares.
  /// @param assets The amount of wETH to withdraw
  /// @param receiver The address to receive the withdrawn wETH
  /// @param owner The address that owns the vault shares to burn
  /// @return The number of shares burned
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override nonReentrant returns (uint256) {
    // Ensures msg.sender has permission to burn shares from owner
    // If msg.sender != owner, super.withdraw checks allowance(owner, msg.sender)
    uint256 shares = super.withdraw(assets, receiver, owner);

    // TODO: Need to calculate profit
    // Mock profit calculation (10% profit for demo purposes; in production, calculate based on actual yield earned from rebalancing)
    uint256 mockProfit = (assets * 10) / 100; // 10% profit
    uint256 fee = (mockProfit * 10) / 100; // 10% fee on profit
    uint256 userAmount = assets + mockProfit - fee;

    // Transfer wETH to user
    weth.transfer(receiver, userAmount);
    // Transfer fee to treasury
    weth.transfer(treasury, fee);

    emit WithdrawWithProfit(
      msg.sender,
      receiver,
      assets,
      shares,
      mockProfit,
      fee
    );
    return shares;
  }

  /// @notice Protocol rebalances by converting wETH to ETH and initiating a cross-chain transfer
  /// @param assets The amount of ETH (in wETH) to rebalance
  /// @param targetChainId The chain ID of the destination chain
  function rebalanceWithdraw(
    uint256 assets,
    uint256 targetChainId
  ) external onlyRole(REBALANCER_ROLE) {
    require(assets <= totalAssets(), 'Insufficient assets');

    // Step 1: Convert wETH to ETH
    weth.withdraw(assets);

    // Step 2: Initiate cross-chain transfer via SuperchainWETH.sendETH
    // Sends to the A9KVault on the destination chain
    superchainWeth.sendETH{value: assets}(address(this), targetChainId);

    // Step 3: Adjust movedAssets after successful transfer
    if (assets <= movedAssets) {
      movedAssets -= assets;
    } else {
      movedAssets = 0;
    }

    emit Rebalanced(assets, targetChainId);
  }

  /// @notice Protocol relays the cross-chain message and completes the rebalance on the destination chain
  /// @param assets The amount of ETH to deposit as wETH
  /// @param receiver Ignored (no shares minted; assets added to vault's balance)
  /// @param _id The identifier of the SentMessage event on the source chain
  /// @param _sentMessage The encoded SentMessage event data
  function completeRebalance(
    uint256 assets,
    address receiver,
    Identifier calldata _id,
    bytes calldata _sentMessage
  ) external onlyRole(REBALANCER_ROLE) nonReentrant {
    // Step 1: Relay the cross-chain message to execute relayETH
    uint256 balanceBefore = address(this).balance;
    messenger.relayMessage{value: 0}(_id, _sentMessage);
    uint256 balanceAfter = address(this).balance;
    require(
      balanceAfter >= balanceBefore + assets,
      'Insufficient ETH received'
    );

    // Step 2: Convert ETH to wETH (ETH was sent to this contract by SuperchainWETH.relayETH)
    // Convert ETH to wETH to maintain consistency with the vault's underlying asset (wETH)
    weth.deposit{value: assets}();

    // Step 3: Add wETH to vault's balance without minting shares
    // Assets are already backing shares on the source chain
    movedAssets += assets;

    emit RebalancedDeposit(assets, receiver);
  }

  function totalAssets() public view override returns (uint256) {
    return weth.balanceOf(address(this));
  }

  // Update treasury address (admin only)
  function updateTreasury(
    address newTreasury
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    treasury = newTreasury;
    emit TreasuryUpdated(newTreasury);
  }

  // Fallback to receive ETH during wETH withdrawal
  receive() external payable {}

  event Rebalanced(uint256 assets, uint256 targetChainId);
  event RebalancedDeposit(uint256 assets, address receiver);
  event TreasuryUpdated(address newTreasury);
  event WithdrawWithProfit(
    address caller,
    address receiver,
    uint256 assets,
    uint256 shares,
    uint256 profit,
    uint256 fee
  );
}
