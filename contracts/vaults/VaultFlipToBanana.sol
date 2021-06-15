// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

/*
*
* MIT License
* ===========
*
* Copyright (c) 2020 HunnyFinance
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

import "@openzeppelin/contracts/math/Math.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "../library/RewardsDistributionRecipientUpgradeable.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/IHunnyMinter.sol";
import "./VaultController.sol";
import "../interfaces/legacy/IStrategyHelper.sol";
import {PoolConstant} from "../library/PoolConstant.sol";


contract VaultFlipToBanana is VaultController, IStrategy, RewardsDistributionRecipientUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    /* ========== CONSTANTS ============= */

    address private constant BANANA = address(0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95);
    IMasterChef private constant BANANA_MASTER_CHEF = IMasterChef(0x5c8D727b265DBAfaba67E050f2f739cAeEB4A6F9);
    IStrategyHelper private constant STRATEGY_HELPER = IStrategyHelper(0x486B662A191E29cF767862ACE492c89A6c834fB4);
    PoolConstant.PoolTypes public constant override poolType = PoolConstant.PoolTypes.FlipToCake;

    /* ========== STATE VARIABLES ========== */

    IStrategy private _rewardsToken;

    uint public periodFinish;
    uint public rewardRate;
    uint public rewardsDuration;
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    uint private _totalSupply;
    mapping(address => uint) private _balances;

    uint public constant override pid = 1;
    mapping (address => uint) private _depositedAt;

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint reward);
    event RewardsDurationUpdated(uint newDuration);

    /* ========== INITIALIZER ========== */

    function initialize() external initializer {
        (address _token,,,) = BANANA_MASTER_CHEF.poolInfo(pid);
        __VaultController_init(IBEP20(_token));
        __RewardsDistributionRecipient_init();
        __ReentrancyGuard_init();

        _stakingToken.safeApprove(address(BANANA_MASTER_CHEF), uint(-1));

        rewardsDuration = 24 hours;

        rewardsDistribution = msg.sender;
        setMinter(0xf6F47e12C2BA03566aC90276eA76Daa9c8216E14);
        setRewardsToken(0xAD4134F59C5241d0B4f6189731AA2f7b279D4104);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view override returns (uint) {
        return _totalSupply;
    }

    function balance() override external view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function sharesOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function principalOf(address account) external view override returns (uint) {
        return _balances[account];
    }

    function depositedAt(address account) external view override returns (uint) {
        return _depositedAt[account];
    }

    function withdrawableBalanceOf(address account) public view override returns (uint) {
        return _balances[account];
    }

    function rewardsToken() external view override returns (address) {
        return address(_rewardsToken);
    }

    function priceShare() external view override returns(uint) {
        return 1e18;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
        );
    }

    function earned(address account) override public view returns (uint) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    // helper function returns reward in cake + hunny
    function profitOf(address account) public view returns (uint _cake, uint _hunny) {
        uint amount = earned(account);

        if (canMint()) {
            uint performanceFee = _minter.performanceFee(amount);
            // cake amount
            _cake = amount.sub(performanceFee);

            uint bnbValue = STRATEGY_HELPER.tvlInBNB(address(BANANA), performanceFee);
            // hunny amount
            _hunny = _minter.amountHunnyToMint(bnbValue);
        } else {
            _cake = amount;
            _hunny = 0;
        }
    }

    function getRewardForDuration() external view returns (uint) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(uint amount) override public {
        _deposit(amount, msg.sender);
    }

    function depositAll() override external {
        deposit(_stakingToken.balanceOf(msg.sender));
    }

    function withdraw(uint amount) override public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "VaultFlipToBanana: amount must be greater than zero");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        uint bananaHarvested = _withdrawStakingToken(amount);
        uint withdrawalFee;
        if (canMint()) {
            uint depositTimestamp = _depositedAt[msg.sender];
            withdrawalFee = _minter.withdrawalFee(amount, depositTimestamp);
            if (withdrawalFee > 0) {
                uint performanceFee = withdrawalFee.div(100);
                _minter.mintFor(address(_stakingToken), withdrawalFee.sub(performanceFee), performanceFee, msg.sender, depositTimestamp);
                amount = amount.sub(withdrawalFee);
            }
        }

        _stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, withdrawalFee);

        _harvest(bananaHarvested);
    }

    function withdrawAll() external override {
        uint _withdraw = withdrawableBalanceOf(msg.sender);
        if (_withdraw > 0) {
            withdraw(_withdraw);
        }
        getReward();
    }

    function getReward() public override nonReentrant updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            uint before = IBEP20(BANANA).balanceOf(address(this));
            _rewardsToken.withdraw(reward);
            uint bananaBalance = IBEP20(BANANA).balanceOf(address(this)).sub(before);
            uint performanceFee;

            if (canMint()) {
                performanceFee = _minter.performanceFee(bananaBalance);
                _minter.mintFor(BANANA, 0, performanceFee, msg.sender, _depositedAt[msg.sender]);
            }

            IBEP20(BANANA).safeTransfer(msg.sender, bananaBalance.sub(performanceFee));
            emit ProfitPaid(msg.sender, bananaBalance, performanceFee);
        }
    }

    function harvest() public override {
        uint bananaHarvested = _withdrawStakingToken(0);
        _harvest(bananaHarvested);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setMinter(address newMinter) override public onlyOwner {
        VaultController.setMinter(newMinter);
        if (newMinter != address(0)) {
            IBEP20(BANANA).safeApprove(newMinter, 0);
            IBEP20(BANANA).safeApprove(newMinter, uint(-1));
        }
    }

    function setRewardsToken(address newRewardsToken) public onlyOwner {
        require(address(_rewardsToken) == address(0), "VaultFlipToBanana: rewards token already set");

        _rewardsToken = IStrategy(newRewardsToken);
        IBEP20(BANANA).safeApprove(newRewardsToken, 0);
        IBEP20(BANANA).safeApprove(newRewardsToken, uint(~0));
    }

    function notifyRewardAmount(uint reward) public override onlyRewardsDistribution {
        _notifyRewardAmount(reward);
    }

    function setRewardsDuration(uint _rewardsDuration) external onlyOwner {
        require(periodFinish == 0 || block.timestamp > periodFinish, "VaultFlipToBanana: reward duration can only be updated after the period ends");
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _deposit(uint amount, address _to) private nonReentrant notPaused updateReward(_to) {
        require(amount > 0, "VaultFlipToBanana: amount must be greater than zero");
        _totalSupply = _totalSupply.add(amount);
        _balances[_to] = _balances[_to].add(amount);
        _depositedAt[_to] = block.timestamp;
        _stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        uint bananaHarvested = _depositStakingToken(amount);
        emit Deposited(_to, amount);
        _harvest(bananaHarvested);
    }
    function _depositStakingToken(uint amount) private returns (uint bananaHarvested) {
        uint before = IBEP20(BANANA).balanceOf(address(this));
        BANANA_MASTER_CHEF.deposit(pid, amount);
        bananaHarvested = IBEP20(BANANA).balanceOf(address(this)).sub(before);
    }
    function _withdrawStakingToken(uint amount) private returns (uint bananaHarvested) {
        uint before = IBEP20(BANANA).balanceOf(address(this));
        BANANA_MASTER_CHEF.withdraw(pid, amount);
        bananaHarvested = IBEP20(BANANA).balanceOf(address(this)).sub(before);
    }

    function _harvest(uint bananaAmount) private {
        uint _before = _rewardsToken.sharesOf(address(this));
        _rewardsToken.deposit(bananaAmount);
        uint amount = _rewardsToken.sharesOf(address(this)).sub(_before);
        if (amount > 0) {
            _notifyRewardAmount(amount);
            emit Harvested(amount);
        }
    }

    function _notifyRewardAmount(uint reward) private updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint remaining = periodFinish.sub(block.timestamp);
            uint leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint _balance = _rewardsToken.sharesOf(address(this));
        require(rewardRate <= _balance.div(rewardsDuration), "VaultFlipToBanana: reward rate must be in the right range");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    /* ========== SALVAGE PURPOSE ONLY ========== */

    function recoverToken(address tokenAddress, uint tokenAmount) external override onlyOwner {
        require(tokenAddress != address(_stakingToken) && tokenAddress != _rewardsToken.stakingToken(), "VaultFlipToBanana: cannot recover underlying token");
        IBEP20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
}
