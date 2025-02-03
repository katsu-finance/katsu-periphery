import { HardhatUserConfig } from 'hardhat/types';
import { accounts } from './helpers/test-wallets';
import { NETWORKS_RPC_URL } from './helper-hardhat-config';

import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomicfoundation/hardhat-chai-matchers';
import '@typechain/hardhat';
import '@tenderly/hardhat-tenderly';
import 'hardhat-gas-reporter';
import 'solidity-coverage';
import 'hardhat-dependency-compiler';
import 'hardhat-deploy';

import dotenv from 'dotenv';
dotenv.config({ path: '../.env' });

const DEFAULT_BLOCK_GAS_LIMIT = 12450000;
const MAINNET_FORK = process.env.MAINNET_FORK === 'true';
const TENDERLY_PROJECT = process.env.TENDERLY_PROJECT || '';
const TENDERLY_USERNAME = process.env.TENDERLY_USERNAME || '';
const TENDERLY_FORK_NETWORK_ID = process.env.TENDERLY_FORK_NETWORK_ID || '1';
const REPORT_GAS = process.env.REPORT_GAS === 'true';

const mainnetFork = MAINNET_FORK
  ? {
      blockNumber: 12012081,
      url: NETWORKS_RPC_URL['main'],
    }
  : undefined;

// export hardhat config
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.10',
        settings: {
          optimizer: { enabled: true, runs: 25000 },
          evmVersion: 'london',
        },
      },
    ],
  },
  tenderly: {
    project: TENDERLY_PROJECT,
    username: TENDERLY_USERNAME,
    forkNetwork: TENDERLY_FORK_NETWORK_ID,
  },
  typechain: {
    outDir: 'types',
    externalArtifacts: [
      'node_modules/@katsu-finance/core-v3/artifacts/contracts/**/*[!dbg].json',
      'node_modules/@katsu-finance/core-v3/artifacts/contracts/**/**/*[!dbg].json',
      'node_modules/@katsu-finance/core-v3/artifacts/contracts/**/**/**/*[!dbg].json',
      'node_modules/@katsu-finance/core-v3/artifacts/contracts/mocks/tokens/WETH9Mocked.sol/WETH9Mocked.json',
    ],
  },
  gasReporter: {
    enabled: REPORT_GAS ? true : false,
    coinmarketcap: process.env.COINMARKETCAP_API,
  },
  networks: {
    hardhat: {
      hardfork: 'berlin',
      blockGasLimit: DEFAULT_BLOCK_GAS_LIMIT,
      gas: DEFAULT_BLOCK_GAS_LIMIT,
      gasPrice: 8000000000,
      chainId: 31337,
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      accounts: accounts.map(({ secretKey, balance }: { secretKey: string; balance: string }) => ({
        privateKey: secretKey,
        balance,
      })),
      forking: mainnetFork,
      allowUnlimitedContractSize: true,
    },
    ganache: {
      url: 'http://ganache:8545',
      accounts: {
        mnemonic: 'fox sight canyon orphan hotel grow hedgehog build bless august weather swarm',
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
      },
    },
  },
  mocha: {
    timeout: 80000,
    bail: true,
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    aclAdmin: {
      default: 0,
    },
    emergencyAdmin: {
      default: 0,
    },
    poolAdmin: {
      default: 0,
    },
    addressesProviderRegistryOwner: {
      default: 0,
    },
    treasuryProxyAdmin: {
      default: 1,
    },
    incentivesProxyAdmin: {
      default: 1,
    },
    incentivesEmissionManager: {
      default: 0,
    },
    incentivesRewardsVault: {
      default: 2,
    },
  },
  // Need to compile aave-v3 contracts due no way to import external artifacts for hre.ethers
  dependencyCompiler: {
    paths: [
      '@katsu-finance/core-v3/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol',
      '@katsu-finance/core-v3/contracts/protocol/configuration/PoolAddressesProvider.sol',
      '@katsu-finance/core-v3/contracts/misc/AaveOracle.sol',
      '@katsu-finance/core-v3/contracts/protocol/tokenization/AToken.sol',
      '@katsu-finance/core-v3/contracts/protocol/tokenization/DelegationAwareAToken.sol',
      '@katsu-finance/core-v3/contracts/protocol/tokenization/StableDebtToken.sol',
      '@katsu-finance/core-v3/contracts/protocol/tokenization/VariableDebtToken.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/GenericLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/ValidationLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/ReserveLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/SupplyLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/EModeLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/BorrowLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/BridgeLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/logic/FlashLoanLogic.sol',
      '@katsu-finance/core-v3/contracts/protocol/pool/Pool.sol',
      '@katsu-finance/core-v3/contracts/protocol/pool/PoolConfigurator.sol',
      '@katsu-finance/core-v3/contracts/protocol/pool/DefaultReserveInterestRateStrategy.sol',
      '@katsu-finance/core-v3/contracts/dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol',
      '@katsu-finance/core-v3/contracts/protocol/libraries/aave-upgradeability/InitializableImmutableAdminUpgradeabilityProxy.sol',
      '@katsu-finance/core-v3/contracts/deployments/ReservesSetupHelper.sol',
      '@katsu-finance/core-v3/contracts/misc/AaveProtocolDataProvider.sol',
      '@katsu-finance/core-v3/contracts/protocol/configuration/ACLManager.sol',
      '@katsu-finance/core-v3/contracts/dependencies/weth/WETH9.sol',
      '@katsu-finance/core-v3/contracts/mocks/helpers/MockIncentivesController.sol',
      '@katsu-finance/core-v3/contracts/mocks/helpers/MockReserveConfiguration.sol',
      '@katsu-finance/core-v3/contracts/mocks/oracle/CLAggregators/MockAggregator.sol',
      '@katsu-finance/core-v3/contracts/mocks/tokens/MintableERC20.sol',
      '@katsu-finance/core-v3/contracts/mocks/flashloan/MockFlashLoanReceiver.sol',
      '@katsu-finance/core-v3/contracts/mocks/tokens/WETH9Mocked.sol',
      '@katsu-finance/core-v3/contracts/mocks/upgradeability/MockVariableDebtToken.sol',
      '@katsu-finance/core-v3/contracts/mocks/upgradeability/MockAToken.sol',
      '@katsu-finance/core-v3/contracts/mocks/upgradeability/MockStableDebtToken.sol',
      '@katsu-finance/core-v3/contracts/mocks/upgradeability/MockInitializableImplementation.sol',
      '@katsu-finance/core-v3/contracts/mocks/helpers/MockPool.sol',
      '@katsu-finance/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol',
      '@katsu-finance/core-v3/contracts/mocks/oracle/PriceOracle.sol',
      '@katsu-finance/core-v3/contracts/mocks/tokens/MintableDelegationERC20.sol',
    ],
  },
  external: {
    contracts: [
      {
        artifacts: './temp-artifacts',
        deploy: 'node_modules/@aave/deploy-v3/dist/deploy',
      },
    ],
  },
};

export default config;
