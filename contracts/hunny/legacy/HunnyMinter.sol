// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";

import "./PancakeSwap.sol";
import "../../interfaces/IHunnyMinter.sol";
import "../../interfaces/IHunnyOracle.sol";
import "../../interfaces/legacy/IStakingRewards.sol";
import "../../interfaces/legacy/IStrategyHelper.sol";

contract HunnyMinter is IHunnyMinter, PancakeSwap {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    IBEP20 private constant HUNNY = IBEP20(0x565b72163f17849832A692A3c5928cc502f46D69);
    IBEP20 private constant WBNB = IBEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    address public constant dev = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);

    uint public override WITHDRAWAL_FEE_FREE_PERIOD;
    uint public override WITHDRAWAL_FEE;
    uint public FEE_MAX;

    uint public PERFORMANCE_FEE;

    uint public override hunnyPerProfitBNB;
    uint public hunnyPerHunnyBNBFlip;

    address public constant HUNNY_POOL = address(0x389D2719a9Bcc29583Db89FD9454ADe9e57CD18d);

    IHunnyOracle public ORACLE;
    IStrategyHelper public HELPER;

    mapping (address => bool) private _minters;

    modifier onlyMinter {
        require(isMinter(msg.sender) == true, "not minter");
        _;
    }

    function initialize() external initializer {
        __PancakeSwap_init();

        WITHDRAWAL_FEE_FREE_PERIOD = 2 days;
        WITHDRAWAL_FEE = 50; // 0.5%
        FEE_MAX = 10000; // 100%

        PERFORMANCE_FEE = 3000; // 30%

        hunnyPerProfitBNB = 3200e18;   // 1 BNB earned, mint 3200 HUNNY
        hunnyPerHunnyBNBFlip = 150e18; // 1 HUNNY-BNB, earn 150 HUNNY / 365 days

        _minters[address(0x434Af79fd4E96B5985719e3F5f766619DC185EAe)] = true; // HUNNY-BNB pool
        _minters[address(0x12180BB36DdBce325b3be0c087d61Fce39b8f5A4)] = true; // CAKE-BNB vault
        _minters[address(0xD87F461a52E2eB9E57463B9A4E0e97c7026A5DCB)] = true; // BUSD-BNB vault
        _minters[address(0x31972E7bfAaeE72F2EB3a7F68Ff71D0C61162e81)] = true; // USDT-BNB vault
        _minters[address(0x3B34AA6825fA731c69C63d4925d7a2E3F6c7f13C)] = true; // DOGE-BNB vault
        _minters[address(0xb7D43F1beD47eCba4Ad69CcD56dde4474B599965)] = true; // CAKE vault
        _minters[address(0xAD4134F59C5241d0B4f6189731AA2f7b279D4104)] = true; // BANANA vault

        ORACLE = IHunnyOracle(0x9e377Bc8DaB0C30CFBa5e94cE52be1989a644e28);
        HELPER = IStrategyHelper(0x486B662A191E29cF767862ACE492c89A6c834fB4);

        HUNNY.approve(HUNNY_POOL, uint256(-1));
    }

    function transferHunnyOwner(address _owner) external onlyOwner {
        Ownable(address(HUNNY)).transferOwnership(_owner);
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

    function setHelper(IStrategyHelper _helper) external onlyOwner {
        require(address(_helper) != address(0), "zero address");
        HELPER = _helper;
    }

    function setOracle(IHunnyOracle _oracle) external onlyOwner {
        require(address(_oracle) != address(0), "zero address");
        ORACLE = _oracle;
    }

    function isMinter(address account) override view public returns(bool) {
        if (HUNNY.getOwner() != address(this)) {
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

        uint hunnyBNBAmount = tokenToHunnyBNB(flip, feeSum);
        address flipToken = hunnyBNBFlipToken();
        IBEP20(flipToken).safeTransfer(HUNNY_POOL, hunnyBNBAmount);
        IStakingRewards(HUNNY_POOL).notifyRewardAmount(hunnyBNBAmount);

        // avoid hunnyBNBAmount manipulation
        uint contribution = HELPER.tvlInBNB(flip, _performanceFee);
        uint mintHunny = amountHunnyToMint(contribution);

        if (mintHunny > 0) {
            mint(mintHunny, to);
        }

        // addition step
        // update oracle price
        ORACLE.update();
    }

    function mintForHunnyBNB(uint amount, uint duration, address to) override external onlyMinter {
        uint mintHunny = amountHunnyToMintForHunnyBNB(amount, duration);
        if (mintHunny == 0) return;
        mint(mintHunny, to);
    }

    function mint(uint amount, address to) private {
        BEP20(address(HUNNY)).mint(amount);
        HUNNY.transfer(to, amount);

        uint hunnyForDev = amount.mul(15).div(100);
        BEP20(address(HUNNY)).mint(hunnyForDev);
        IStakingRewards(HUNNY_POOL).stakeTo(hunnyForDev, dev);
    }
}
