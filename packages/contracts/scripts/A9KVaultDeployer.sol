// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from 'forge-std/Script.sol';
import {Vm} from 'forge-std/Vm.sol';
import {A9KVault} from '../src/A9KVault.sol';
import {ISuperchainWETH} from '@interop-lib/interfaces/ISuperchainWETH.sol';
import {PredeployAddresses} from '@interop-lib/libraries/PredeployAddresses.sol';

// Create an address to own the vaults on both chains

contract A9KVaultDeployer is Script {
  string deployConfig;

  constructor() {
    string memory deployConfigPath = vm.envOr(
      'DEPLOY_CONFIG_PATH',
      string('/configs/deploy-config.toml')
    );
    string memory filePath = string.concat(vm.projectRoot(), deployConfigPath);
    deployConfig = vm.readFile(filePath);
  }

  function setUp() public {}

  function run() public {
    // Gets the chains to deploy to from the deploy config
    string[] memory chainsToDeployTo = vm.parseTomlStringArray(
      deployConfig,
      '.deploy_config.chains'
    );

    address deployedAddress;
    address ownerAddr;

    ISuperchainWETH weth = ISuperchainWETH(payable(PredeployAddresses.SUPERCHAIN_WETH));

    // Deploys the vault to each chain
    for (uint256 i = 0; i < chainsToDeployTo.length; i++) {
      string memory chainToDeployTo = chainsToDeployTo[i];

      console.log('Deploying to chain: ', chainToDeployTo);

      vm.createSelectFork(chainToDeployTo);
      // Check if weth is deployed on the chain
      if (address(weth).code.length == 0) {
        revert('WETH not deployed on chain');
      }

      console.log('WETH deployed on chain: ', chainToDeployTo);

      (address _deployedAddress, address _ownerAddr) = deployA9kVault();
      deployedAddress = _deployedAddress;
      ownerAddr = _ownerAddr;
    }

    outputDeploymentResult(deployedAddress, ownerAddr);
  }

  function deployA9kVault() public returns (address addr_, address ownerAddr_) {
    ownerAddr_ = vm.parseTomlAddress(deployConfig, '.vault.owner_address');
    vm.startBroadcast(ownerAddr_);
    // Args needed for the deployment
    address treasuryAddress = vm.parseTomlAddress(
      deployConfig,
      '.vault.treasury_address'
    );
    string memory name = 'A9K wETH';
    string memory symbol = 'A9K wETH';

    bytes memory initCode = abi.encodePacked(
      type(A9KVault).creationCode,
      abi.encode(ownerAddr_, treasuryAddress, name, symbol)
    );
    address preComputedAddress = vm.computeCreate2Address(
      _implSalt(),
      keccak256(initCode)
    );
    if (preComputedAddress.code.length > 0) {
      console.log(
        'A9KVault already deployed at %s',
        preComputedAddress,
        'on chain id: ',
        block.chainid
      );
      addr_ = preComputedAddress;
    } else {
      addr_ = address(
        new A9KVault{salt: _implSalt()}(
          ownerAddr_,
          treasuryAddress,
          name,
          symbol
        )
      );
      console.log(
        'Deployed A9KVault at address: ',
        addr_,
        'on chain id: ',
        block.chainid
      );
    }

    vm.stopBroadcast();
  }

  function outputDeploymentResult(
    address deployedAddress,
    address ownerAddr
  ) public {
    console.log('Outputting deployment result');

    string memory obj = 'result';
    vm.serializeAddress(obj, 'deployedAddress', deployedAddress);
    string memory jsonOutput = vm.serializeAddress(
      obj,
      'ownerAddress',
      ownerAddr
    );

    vm.writeJson(jsonOutput, 'deployment.json');
  }

  /// @notice The CREATE2 salt to be used when deploying the token.
  function _implSalt() internal view returns (bytes32) {
    string memory salt = vm.parseTomlString(
      deployConfig,
      '.deploy_config.salt'
    );
    return keccak256(abi.encodePacked(salt));
  }
}
