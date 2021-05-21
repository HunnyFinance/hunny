// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

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

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";

import "../interfaces/IHunnyMinterV2.sol";
import "../interfaces/legacy/IStakingRewards.sol";
import "../dashboard/calculator/PriceCalculatorBSC.sol";
import "../zap/ZapBSC.sol";

contract HunnyMinterV2 is IHunnyMinterV2, OwnableUpgradeable {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    /* ========== CONSTANTS ============= */

    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant HUNNY = 0xC9849E6fdB743d08fAeE3E34dd2D1bc69EA11a51;
    address public constant HUNNY_BNB = 0x7Bb89460599Dbf32ee3Aa50798BBcEae2A5F7f6a;
    address public constant HUNNY_POOL = 0xCADc8CB26c8C7cB46500E61171b5F27e9bd7889D;

    address public constant DEPLOYER = 0xe87f02606911223C2Cf200398FFAF353f60801F7;
    address private constant TIMELOCK = 0x85c9162A51E03078bdCd08D4232Bab13ed414cC3;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint public constant FEE_MAX = 10000;

    ZapBSC public constant zapBSC = ZapBSC(0xCBEC8e7AB969F6Eb873Df63d04b4eAFC353574b1);
    PriceCalculatorBSC public constant priceCalculator = PriceCalculatorBSC(0x542c06a5dc3f27e0fbDc9FB7BC6748f26d54dDb0);

    /* ========== STATE VARIABLES ========== */

    address public hunnyChef;
    mapping(address => bool) private _minters;
    address public _deprecated_helper; // deprecated

    uint public PERFORMANCE_FEE;
    uint public override WITHDRAWAL_FEE_FREE_PERIOD;
    uint public override WITHDRAWAL_FEE;

    uint public override hunnyPerProfitBNB;
    uint public hunnyPerHunnyBNBFlip;   // will be deprecated

    /* ========== MODIFIERS ========== */

    modifier onlyMinter {
        require(isMinter(msg.sender) == true, "HunnyMinterV2: caller is not the minter");
        _;
    }

    modifier onlyHunnyChef {
        require(msg.sender == hunnyChef, "HunnyMinterV2: caller not the hunny chef");
        _;
    }

    receive() external payable {}

    /* ========== INITIALIZER ========== */

    function initialize() external initializer {
        WITHDRAWAL_FEE_FREE_PERIOD = 3 days;
        WITHDRAWAL_FEE = 50;
        PERFORMANCE_FEE = 3000;

        hunnyPerProfitBNB = 5e18;
        hunnyPerHunnyBNBFlip = 6e18;

        IBEP20(HUNNY).approve(HUNNY_POOL, uint(-1));
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function transferHunnyOwner(address _owner) external onlyOwner {
        Ownable(HUNNY).transferOwnership(_owner);
    }

    function setWithdrawalFee(uint _fee) external onlyOwner {
        require(_fee < 500, "wrong fee");
        // less 5%
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

    function setHunnyChef(address _hunnyChef) external onlyOwner {
        require(hunnyChef == address(0), "HunnyMinterV2: setHunnyChef only once");
        hunnyChef = _hunnyChef;
    }

    /* ========== VIEWS ========== */

    function isMinter(address account) public view override returns (bool) {
        if (IBEP20(HUNNY).getOwner() != address(this)) {
            return false;
        }
        return _minters[account];
    }

    function amountHunnyToMint(uint bnbProfit) public view override returns (uint) {
        return bnbProfit.mul(hunnyPerProfitBNB).div(1e18);
    }

    function amountHunnyToMintForHunnyBNB(uint amount, uint duration) public view override returns (uint) {
        return amount.mul(hunnyPerHunnyBNBFlip).mul(duration).div(365 days).div(1e18);
    }

    function withdrawalFee(uint amount, uint depositedAt) external view override returns (uint) {
        if (depositedAt.add(WITHDRAWAL_FEE_FREE_PERIOD) > block.timestamp) {
            return amount.mul(WITHDRAWAL_FEE).div(FEE_MAX);
        }
        return 0;
    }

    function performanceFee(uint profit) public view override returns (uint) {
        return profit.mul(PERFORMANCE_FEE).div(FEE_MAX);
    }

    /* ========== V1 FUNCTIONS ========== */

    function mintFor(address asset, uint _withdrawalFee, uint _performanceFee, address to, uint) external payable override onlyMinter {
        uint feeSum = _performanceFee.add(_withdrawalFee);
        _transferAsset(asset, feeSum);

        if (asset == HUNNY) {
            IBEP20(HUNNY).safeTransfer(DEAD, feeSum);
            return;
        }

        uint hunnyBNBAmount = _zapAssetsToHunnyBNB(asset);
        if (hunnyBNBAmount == 0) return;

        IBEP20(HUNNY_BNB).safeTransfer(HUNNY_POOL, hunnyBNBAmount);
        IStakingRewards(HUNNY_POOL).notifyRewardAmount(hunnyBNBAmount);

        (uint valueInBNB,) = priceCalculator.valueOfAsset(HUNNY_BNB, hunnyBNBAmount);
        uint contribution = valueInBNB.mul(_performanceFee).div(feeSum);
        uint mintHunny = amountHunnyToMint(contribution);
        if (mintHunny == 0) return;
        _mint(mintHunny, to);
    }

    // @dev will be deprecated
    function mintForHunnyBNB(uint amount, uint duration, address to) external override onlyMinter {
        uint mintHunny = amountHunnyToMintForHunnyBNB(amount, duration);
        if (mintHunny == 0) return;
        _mint(mintHunny, to);
    }

    /* ========== V2 FUNCTIONS ========== */

    function mint(uint amount) external override onlyHunnyChef {
        if (amount == 0) return;
        _mint(amount, address(this));
    }

    function safeHunnyTransfer(address _to, uint _amount) external override onlyHunnyChef {
        if (_amount == 0) return;

        uint bal = IBEP20(HUNNY).balanceOf(address(this));
        if (_amount <= bal) {
            IBEP20(HUNNY).safeTransfer(_to, _amount);
        } else {
            IBEP20(HUNNY).safeTransfer(_to, bal);
        }
    }

    // @dev should be called when determining mint in governance. Hunny is transferred to the timelock contract.
    function mintGov(uint amount) external override onlyOwner {
        if (amount == 0) return;
        _mint(amount, TIMELOCK);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _transferAsset(address asset, uint amount) private {
        if (asset == address(0)) {
            // case) transferred BNB
            require(msg.value >= amount);
        } else {
            IBEP20(asset).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _zapAssetsToHunnyBNB(address asset) private returns (uint) {
        if (asset != address(0) && IBEP20(asset).allowance(address(this), address(zapBSC)) == 0) {
            IBEP20(asset).safeApprove(address(zapBSC), uint(-1));
        }

        if (asset == address(0)) {
            zapBSC.zapIn{value : address(this).balance}(HUNNY_BNB);
        }
        else if (keccak256(abi.encodePacked(IPancakePair(asset).symbol())) == keccak256("Cake-LP")) {
            zapBSC.zapOut(asset, IBEP20(asset).balanceOf(address(this)));

            IPancakePair pair = IPancakePair(asset);
            address token0 = pair.token0();
            address token1 = pair.token1();
            if (token0 == WBNB || token1 == WBNB) {
                address token = token0 == WBNB ? token1 : token0;
                if (IBEP20(token).allowance(address(this), address(zapBSC)) == 0) {
                    IBEP20(token).safeApprove(address(zapBSC), uint(-1));
                }
                zapBSC.zapIn{value : address(this).balance}(HUNNY_BNB);
                zapBSC.zapInToken(token, IBEP20(token).balanceOf(address(this)), HUNNY_BNB);
            } else {
                if (IBEP20(token0).allowance(address(this), address(zapBSC)) == 0) {
                    IBEP20(token0).safeApprove(address(zapBSC), uint(-1));
                }
                if (IBEP20(token1).allowance(address(this), address(zapBSC)) == 0) {
                    IBEP20(token1).safeApprove(address(zapBSC), uint(-1));
                }

                zapBSC.zapInToken(token0, IBEP20(token0).balanceOf(address(this)), HUNNY_BNB);
                zapBSC.zapInToken(token1, IBEP20(token1).balanceOf(address(this)), HUNNY_BNB);
            }
        }
        else {
            zapBSC.zapInToken(asset, IBEP20(asset).balanceOf(address(this)), HUNNY_BNB);
        }

        return IBEP20(HUNNY_BNB).balanceOf(address(this));
    }

    function _mint(uint amount, address to) private {
        BEP20 tokenHUNNY = BEP20(HUNNY);

        tokenHUNNY.mint(amount);
        if (to != address(this)) {
            tokenHUNNY.transfer(to, amount);
        }

        uint hunnyForDev = amount.mul(15).div(100);
        tokenHUNNY.mint(hunnyForDev);
        IStakingRewards(HUNNY_POOL).stakeTo(hunnyForDev, DEPLOYER);
    }
}
