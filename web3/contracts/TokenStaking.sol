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

    uint256 _minimumStakingAmount;
    uint256 _maxStakeTokenLimit;
    uint256 _stakeEndDate;
    uint256 _stakeStartDate;
    uint256 _totalStakedTokens;
    uint256 _totaluser;
    uint256 _stakeDays;

    uint256 _earlyUnstakeFeePercentage;
    bool _isStakingPaused;

    // Token Contract address
    address private _tokenAddress;

    // APY
    uint256 _apyRate;

    uint256 public constant PERCENTAGE_DENOMINATOR = 1000;
    uint256 public constant APY_RATE_CHANGE_THRESHOLD = 10;

    // user address => User
    mapping(address => User) private _user;

    event Stake(address indexed user, uint256 amount);
    event UnStake(address indexed user, uint256 amount);
    event EarlyUnStakeFee(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    modifier whenTreasuryHasBalance (uint256 amount){
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) > amount, "TokenStaking: insufficient funds in the treasury"
        );
        _;
    }

    function initialize(
        address owner_,
        address tokenAddress_,
        uint256 apyRate_,
        uint256 minimumStakingAmount_,
        uint256 maxStakeTokenLimit,
        uint256 stakeStartDate_,
        uint256 stakeEndDate_,
        uint256 stakeDays_,
        uint256 earlyUnstakeFeePercentage_
    ) public virtual initializer {
        __TokenStaking_init_unchained(
             owner_,
             tokenAddress_,
             apyRate_,
             minimumStakingAmount_,
             maxStakeTokenLimit,
             stakeStartDate_,
             stakeEndDate_,
             stakeDays_,
             earlyUnstakeFeePercentage_
        );
    }

    function __TokenStaking_init_unchained(
        address owner_,
        address tokenAddress_,
        uint256 apyRate_,
        uint256 minimumStakingAmount_,
        uint256 maxStakeTokenLimit_,
        uint256 stakeStartDate_,
        uint256 stakeEndDate_,
        uint256 stakeDays_,
        uint256 earlyUnstakeFeePercentage_
    ) internal onlyInitializing {
        require(apyRate_ <= 10000, "TokenStaking:apy rate should be less than 10000");
        require(stakeDays_ > 0, "TokenStaking: Stakedays should not be zero");
        require(tokenAddress_ != address (0), "TokenStaking: token address should not be zero");
        require(stakeStartDate_ < stakeEndDate_, "TokenStaking: start date must be less than end date");

        _transferOwnership(owner_);
        _tokenAddress = tokenAddress_;
        _apyRate = apyRate_;
        _minimumStakingAmount = minimumStakingAmount_;
        _maxStakeTokenLimit = maxStakeTokenLimit_;
        _stakeEndDate = stakeEndDate_;
        _stakeStartDate = stakeStartDate_ ;
        _totalStakedTokens = totalStakedTokens_;
        _earlyUnstakeFeePercentage = earlyUnstakeFeePercentage_;
        _stakeDays = stakeDays_ * 1 days;
    }

    /* View methods start */

    /**
    * @notice this function is used to get minimum staking amount
    */
    function getMinimumStakingAmount() external view returns (uint256){
        return _minimumStakingAmount;
    }

    /**
   * @notice this function is used to get max limit amount
   */
    function getMaximumStakingLimit() external view returns (uint256){
        return _maxStakeTokenLimit;
    }

    /**
   * @notice this function is used to get the staking start date
   */
    function getStakingStartDate() external view returns (uint256){
        return _stakeStartDate;
    }

    /**
     * @notice this function is used to get the staking end date
    */
    function getStakeEndDate() external view returns (uint256){
        return _stakeEndDate;
    }

    /**
    * @notice this function is used to get the total staked tokens
    */
    function getTotalStakedTokens() external view returns (uint256){
        return _totalStakedTokens;
    }


    /**
    * @notice this function is used to get the total users
    */
    function getTotalUsers() external view returns (uint256){
        return _totaluser;
    }

    /**
    * @notice this function is used to get the stake days
    */
    function getStakeDays() external view returns (uint256){
        return _stakeDays;
    }

    /**
    * @notice this function is used to get early unstaked fee percentage
    */
    function getEarlyUnstakedFeePrecentage() external view returns (uint256){
        return _earlyUnstakeFeePercentage;
    }

    /**
    * @notice this function is used to get staking status
    */
    function getStakingStatus() external view returns (uint256){
        return _isStakingPaused;
    }

    /**
   * @notice this function is used to get current APY Rate
   * @return Current APY Rate
   */
    function getAPY() external view returns (uint256){
        return _apyRate;
    }

    /**
   * @notice this function is used to get user estimated reward amount
   * @return msg.sender reward amount
   */
    function getUserEstimatedRewards() external view returns (uint256){
        (uint256 amount, ) = _getUserEstimatedRewards(msg.sender);
        return _users[msg.sender].rewardAmount + amount;
    }

    /**
   * @notice this function is used to get withdrawable amount from contract
   */
    function getWithdrawableAmount() external view returns (uint256){
        return IERC20(_tokenAddress).balanceOf(address (this)) - _totalStakedTokens;
    }

    function getUser(address userAddress) external view returns (User memory) {
        return _users[userAddress];
    }

    function isStakingHolder(address userAddress) external view returns (bool){
        return _users[userAddress].stakeAmount != 0;
    }

    /* View methods end */

    /* Owner methods starts */


    /**
      * @notice this function is used to update minimum staking amount by owner only
      */
    function updateMinimumStakingAmount(uint256 newAmount) external onlyOwner {
        _minimumStakingAmount = newAmount;
    }

    /**
      * @notice this function is used to update max staking amount by owner only
      */
    function updateMaximumStakingAmount(uint256 newAmount) external onlyOwner {
        _maxStakeTokenLimit = newAmount;
    }

    /**
     * @notice this function is used to update staking end date by owner only
     */
    function updateStakingEndDate(uint256 newDate) external onlyOwner {
        _stakeEndDate = newDate;
    }

    function updateEarlyUnstakeFeePercentage(uint256 newPercentage) external onlyOwner {
        _earlyUnstakeFeePercentage = newPercentage;
    }

    function stakeForUser(uint256 amount, address user) onlyOwner nonReentrant {
        _stakeTokens(amount, user);
    }

    function toggleStakingStatus() external onlyOwner {
        _isStakingPaused = !_isStakingPaused;
    }

    function withdraw(uint256 amount) external onlyOwner  nonReentrant {
        require(this.getWithdrawableAmount() >= amount, "Tokenstaking: not enough withdrawable tokens");
        IERC20(_tokenAddress).transfer(msg.sender, amount);
    }

    /* Owner Methods ends */

    /* User methods starts */

    function stake(uint256 _amount) external nonReentrant {
        _stakeTokens(_amount, msg.sender);
    }

    function _stakeTokens(uint256 _amount, address user_) private  {
        require(!_isStakingPaused, "Tokenstaking: staking is paused");
        uint256 currentTime = getCurrentTime();
        require(currentTime > _stakeStartDate, "Tokenstaking: staking not started yet");
        require(currentTime < _stakeEndDate, "Tokenstaking: staking ended");
        require(_totalStakedTokens + _amount <= _maxStakeTokenLimit, "Tokenstaking: max staking token limit reached");
        require(_amount > 0, "Tokenstaking: must be above zero");
        require(
            _amount >= _minimumStakingAmount,
            "Tokenstaking: stake amount must be greater than minimum amount allowed"
        );

        if(_users[user_].stakeAmount != 0) {
            _calculateRewards(user_);
        } else {
            _users[user_].lastRewardCalculationTime = currentTime;
            _totaluser += 1;
        }

        _users[user_].stakeAmount += _amount;
        _users[user_].lastStakeTime = currentTime;

        _totalStakedTokens += _amount;

        require(
            IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount), "TokenStaking: failed to transfer tokens"
        );

        emit Stake(user_, _amount);
    }

}