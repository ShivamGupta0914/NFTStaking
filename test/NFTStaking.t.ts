import {
  loadFixture,
  mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers, upgrades } from "hardhat";
import { parseUnits, Signer } from "ethers";
import { MockERC20, MockERC721, NFTStaking } from "../typechain-types";

describe("NFTStaking.t", function () {
  let nftContract1: MockERC721;
  let nftContract2: MockERC721;
  let rewardToken: MockERC20;
  let nftStaking: NFTStaking;
  let owner: Signer;
  let otherAccount: Signer;

  async function setUpStakeNFT(account: Signer, tokenId: number) {
    await nftContract1.safeMint(await account.getAddress());
    await nftContract1.safeMint(await account.getAddress());
    await nftContract1.safeMint(await account.getAddress());
    await nftContract1
      .connect(account)
      .setApprovalForAll(nftStaking.target, true);

    await nftStaking.setDelayPeriod(50);
    await nftStaking.setWhiteListStatus(nftContract1.target, true);
    await nftStaking.connect(account).stakeNFT(nftContract1.target, tokenId);
  }

  const rewardTokenSpeed = parseUnits("1", 18);

  async function deployNFTStakingFixture() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const NFTStaking = await hre.ethers.getContractFactory("NFTStaking");
    const ERC20 = await hre.ethers.getContractFactory("MockERC20");
    const NFTContract = await hre.ethers.getContractFactory("MockERC721");

    const nftContract1 = await NFTContract.deploy("NFT1", "NFT1");
    const nftContract2 = await NFTContract.deploy("NFT2", "NFT2");
    const rewardToken = await ERC20.deploy("TOKEN1", "TK1");

    const nftStaking = await upgrades.deployProxy(
      NFTStaking,
      [rewardToken.target, rewardTokenSpeed],
      {
        initializer: "initialize(address,uint256)",
      }
    );

    return {
      owner,
      otherAccount,
      rewardToken,
      nftContract1,
      nftContract2,
      nftStaking,
    };
  }

  beforeEach(async () => {
    ({
      owner,
      otherAccount,
      nftContract1,
      nftContract2,
      rewardToken,
      nftStaking,
    } = await loadFixture(deployNFTStakingFixture));
  });

  describe("initialize", function () {
    it("should revert on initializing again", async () => {
      await expect(
        nftStaking.initialize(rewardToken.target, 11)
      ).to.be.revertedWith("Initializable: contract is already initialized");
    });
  });

  describe("setDelayPeriod", function () {
    it("should set the delay period", async () => {
      await expect(nftStaking.setDelayPeriod(60))
        .to.be.emit(nftStaking, "DelayPeriodUpdated")
        .withArgs(0, 60);
      expect(await nftStaking.delayPeriod()).to.eq(60);
    });

    it("should revert if not owner", async () => {
      await expect(
        nftStaking.connect(otherAccount).setDelayPeriod(60)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("setUnboundingPeriod", function () {
    it("should set the unbounding period", async () => {
      await expect(nftStaking.setUnboundingPeriod(100))
        .to.be.emit(nftStaking, "UnboundingPeriodUpdated")
        .withArgs(0, 100);
      expect(await nftStaking.unboundingPeriod()).to.eq(100);
    });

    it("should revert if not owner", async () => {
      await expect(
        nftStaking.connect(otherAccount).setUnboundingPeriod(60)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("setWhiteListStatus", function () {
    it("should set white list status", async () => {
      await expect(nftStaking.setWhiteListStatus(nftContract1.target, true))
        .to.emit(nftStaking, "WhiteListedStatusUpdated")
        .withArgs(nftContract1.target, true);
      expect(
        await nftStaking.isWhiteListedNftContract(nftContract1.target)
      ).to.eq(true);
    });

    it("should revert on zero address", async () => {
      await expect(
        nftStaking.setWhiteListStatus(ethers.ZeroAddress, true)
      ).to.be.revertedWithCustomError(nftStaking, "NonZeroAddressNotAllowed");
    });

    it("should revert if not owner", async () => {
      await expect(
        nftStaking
          .connect(otherAccount)
          .setWhiteListStatus(nftContract1.target, true)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("setSpeedPerBlock", function () {
    it("should set the rewards speed", async () => {
      await expect(nftStaking.setSpeedPerBlock(parseUnits("2", 18)))
        .to.be.emit(nftStaking, "SpeedPerBlockUpdated")
        .withArgs(parseUnits("1", 18), parseUnits("2", 18));
      expect(await nftStaking.speedPerBlock()).to.eq(parseUnits("2", 18));
    });

    it("should revert if not owner", async () => {
      await expect(
        nftStaking.connect(otherAccount).setSpeedPerBlock(60)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("should update the contract reward index on setting new speed", async () => {
      const prevRewardIndexInfo = await nftStaking.rewardIndex();
      await nftStaking.setSpeedPerBlock(parseUnits("2", 18));
      const currRewardIndexInfo = await nftStaking.rewardIndex();

      // new index should be greater than the prev as it is updated
      expect(currRewardIndexInfo[0]).to.be.greaterThan(prevRewardIndexInfo[0]);

      // curr block number should be greater than the prev
      expect(currRewardIndexInfo[1]).to.be.greaterThan(prevRewardIndexInfo[1]);
    });
  });

  describe("stakeNFT", function () {
    it("should revert when zero nft address is passed", async () => {
      await expect(
        nftStaking.stakeNFT(ethers.ZeroAddress, 1)
      ).to.be.revertedWithCustomError(nftStaking, "NonZeroAddressNotAllowed");
    });

    it("should revert when staking is paused", async () => {
      await nftStaking.pause();
      await expect(
        nftStaking.stakeNFT(nftContract1.target, 1)
      ).to.be.revertedWith("Pausable: paused");
    });

    it("should revert when nft contract is not whitelisted", async () => {
      await expect(
        nftStaking.stakeNFT(nftContract2.target, 1)
      ).to.be.revertedWithCustomError(nftStaking, "NFTContractNotWhiteListed");
    });

    it("should revert when caller not owner of nft", async () => {
      await expect(nftStaking.stakeNFT(nftContract1.target, 1)).to.be.reverted;
    });

    it("should revert when contract not approved", async () => {
      await nftContract1.safeMint(await otherAccount.getAddress());
      await expect(
        nftStaking.connect(otherAccount).stakeNFT(nftContract1.target, 0)
      ).to.be.reverted;
    });

    it("should stake NFT successfully", async () => {
      await nftStaking.setWhiteListStatus(nftContract1.target, true);
      await nftContract1.safeMint(await otherAccount.getAddress());
      await nftContract1
        .connect(otherAccount)
        .setApprovalForAll(nftStaking.target, true);

      const prevInfo = await nftStaking.stakers(
        await otherAccount.getAddress()
      );
      // index = 0, rewards = 0, lastClaimedAt = 0, totalStaked = 0
      expect(prevInfo).to.deep.equal([0, 0, 0, 0]);
      // expect()
      await nftStaking.connect(otherAccount).stakeNFT(nftContract1.target, 0);

      const currInfo = await nftStaking.stakers(
        await otherAccount.getAddress()
      );

      expect(currInfo[0]).to.greaterThan(0);
      expect(currInfo[1]).to.be.equal(0);
      expect(currInfo[2]).to.be.equal(0);
      expect(currInfo[3]).to.be.equal(1);
      const stakedNFTs = await nftStaking.getStakedNFTsInfo(
        await otherAccount.getAddress()
      );

      expect(stakedNFTs.length).to.be.equal(1);
      expect(stakedNFTs[0].tokenId).to.be.equal(0);
      expect(stakedNFTs[0].unstakedAt).to.be.equal(0);
      expect(stakedNFTs[0].nftAddress).to.be.equal(nftContract1.target);

      expect(await nftContract1.ownerOf(0)).to.be.equal(nftStaking.target);

      await nftStaking.connect(otherAccount).updateUserRewardIndex();

      const updatedInfo = await nftStaking.stakers(
        await otherAccount.getAddress()
      );

      // index should increase
      expect(updatedInfo[0]).to.be.greaterThan(currInfo[0]);

      // rewards should increase
      expect(updatedInfo[1]).to.be.greaterThan(currInfo[1]);
    });
  });

  describe("unstakeNFT", function () {
    it("should revert if index is out of bounds", async () => {
      await expect(nftStaking.unstakeNFT(1)).to.be.revertedWithCustomError(
        nftStaking,
        "IndexOutOfBounds"
      );
    });

    it("should revert if nft is already unstaked", async () => {
      await setUpStakeNFT(otherAccount, 1);

      await nftStaking.connect(otherAccount).unstakeNFT(0);
      await expect(
        nftStaking.connect(otherAccount).unstakeNFT(0)
      ).to.be.revertedWithCustomError(nftStaking, "AlreadyUnstaked");
    });

    it("should unstake nft successfully", async () => {
      await setUpStakeNFT(otherAccount, 1);

      const totalNFTsStaked = await nftStaking.totalNFTsStaked();
      let info = await nftStaking.stakers(await otherAccount.getAddress());
      expect(info[3]).to.be.equal(1);

      await expect(nftStaking.connect(otherAccount).unstakeNFT(0))
        .to.be.emit(nftStaking, "NFTUnstaked")
        .withArgs(await otherAccount.getAddress(), nftContract1.target, 1, 0);

      expect(await nftStaking.totalNFTsStaked()).to.be.equal(
        totalNFTsStaked - BigInt(1)
      );

      info = await nftStaking.stakers(await otherAccount.getAddress());
      expect(info[3]).to.be.equal(0);

      const allNFTsInfo = await nftStaking.getStakedNFTsInfo(
        await otherAccount.getAddress()
      );
      expect(allNFTsInfo[0].unstakedAt).to.be.greaterThan(0);
    });
  });

  describe("claimRewards", function () {
    it("should revert if rewards are zero", async () => {
      await expect(nftStaking.claimRewards()).to.be.revertedWithCustomError(
        nftStaking,
        "ZeroRewardsToClaim"
      );
    });

    it("should revert if contract has insufficient balance", async () => {
      await setUpStakeNFT(otherAccount, 1);
      await mine(100);

      await expect(nftStaking.connect(otherAccount).claimRewards()).to.be
        .reverted;
    });

    it("should revert if delay period is not end", async () => {
      await setUpStakeNFT(otherAccount, 1);
      await expect(
        nftStaking.connect(otherAccount).claimRewards()
      ).to.be.revertedWithCustomError(nftStaking, "DelayPeriodNotEnd");
    });

    it("should be able to claim rewards", async () => {
      await rewardToken.mint(nftStaking.target, parseUnits("100000", 18));
      await setUpStakeNFT(otherAccount, 1);
      await mine(100);

      // rewards will be accrued by considering mined(100) + 1(for claimRewards tx)
      const totalRewards = (await nftStaking.speedPerBlock()) * BigInt(101);
      await expect(nftStaking.connect(otherAccount).claimRewards())
        .to.be.emit(nftStaking, "RewardsClaimed")
        .withArgs(await otherAccount.getAddress(), totalRewards);
      expect(
        await rewardToken.balanceOf(await otherAccount.getAddress())
      ).to.be.equal(totalRewards);

      await setUpStakeNFT(owner, 4);
      const blockNumberJustAfterOwnerAccountStake =
        await ethers.provider.getBlock("latest");
      await mine(100);

      // rewards will be accrued by considering mined(100) + 1(for claimRewards tx) and divided by 2 as
      // there are two staked nfts by two different users, so rewards will be divided among them
      // but there will be also some rewards which only belong to otherAccount accrued before staked of nft by owner account
      const totalRewardsNew =
        ((await nftStaking.speedPerBlock()) * BigInt(101)) / BigInt(2);
      await expect(nftStaking.connect(otherAccount).claimRewards()).to.be.emit(
        nftStaking,
        "RewardsClaimed"
      );

      // previous + new claimed
      expect(
        await rewardToken.balanceOf(await otherAccount.getAddress())
      ).to.be.greaterThan(totalRewards + totalRewardsNew);

      // 102 blocks are considered as 101 block was used by otherAccount for claiming rewards
      // and 102 will be used for claiming rewards by owner account
      const totalRewardsForOwnerAccount =
        ((await nftStaking.speedPerBlock()) * BigInt(102)) / BigInt(2);

      await expect(nftStaking.connect(owner).claimRewards())
        .to.be.emit(nftStaking, "RewardsClaimed")
        .withArgs(await owner.getAddress(), totalRewardsForOwnerAccount);

      expect(await rewardToken.balanceOf(await owner.getAddress())).to.be.equal(
        totalRewardsForOwnerAccount
      );
    });
  });

  describe("withdrawNFT", function () {
    it("should revert if NFT not unstaked", async () => {
      await setUpStakeNFT(otherAccount, 1);

      await expect(
        nftStaking.connect(otherAccount).withdrawNFT(0)
      ).to.be.revertedWithCustomError(nftStaking, "NFTNotUnstaked");
    });

    it("should revert if index is out of bounds", async () => {
      await expect(nftStaking.withdrawNFT(1)).to.be.revertedWithCustomError(
        nftStaking,
        "IndexOutOfBounds"
      );
    });

    it("should revert if unbounding period not end", async () => {
      await nftStaking.setUnboundingPeriod(100);
      await setUpStakeNFT(otherAccount, 1);

      await nftStaking.connect(otherAccount).unstakeNFT(0);

      await expect(
        nftStaking.connect(otherAccount).withdrawNFT(0)
      ).to.be.revertedWithCustomError(nftStaking, "UnboundingPeriodNotEnd");
    });

    it("should be able to withdraw NFT", async () => {
      await nftStaking.setUnboundingPeriod(100);
      await setUpStakeNFT(otherAccount, 1);
      await setUpStakeNFT(otherAccount, 2);
      await setUpStakeNFT(otherAccount, 3);
      await setUpStakeNFT(otherAccount, 4);

      const totalStakedNFTsBeforeUnstake = (
        await nftStaking.stakers(await otherAccount.getAddress())
      )[3];
      await nftStaking.connect(otherAccount).unstakeNFT(0);
      const totalStakedNFTsAfterUnstake = (
        await nftStaking.stakers(await otherAccount.getAddress())
      )[3];

      const stakedNFTsBeforeWithdraw = await nftStaking.getStakedNFTsInfo(
        await otherAccount.getAddress()
      );
      expect(totalStakedNFTsAfterUnstake).to.be.equal(
        totalStakedNFTsBeforeUnstake - BigInt(1)
      );
      await mine(100);
      await expect(nftStaking.connect(otherAccount).withdrawNFT(0)).to.be.emit(
        nftStaking,
        "NFTWithdrawn"
      );

      const totalStakedNFTsAfterWithdraw = (
        await nftStaking.stakers(await otherAccount.getAddress())
      )[3];

      const stakedNFTsAfterWithdraw = await nftStaking.getStakedNFTsInfo(
        await otherAccount.getAddress()
      );

      expect(totalStakedNFTsAfterWithdraw).to.be.equal(
        totalStakedNFTsAfterUnstake
      );

      expect(stakedNFTsAfterWithdraw.length).to.be.equal(
        stakedNFTsBeforeWithdraw.length - 1
      );

      expect(await nftContract1.ownerOf(1)).to.be.equal(
        await otherAccount.getAddress()
      );
    });
  });

  describe("Pause & Unpause", () => {
    it("Should revert if not owner", async () => {
      await expect(nftStaking.connect(otherAccount).pause()).to.be.revertedWith(
        "Ownable: caller is not the owner"
      );
      await expect(
        nftStaking.connect(otherAccount).unpause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should execute successfully", async () => {
      await nftStaking.pause();
      expect(await nftStaking.paused()).to.be.equal(true);

      await nftStaking.unpause();
      expect(await nftStaking.paused()).to.be.equal(false);
    });
  });
});
