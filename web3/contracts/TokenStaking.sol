// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./Initializable.sol";
import "./IERC20.sol";

contract TokenStaking is Ownable, ReentrancyGuard, Initializable {
    // Struct to store the User's details
    struct User {
        uint256 stakeAmount; // Stake amount
        uint256 rewardAmount; // Reward amount
        uint256 lastStakeTime; // last stake timestamp
        uint256 lastRewardCalculationTime; // last reward calculation timestamp
        uint256 rewardsClaimedSoFar; // Sum of rewards claimed so far
    }
}