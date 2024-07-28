# Overview
The NFT Staking contract is designed to allow users to stake their NFTs and earn ERC20 tokens as rewards. This contract supports functionalities for staking, unstaking, and claiming rewards, with upgradeability using the Transparent proxy pattern. The primary goal is to provide a secure and flexible staking mechanism for NFT holders.

# Staking Functionality
1. `Staking NFTs`: Users can stake one or more NFTs, and for each staked NFT, users receive a specified number of reward tokens per block.

2. `Unstaking NFTs`: Users can select specific NFTs to unstake. After unstaking, there is an unbonding period before the user can withdraw the NFT, and no additional rewards are given during this period.

3. `Claiming Rewards`: Users can claim their accumulated rewards after a defined delay period. The delay period resets each time rewards are claimed.
Upgradeable Contract
The contract is implemented using the Transparent proxy pattern, allowing for upgradeability and the addition of new functionalities without disrupting existing operations.

# Control Mechanisms
- `Pause/Unpause Staking`: The contract includes methods to pause and unpause the staking process.
- `Update Reward Tokens per Block`: The contract allows updating the number of reward tokens given per block.
- `Upgrade Staking Configuration`: The contract can upgrade its staking configuration to adapt to new requirements or optimizations.

### Run project by following the steps below:

Copy the ``.env.example`` file in a new file ``.env``.

Install node:
```shell
nvm install v20.0.0
```

Then run command to use the installed node version
```shell
nvm use v20.0.0
```

First install the dependencies:
```shell
yarn install
```
To compile the smart contracts use command:
```shell
npx hardhat compile
```

To run test cases use command:
```shell
npx hardhat test
```

To deploy NFTStaking on hardhat local network use command:
```shell
npx hardhat run scripts/deployNFTStaking.ts
```

To deploy NFTStaking on testnet or mainnet use command:
```shell
npx hardhat run scripts/deployNFTStaking.ts --network <network name>
```

To deploy on network remember to save network url, api key, private key in .env file which will be exported in hardhat.config.ts file.

# Deployed Addresses
- `Reward Token`: 0xA3bccFde9E8E04e846CbD6bf52ec62F3D5cB478d
- `NFT Contract`: 0x72489c0341b319F90F80920f84104E073DcB49C5
- `NFTStaking`: 0xaf8EE14Fc45d5897103A5046c6912Ac58BdB4C57