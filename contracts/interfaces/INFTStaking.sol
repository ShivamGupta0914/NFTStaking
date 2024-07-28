// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface INFTStaking {
    /**
     * @notice Represents information about a staked NFT.
     * @param tokenId The ID of the staked NFT.
     * @param unstakedAt The block number at which the NFT was unstaked.
     * @param nftAddress The address of the NFT contract.
     */
    struct StakedNFTInfo {
        uint256 tokenId;
        uint256 unstakedAt;
        address nftAddress;
    }

    /**
     * @notice Represents information about a staker.
     * @param userRewardIndex The index used to calculate the staker's rewards.
     * @param rewardsAccrued The amount of rewards accrued by the staker.
     * @param lastClaimedAt The block number at which the staker last claimed rewards.
     * @param totalStakedNFTs The total number of NFTs staked by the staker.
     * @param nftsInfo An array of staked NFT information.
     */
    struct StakerInfo {
        uint256 userRewardIndex;
        uint256 rewardsAccrued;
        uint256 lastClaimedAt;
        uint256 totalStakedNFTs;
        StakedNFTInfo[] nftsInfo;
    }

    /**
     * @notice Represents the reward index information.
     * @param index The current reward index.
     * @param block The block number at which the reward index was last updated.
     */
    struct RewardIndex {
        uint256 index;
        uint256 block;
    }

    /**
     * @notice Thrown when an operation attempts to access an array with an out-of-bounds index.
     */
    error IndexOutOfBounds();

    /**
     * @notice Thrown when attempting to unstake an NFT that is not unstaked.
     */
    error NFTNotUnstaked();

    /**
     * @notice Thrown when attempting to withdraw an NFT before the unbounding period has ended.
     */
    error UnboundingPeriodNotEnd();

    /**
     * @notice Thrown when attempting to claim rewards before the delay period has ended.
     */
    error DelayPeriodNotEnd();

    /**
     * @notice Thrown when there is a mismatch in the expected and actual array lengths.
     */
    error LengthMisMatch();

    /**
     * @notice Thrown when the NFT contract is not whitelisted.
     */
    error NFTContractNotWhiteListed();

    /**
     * @notice Thrown when the caller is not the holder of the specified NFT.
     */
    error CallerNotNFTHolder();

    /**
     * @notice Thrown when attempting to unstake an NFT that is already unstaked.
     */
    error AlreadyUnstaked();

    /**
     * @notice Thrown when attempting to set a zero address where a non-zero address is required.
     */
    error NonZeroAddressNotAllowed();

    /**
     * @notice Thrown when attempting to claim rewards but there are no rewards to claim.
     */
    error ZeroRewardsToClaim();

    /**
     * @notice Emitted when the whitelisted status of an NFT contract is updated.
     * @param contractAddress The address of the NFT contract.
     * @param isWhiteListed The new whitelisted status.
     */
    event WhiteListedStatusUpdated(
        address indexed contractAddress,
        bool isWhiteListed
    );

    /**
     * @notice Emitted when the speed per block for rewards is updated.
     * @param oldSpeed The old speed per block.
     * @param newSpeed The new speed per block.
     */
    event SpeedPerBlockUpdated(
        uint256 indexed oldSpeed,
        uint256 indexed newSpeed
    );

    /**
     * @notice Emitted when the delay period for claiming rewards is updated.
     * @param oldDelayPeriod The old delay period.
     * @param newDelayPeriod The new delay period.
     */
    event DelayPeriodUpdated(
        uint256 indexed oldDelayPeriod,
        uint256 indexed newDelayPeriod
    );

    /**
     * @notice Emitted when the unbounding period for withdrawing NFTs is updated.
     * @param oldUnboundingPeriod The old unbounding period.
     * @param newUnboundingPeriod The new unbounding period.
     */
    event UnboundingPeriodUpdated(
        uint256 indexed oldUnboundingPeriod,
        uint256 indexed newUnboundingPeriod
    );

    /**
     * @notice Emitted when an NFT is staked.
     * @param user The address of the staker.
     * @param nftContract The address of the NFT contract.
     * @param id The ID of the staked NFT.
     * @param totalNFTsStaked The total number of NFTs staked by the user.
     */
    event NFTStaked(
        address indexed user,
        address indexed nftContract,
        uint256 indexed id,
        uint256 totalNFTsStaked
    );

    /**
     * @notice Emitted when an NFT is unstaked.
     * @param user The address of the staker.
     * @param nftContract The address of the NFT contract.
     * @param id The ID of the unstaked NFT.
     * @param totalNFTsStaked The total number of NFTs staked by the user.
     */
    event NFTUnstaked(
        address indexed user,
        address indexed nftContract,
        uint256 indexed id,
        uint256 totalNFTsStaked
    );

    /**
     * @notice Emitted when an NFT is withdrawn.
     * @param user The address of the staker.
     * @param nftContract The address of the NFT contract.
     * @param id The ID of the withdrawn NFT.
     */
    event NFTWithdrawn(
        address indexed user,
        address indexed nftContract,
        uint256 indexed id
    );

    /**
     * @notice Emitted when rewards are claimed.
     * @param user The address of the staker.
     * @param amount The amount of rewards claimed.
     */
    event RewardsClaimed(address indexed user, uint256 amount);
}
