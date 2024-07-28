// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {SafeERC20Upgradeable, IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {INFTStaking} from "contracts/interfaces/INFTStaking.sol";

contract NFTStaking is
    INFTStaking,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice The amount of reward tokens distributed per block.
     */
    uint256 public speedPerBlock;

    /**
     * @notice The period in blocks that must pass between successive reward claims.
     */
    uint256 public delayPeriod;

    /**
     * @notice The period in blocks that must pass after unstaking an NFT before it can be withdrawn.
     */
    uint256 public unboundingPeriod;

    /**
     * @notice The total number of NFTs currently staked in the contract.
     */
    uint256 public totalNFTsStaked;

    /**
     * @notice The current reward index and the block number when it was last updated.
     */
    RewardIndex public rewardIndex;

    /**
     * @notice The ERC20 token used for rewards.
     */
    IERC20Upgradeable public rewardToken;

    /**
     * @notice Stores information about each staker.
     */
    mapping(address user => StakerInfo stakersInfo) public stakers;

    /**
     * @notice Stores whether a specific NFT contract address is whitelisted.
     */
    mapping(address nftContractAddress => bool isWhiteListed)
        public isWhiteListedNftContract;

    /**
     * @dev Ensures the index is within the length of the NFTs staked by the user.
     * @param _index The index to check.
     */
    modifier indexWithinLength(uint256 _index) {
        if (_index >= stakers[msg.sender].nftsInfo.length)
            revert IndexOutOfBounds();
        _;
    }

    /**
     * @dev Ensures the provided address is not zero.
     * @param _addr The address to check.
     */
    modifier nonZeroAddress(address _addr) {
        if (_addr == address(0)) revert NonZeroAddressNotAllowed();
        _;
    }

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        // Note that the contract is upgradeable. Use initialize() or reinitializers
        // to set the state variables.
        _disableInitializers();
    }

    /**
     * @notice Initializes the NFTStaking contract.
     * @param _rewardToken The address of the reward token contract.
     * @param _initialSpeed The initial speed of rewards per block.
     */
    function initialize(
        address _rewardToken,
        uint256 _initialSpeed
    ) external initializer {
        rewardToken = IERC20Upgradeable(_rewardToken);
        speedPerBlock = _initialSpeed;
        rewardIndex.block = block.number;

        __Ownable2Step_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    /**
     * @notice Allows an user to stake an NFT.
     * @param _nftContractAddress The address of the NFT contract.
     * @param _tokenId The ID of the token to stake.
     * @custom:error NonZeroAddressNotAllowed is thrown if the provided address is zero.
     * @custom:error NFTContractNotWhiteListed is thrown if the NFT contract is not whitelisted.
     * @custom:event NFTStaked Emitted when an NFT is staked.
     */
    function stakeNFT(
        address _nftContractAddress,
        uint256 _tokenId
    ) external nonZeroAddress(_nftContractAddress) whenNotPaused {
        if (!isWhiteListedNftContract[_nftContractAddress])
            revert NFTContractNotWhiteListed();

        updateUserRewardIndex();

        stakers[msg.sender].totalStakedNFTs += 1;
        stakers[msg.sender].nftsInfo.push(
            StakedNFTInfo({
                tokenId: _tokenId,
                unstakedAt: 0,
                nftAddress: _nftContractAddress
            })
        );

        unchecked {
            ++totalNFTsStaked;
        }

        IERC721Upgradeable(_nftContractAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit NFTStaked(
            msg.sender,
            _nftContractAddress,
            _tokenId,
            totalNFTsStaked
        );
    }

    /**
     * @notice Allows an user to unstake their NFT.
     * @param _index The index of the NFT to be unstaked.
     * @custom:event NFTUnstaked emits when an NFT is successfully unstaked.
     * @custom:error IndexOutOfBounds is thrown if the provided index is out of bounds.
     * @custom:error AlreadyUnstaked is thrown if the NFT is already unstaked.
     */
    function unstakeNFT(uint256 _index) external indexWithinLength(_index) {
        (address nftAddress, uint256 tokenId) = _verifyNFTStakeStatus(_index);

        updateUserRewardIndex();

        stakers[msg.sender].totalStakedNFTs -= 1;
        stakers[msg.sender].nftsInfo[_index].unstakedAt = block.number;

        unchecked {
            --totalNFTsStaked;
        }
        emit NFTUnstaked(msg.sender, nftAddress, tokenId, totalNFTsStaked);
    }

    /**
     * @notice Withdraws a staked NFT after the unbounding period has ended.
     * @dev This function checks if the NFT has been unstaked and if the unbounding period
     *      has ended before allowing the withdrawal. The NFT is then removed from the staker's
     *      array and transferred back to the staker.
     * @param _index The index of the NFT in the staker's staked NFTs array.
     * @custom:error NFTNotUnstaked is thrown if the NFT has not been unstaked.
     * @custom:error UnboundingPeriodNotEnd is thrown if the unbounding period has not yet ended.
     * @custom:event NFTWithdrawn Emits when an NFT is successfully withdrawn.
     */
    function withdrawNFT(
        uint256 _index
    ) external indexWithinLength(_index) nonReentrant {
        StakedNFTInfo memory info = stakers[msg.sender].nftsInfo[_index];

        uint256 unstakedBlock = info.unstakedAt;
        if (unstakedBlock == 0) revert NFTNotUnstaked();
        if (block.number - unstakedBlock < unboundingPeriod)
            revert UnboundingPeriodNotEnd();

        (address nftAddress, uint256 tokenId) = _deleteNFTInfoAtIndex(_index);
        IERC721Upgradeable(info.nftAddress).transferFrom(
            address(this),
            msg.sender,
            info.tokenId
        );

        emit NFTWithdrawn(msg.sender, nftAddress, tokenId);
    }

    /**
     * @notice Claims accrued rewards for the caller.
     * @dev This function updates the contract and user reward indices before
     *      transferring the accrued rewards to the caller. The function is protected
     *      by a delay period to prevent frequent claims.
     * @custom:error DelayPeriodNotEnd is thrown if the delay period has not yet ended.
     * @custom:error ZeroRewardsToClaim is thrown if there are no rewards to claim.
     * @custom:event RewardsClaimed Emits when rewards are successfully claimed.
     */
    function claimRewards() external nonReentrant {
        if (block.number - stakers[msg.sender].lastClaimedAt < delayPeriod)
            revert DelayPeriodNotEnd();

        updateUserRewardIndex();
        uint256 totalAmount = stakers[msg.sender].rewardsAccrued;

        if (totalAmount == 0) revert ZeroRewardsToClaim();
        delete stakers[msg.sender].rewardsAccrued;
        stakers[msg.sender].lastClaimedAt = block.number;
        rewardToken.safeTransfer(msg.sender, totalAmount);

        emit RewardsClaimed(msg.sender, totalAmount);
    }

    /**
     * @notice Triggers stopped state of the bridge.
     * @custom:access Only owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Triggers resume state of the bridge.
     * @custom:access Only owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Sets a new speed at which rewards are distributed per block.
     * @dev This function updates the contract's reward index before setting the new speed.
     * @param _newSpeed The new speed at which rewards will be distributed per block.
     * @custom:event SpeedPerBlockUpdated Emits when the speed per block is updated.
     * @custom:access Only callable by the contract owner.
     */
    function setSpeedPerBlock(uint256 _newSpeed) external onlyOwner {
        _updateContractRewardIndex();

        emit SpeedPerBlockUpdated(speedPerBlock, _newSpeed);
        speedPerBlock = _newSpeed;
    }

    /**
     * @notice Sets a new delay period for reward claims.
     * @param _newDelayPeriod The new delay period.
     * @custom:event DelayPeriodUpdated Emits when the delay period is updated.
     * @custom:access Only callable by the contract owner.
     */
    function setDelayPeriod(uint256 _newDelayPeriod) external onlyOwner {
        emit DelayPeriodUpdated(delayPeriod, _newDelayPeriod);
        delayPeriod = _newDelayPeriod;
    }

    /**
     * @notice Sets new unbounding period for NFT withdraw.
     * @param _newUnboundingPeriod The new unbounding period.
     * @custom:event UnboundingPeriodUpdated Emits when the unbounding period is updated.
     * @custom:access Only callable by the contract owner.
     */
    function setUnboundingPeriod(
        uint256 _newUnboundingPeriod
    ) external onlyOwner {
        emit UnboundingPeriodUpdated(unboundingPeriod, _newUnboundingPeriod);
        unboundingPeriod = _newUnboundingPeriod;
    }

    /**
     * @notice Updates the whitelist status of an NFT contract.
     * @param _nftContract The address of the NFT contract.
     * @param _isWhiteListed The whitelist status to set.
     * @custom:event WhiteListedStatusUpdated emits on success.
     * @custom:error NonZeroAddressNotAllowed is thrown if the provided address is zero.
     */
    function setWhiteListStatus(
        address _nftContract,
        bool _isWhiteListed
    ) external onlyOwner nonZeroAddress(_nftContract) {
        isWhiteListedNftContract[_nftContract] = _isWhiteListed;
        emit WhiteListedStatusUpdated(_nftContract, _isWhiteListed);
    }

    /**
     * @notice Retrieves the information of staked NFTs for a user.
     * @param _user The address of the user.
     * @return An array of StakedNFTInfo structs.
     */
    function getStakedNFTsInfo(
        address _user
    ) external view returns (StakedNFTInfo[] memory) {
        return stakers[_user].nftsInfo;
    }

    /**
     * @notice Updates the user's reward index to the latest contract reward index.
     * @dev This function first updates the contract's reward index, then updates
     *      the user's reward index and accrued rewards.
     */
    function updateUserRewardIndex() public {
        _updateContractRewardIndex();
        _updateUserRewardIndex();
    }

    /**
     * @dev Updates the reward index for the user and calculates accrued rewards.
     * @dev This function updates the user's reward index to the latest contract reward index
     *      and calculates the rewards accrued since the last update.
     */
    function _updateUserRewardIndex() private {
        StakerInfo memory info = stakers[msg.sender];

        uint256 userIndex = info.userRewardIndex;
        if (userIndex == 0) {
            userIndex = rewardIndex.index;
        }

        uint256 deltaIndex = rewardIndex.index - userIndex;
        uint256 rewardsAccrued = deltaIndex * info.totalStakedNFTs;
        stakers[msg.sender].rewardsAccrued += rewardsAccrued;
        stakers[msg.sender].userRewardIndex = rewardIndex.index;
    }

    /**
     * @dev Updates the global reward index for the contract.
     * @dev This function updates the global reward index based on the number of blocks
     *      that have passed since the last update and the speed at which rewards are distributed per block.
     */
    function _updateContractRewardIndex() private {
        uint256 deltaBlocks = block.number - rewardIndex.block;

        uint256 indexToIncrease = deltaBlocks * speedPerBlock;

        uint256 totalStaked = totalNFTsStaked;
        if (totalStaked == 0) totalStaked = 1;

        rewardIndex.index += indexToIncrease / totalStaked;
        rewardIndex.block = block.number;
    }

    /**
     * @dev Deletes an NFT info at a specific index from the staker's staked NFT info array.
     * @param _index The index of the NFT info to be deleted.
     * @return nftAddress The address of the NFT contract.
     * @return tokenId The ID of the token.
     */
    function _deleteNFTInfoAtIndex(
        uint256 _index
    ) private returns (address, uint256) {
        StakedNFTInfo[] storage nftsInfo = stakers[msg.sender].nftsInfo;
        address nftAddress = nftsInfo[_index].nftAddress;
        uint256 tokenId = nftsInfo[_index].tokenId;
        uint256 length = nftsInfo.length;

        // Shift elements to the left to overwrite the element to be deleted
        for (uint256 i = _index; i < length - 1; ) {
            nftsInfo[i] = nftsInfo[i + 1];
            unchecked {
                ++i;
            }
        }

        // Remove the last element
        nftsInfo.pop();

        return (nftAddress, tokenId);
    }

    /**
     * @dev Verifies the staking status of an NFT at a given index.
     * @dev This function reverts if the NFT at the specified index has already been unstaked.
     * @param index The index of the NFT info to be verified.
     * @return nftAddress The address of the NFT contract.
     * @return tokenId The ID of the token.
     */
    function _verifyNFTStakeStatus(
        uint256 index
    ) private view returns (address, uint256) {
        StakedNFTInfo memory info = stakers[msg.sender].nftsInfo[index];
        if (info.unstakedAt != 0) revert AlreadyUnstaked();

        return (info.nftAddress, info.tokenId);
    }
}
