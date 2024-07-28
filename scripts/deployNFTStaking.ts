import { Addressable, parseUnits } from "ethers";
import { ethers, upgrades } from "hardhat";

// configure while deploying
let REWARD_TOKEN_ADDRESS: string | Addressable = "";
const REWARD_SPEED = parseUnits("1", 18);

// set to false if testnet setup is not required
const deployTestnetSetup = true;

async function main() {
  if (deployTestnetSetup) {
    const RewardTokenFactory = await ethers.getContractFactory("MockERC20");
    console.log("RewardToken contract is deploying........");

    const rewardToken = await RewardTokenFactory.deploy("MockToken", "MTK");
    console.log("RewardToken deployed at address: ", rewardToken.target);

    const NFTContractFactory = await ethers.getContractFactory("MockERC721");
    console.log("NFT contract is deploying........");

    const nftContract = await NFTContractFactory.deploy("MockNFT", "MNFT");
    console.log("NNFT contract deployed at address: ", nftContract.target);

    REWARD_TOKEN_ADDRESS = rewardToken.target;
  }

  const NFTStakingFactory = await ethers.getContractFactory("NFTStaking");

  console.log("NFTStaking contract is deploying........");
  const nftStaking = await upgrades.deployProxy(
    NFTStakingFactory,
    [REWARD_TOKEN_ADDRESS, REWARD_SPEED],
    {
      initializer: "initialize",
      unsafeAllow: ["constructor"],
    }
  );

  console.log("NFTStaking deployed at address: ", nftStaking.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
