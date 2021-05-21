// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "./HunnyToken.sol";
import "./HunnyPresale.sol";
import "./legacy/HunnyMinter.sol";
import "../Constants.sol";
import "../vaults/legacy/StrategyHelperV1.sol";
import "../vaults/legacy/HunnyPool.sol";
import "../vaults/legacy/HunnyBNBPool.sol";
import "../interfaces/IPancakeRouter02.sol";

contract Deployer1 {
    HunnyToken public hunny;
    StrategyHelperV1 public helper;
    HunnyPresale public presale;

    constructor() public {
        // deploy hunny token
        hunny = new HunnyToken();

        helper = new StrategyHelperV1();

        presale = new HunnyPresale();
    }

    function step1_configPresaleMoney(
        uint256 _exchangeRate,
        uint256 _minBNBAmount,
        uint256 _maxBNBAmount,
        uint256 _publicBNBTotal,
        uint256 _whitelistBNBTotal
    ) public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");
        presale.configMoney(
            _exchangeRate,
            _minBNBAmount,
            _maxBNBAmount,
            _publicBNBTotal,
            _whitelistBNBTotal
        );
    }

    function step2_configPresaleTime(
        uint _startTime,
        uint _endTime
    ) public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");
        presale.configTime(_startTime, _endTime);
    }

    function configPresaleWhitelist(address account, bool allow) public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");
        presale.configWhitelist(account, allow);
    }

    function changeOwner(address deployer3) public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        hunny.transferOwnership(deployer3);
        presale.transferOwnership(deployer3);
        helper.transferOwnership(deployer3);
    }
}

contract Deployer2 {
    Deployer1 public deployer1;
    HunnyPool public hunnyPool;
    HunnyBNBPool public hunnyBNBPool;
    HunnyMinter public minter;

    constructor(address deployer1Address) public {
        deployer1 = Deployer1(deployer1Address);

        // deploy HUNNY Pool
        hunnyPool = new HunnyPool(
            address(deployer1.hunny()),
            address(deployer1.presale()),
            address(deployer1.helper())
        );

        // end the presale
        hunnyBNBPool = new HunnyBNBPool(
            address(deployer1.hunny()),
            address(deployer1.presale()),
            address(deployer1.helper())
        );

        // deploy hunny minter
        minter = new HunnyMinter(
            address(deployer1.hunny()),
            address(hunnyPool),
            address(deployer1.helper())
        );
    }

    function changeOwner(address deployer3) public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        hunnyPool.transferOwnership(deployer3);
        hunnyBNBPool.transferOwnership(deployer3);
        minter.transferOwnership(deployer3);
    }
}

contract Deployer3 {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    Deployer1 public deployer1;
    Deployer2 public deployer2;

    constructor(address deployer2Address) public {
        deployer2 = Deployer2(deployer2Address);
        deployer1 = Deployer1(deployer2.deployer1());
    }

    // allow deployer3 receive BNB from presale contract
    receive() external payable{}

    function step1_presaleInitialize() public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        // mint token for presale contract
        deployer1.hunny().mint(address(deployer1.presale()), deployer1.presale().totalBalance());
        deployer1.hunny().mint(address(this), deployer1.presale().totalBalance().div(2));

        // initialize presale
        deployer1.presale().initialize(
            address(deployer1.hunny()),
            address(deployer2.hunnyBNBPool()),
            address(deployer2.hunnyPool())
        );

        // set flip token
        deployer2.hunnyBNBPool().setFlipToken(deployer1.presale().flipToken());

        // set rewards token
        deployer2.hunnyPool().setRewardsToken(deployer1.presale().flipToken());
    }

    function step2_presaleDistributeTokens() public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        deployer1.presale().distributeTokens(0);
    }

    function step3_presaleFinalize() public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        deployer1.presale().finalize();

        // transfer HUNNY token ownership
        deployer1.hunny().transferOwnership(address(deployer2.minter()));

        // set minter role for HUNNY-BNB Hive Pool
        deployer2.minter().setMinter(address(deployer2.hunnyBNBPool()), true);

        // set minter address in HUNNY-BNB Hive Pool
        deployer2.hunnyBNBPool().setMinter(IHunnyMinter(address(deployer2.minter())));

        // set stake permission for Hunny Minter from HUNNY Hive Pool
        deployer2.hunnyPool().setStakePermission(address(deployer2.minter()), true);

        // set reward distribution on HUNNY Hive Pool
        deployer2.hunnyPool().setRewardsDistribution(address(deployer2.minter()));
    }

    function step4_setupLiquidityReward(uint256 bnbAmount) public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        IPancakeRouter02 router = IPancakeRouter02(Constants.PANCAKE_ROUTER);

        address token = address(deployer1.hunny());
        uint256 tokenAmount = bnbAmount.mul(deployer1.hunny().balanceOf(address(this))).div(address(this).balance);

        IBEP20(token).safeApprove(address(router), 0);
        IBEP20(token).safeApprove(address(router), tokenAmount);
        router.addLiquidityETH{value: bnbAmount}(token, tokenAmount, 0, 0, address(this), block.timestamp);

        payable(Constants.HUNNY_DEPLOYER).transfer(address(this).balance);
        deployer1.hunny().transfer(Constants.HUNNY_DEPLOYER, deployer1.hunny().balanceOf(address(this)));

        // transfer reward to HUNNY Hive Pool
        uint256 rewardAmount = IBEP20(deployer1.presale().flipToken()).balanceOf(address(this));
        IBEP20(deployer1.presale().flipToken()).transfer(address(deployer2.hunnyPool()), rewardAmount);
        deployer2.hunnyPool().notifyRewardAmount(rewardAmount);
    }

    function changeOwner() public {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        deployer1.hunny().transferOwnership(Constants.HUNNY_DEPLOYER);
        deployer1.presale().transferOwnership(Constants.HUNNY_DEPLOYER);
        deployer1.helper().transferOwnership(Constants.HUNNY_DEPLOYER);

        deployer2.hunnyPool().transferOwnership(Constants.HUNNY_DEPLOYER);
        deployer2.hunnyBNBPool().transferOwnership(Constants.HUNNY_DEPLOYER);
        deployer2.minter().transferOwnership(Constants.HUNNY_DEPLOYER);
    }

    function emergencyTransferBNB() public payable {
        require(msg.sender == Constants.HUNNY_DEPLOYER, "!dev");

        payable(Constants.HUNNY_DEPLOYER).transfer(address(this).balance);
        deployer1.hunny().transfer(Constants.HUNNY_DEPLOYER, deployer1.hunny().balanceOf(address(this)));
    }
}
