// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";

import "./PancakeSwap.sol";
import "../../Constants.sol";
import "../../interfaces/IHunnyMinter.sol";
import "../../interfaces/IHunnyOracle.sol";
import "../../interfaces/legacy/IStakingRewards.sol";
import "../../interfaces/legacy/IStrategyHelper.sol";

contract HunnyMinter is IHunnyMinter, Ownable, PancakeSwap {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    BEP20 private hunny;
    address public dev = Constants.HUNNY_DEPLOYER;
    IBEP20 private WBNB = IBEP20(Constants.WBNB);

    uint public override WITHDRAWAL_FEE_FREE_PERIOD = 3 days;
    uint public override WITHDRAWAL_FEE = 50;
    uint public constant FEE_MAX = 10000;

    uint public PERFORMANCE_FEE = 3000; // 30%

    uint public override hunnyPerProfitBNB;
    uint public override hunnyPerBlockLottery;
    uint public lastLotteryMintBlock;
    uint public hunnyPerHunnyBNBFlip;

    address public hunnyPool;
    address public lotteryPool;
    IHunnyOracle public oracle;
    IStrategyHelper public helper;

    mapping (address => bool) private _minters;

    modifier onlyMinter {
        require(isMinter(msg.sender) == true, "not minter");
        _;
    }

    constructor(address _hunny, address _hunnyPool, address _lotteryPool, address _oracle, address _helper) PancakeSwap(_hunny) public {
        hunny = BEP20(_hunny);
        hunnyPool = _hunnyPool;
        lotteryPool = _lotteryPool;
        oracle = IHunnyOracle(_oracle);
        helper = IStrategyHelper(_helper);

        hunnyPerProfitBNB = Constants.HUNNY_PER_PROFIT_BNB;
        hunnyPerBlockLottery = Constants.HUNNY_PER_BLOCK_LOTTERY;
        lastLotteryMintBlock = block.number;
        hunnyPerHunnyBNBFlip = Constants.HUNNY_PER_HUNNY_BNB_FLIP;
        hunny.approve(hunnyPool, uint(~0));
    }

    function transferHunnyOwner(address _owner) external onlyOwner {
        Ownable(address(hunny)).transferOwnership(_owner);
    }

    function setWithdrawalFee(uint _fee) external onlyOwner {
        require(_fee < 500, "wrong fee");   // less 5%
        WITHDRAWAL_FEE = _fee;
    }

    function setPerformanceFee(uint _fee) external onlyOwner {
        require(_fee < 5000, "wrong fee");
        PERFORMANCE_FEE = _fee;
    }

    function setWithdrawalFeeFreePeriod(uint _period) external onlyOwner {
        WITHDRAWAL_FEE_FREE_PERIOD = _period;
    }

    function setMinter(address minter, bool canMint) external override onlyOwner {
        if (canMint) {
            _minters[minter] = canMint;
        } else {
            delete _minters[minter];
        }
    }

    function setHunnyPerProfitBNB(uint _ratio) external onlyOwner {
        hunnyPerProfitBNB = _ratio;
    }

    function setHunnyPerHunnyBNBFlip(uint _hunnyPerHunnyBNBFlip) external onlyOwner {
        hunnyPerHunnyBNBFlip = _hunnyPerHunnyBNBFlip;
    }

    function setHunnyPerBlockLottery(uint _hunnyPerBlockLottery) external onlyOwner {
        hunnyPerBlockLottery = _hunnyPerBlockLottery;
    }

    function setHelper(IStrategyHelper _helper) external onlyOwner {
        require(address(_helper) != address(0), "zero address");
        helper = _helper;
    }

    function setOracle(IHunnyOracle _oracle) external onlyOwner {
        require(address(_oracle) != address(0), "zero address");
        oracle = _oracle;
    }

    function isMinter(address account) override view public returns(bool) {
        if (hunny.getOwner() != address(this)) {
            return false;
        }

        if (block.timestamp < 1605585600) { // 12:00 SGT 17th November 2020
            return false;
        }
        return _minters[account];
    }

    function amountHunnyToMint(uint bnbProfit) override view public returns(uint) {
        return bnbProfit.mul(hunnyPerProfitBNB).div(1e18);
    }

    function amountHunnyToMintForHunnyBNB(uint amount, uint duration) override view public returns(uint) {
        return amount.mul(hunnyPerHunnyBNBFlip).mul(duration).div(365 days).div(1e18);
    }

    function withdrawalFee(uint amount, uint depositedAt) override view external returns(uint) {
        if (depositedAt.add(WITHDRAWAL_FEE_FREE_PERIOD) > block.timestamp) {
            return amount.mul(WITHDRAWAL_FEE).div(FEE_MAX);
        }
        return 0;
    }

    function performanceFee(uint profit) override view public returns(uint) {
        return profit.mul(PERFORMANCE_FEE).div(FEE_MAX);
    }

    function mintFor(address flip, uint _withdrawalFee, uint _performanceFee, address to, uint) override external onlyMinter {
        uint feeSum = _performanceFee.add(_withdrawalFee);
        IBEP20(flip).safeTransferFrom(msg.sender, address(this), feeSum);

        uint hunnyBNBAmount = tokenToHunnyBNB(flip, IBEP20(flip).balanceOf(address(this)));
        address flipToken = hunnyBNBFlipToken();
        IBEP20(flipToken).safeTransfer(hunnyPool, hunnyBNBAmount);
        IStakingRewards(hunnyPool).notifyRewardAmount(hunnyBNBAmount);

        uint contribution = helper.tvlInBNB(flipToken, hunnyBNBAmount).mul(_performanceFee).div(feeSum);
        uint mintHunny = amountHunnyToMint(contribution);
        mint(mintHunny, to);

        // addition step
        // update oracle price
        oracle.update();
    }

    function mintForHunnyBNB(uint amount, uint duration, address to) override external onlyMinter {
        uint mintHunny = amountHunnyToMintForHunnyBNB(amount, duration);
        if (mintHunny == 0) return;
        mint(mintHunny, to);
    }

    function mint(uint amount, address to) private {
        hunny.mint(amount);
        hunny.transfer(to, amount);

        uint hunnyForDev = amount.mul(15).div(100);
        hunny.mint(hunnyForDev);
        IStakingRewards(hunnyPool).stakeTo(hunnyForDev, dev);

        // mint for lottery pool
        mintForLottery();
    }

    // only after when lottery pool address was set
    // token calculated from the block when dev set lottery pool address only
    function mintForLottery() private {
        if (lotteryPool != address(0)) {
            uint amountHunny = block.number.sub(lastLotteryMintBlock).mul(hunnyPerBlockLottery);
            hunny.mint(amountHunny);
            hunny.transfer(lotteryPool, amountHunny);
        }

        lastLotteryMintBlock = block.number;
    }
}
