// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "./HunnyToken.sol";
import "./HunnyPresale.sol";
import "./HunnyOracle.sol";
import "./legacy/HunnyMinter.sol";
import "../Constants.sol";
import "../vaults/legacy/StrategyHelperV1.sol";
import "../vaults/legacy/HunnyPool.sol";
import "../vaults/legacy/HunnyBNBPool.sol";
import "../vaults/legacy/CakeVault.sol";
import "../vaults/legacy/CakeFlipVault.sol";
import "../interfaces/IPancakeRouter02.sol";


// assume that the presale contract has been deployed
// deploy following contract only when the presale ended
// ready for add liquidity and open legacy pools
contract Deployer1 is Ownable {
    HunnyToken public hunny;
    HunnyOracle public hunnyOracle;
    StrategyHelperV1 public helper;

    HunnyPool public hunnyPool;
    HunnyBNBPool public hunnyBNBPool;
    HunnyMinter public hunnyMinter;

    constructor(address presaleAddress) public {
        // deploy hunny token
        hunny = new HunnyToken();
        hunnyOracle = new HunnyOracle(address(hunny));
        helper = new StrategyHelperV1(address(hunnyOracle));

        // deploy HUNNY Pool
        hunnyPool = new HunnyPool(
            address(hunny),
            address(presaleAddress),
            address(helper)
        );

        // deploy HUNNY BNB pool
        hunnyBNBPool = new HunnyBNBPool(
            address(hunny),
            address(presaleAddress),
            address(helper)
        );

        // deploy hunny minter
        hunnyMinter = new HunnyMinter(
            address(hunny),
            address(hunnyPool),
            address(Constants.HUNNY_LOTTERY),
            address(hunnyOracle),
            address(helper)
        );
    }

    function transferContractOwner(address deployer2) public onlyOwner {
        hunny.transferOwnership(deployer2);
        hunnyOracle.transferOwnership(deployer2);
        helper.transferOwnership(deployer2);
        hunnyPool.transferOwnership(deployer2);
        hunnyBNBPool.transferOwnership(deployer2);
        hunnyMinter.transferOwnership(deployer2);
    }
}

contract Deployer2 is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    Deployer1 public deployer1;
    HunnyPresale public presale;

    constructor(address deployer1Address, address payable presaleAddress) public {
        deployer1 = Deployer1(deployer1Address);
        presale = HunnyPresale(presaleAddress);
    }

    // allow deployer2 receive BNB from presale contract
    receive() external payable{}

    function step1_presaleInitialize() public onlyOwner {
        // mint token for presale contract
        deployer1.hunny().mint(address(presale), presale.totalBalance());

        // this part used to add liquidity and distribute to HUNNY pool as reward
        deployer1.hunny().mint(address(this), presale.totalBalance().div(2));

        // initialize presale
        presale.initialize(
            address(deployer1.hunny()),
            address(deployer1.hunnyBNBPool()),
            address(deployer1.hunnyPool())
        );

        // set flip token
        deployer1.hunnyBNBPool().setFlipToken(presale.flipToken());

        // set rewards token
        deployer1.hunnyPool().setRewardsToken(presale.flipToken());
    }

    function step2_presaleDistributeTokens() public onlyOwner {
        presale.distributeTokens(0);
    }

    function step3_presaleFinalize() public onlyOwner {
        // transfer remain fund to this address
        presale.finalize();

        // transfer HUNNY token ownership
        deployer1.hunny().transferOwnership(address(deployer1.hunnyMinter()));

        // set minter role for HUNNY-BNB Hive Pool
        deployer1.hunnyMinter().setMinter(address(deployer1.hunnyBNBPool()), true);

        // set minter address in HUNNY-BNB Hive Pool
        deployer1.hunnyBNBPool().setMinter(IHunnyMinter(address(deployer1.hunnyMinter())));

        // set stake permission for Hunny Minter from HUNNY Hive Pool
        deployer1.hunnyPool().setStakePermission(address(deployer1.hunnyMinter()), true);

        // transfer hunny oracle owner to hunny minter
        deployer1.hunnyOracle().transferOwnership(address(deployer1.hunnyMinter()));
    }

    function step4_setupLiquidityReward(uint256 bnbAmount) public onlyOwner {
        IPancakeRouter02 router = IPancakeRouter02(Constants.PANCAKE_ROUTER);

        address token = address(deployer1.hunny());
        uint256 tokenAmount = bnbAmount.mul(deployer1.hunny().balanceOf(address(this))).div(address(this).balance);

        IBEP20(token).safeApprove(address(router), 0);
        IBEP20(token).safeApprove(address(router), tokenAmount);
        router.addLiquidityETH{value: bnbAmount}(token, tokenAmount, 0, 0, address(this), block.timestamp);

        payable(owner()).transfer(address(this).balance);
        deployer1.hunny().transfer(owner(), deployer1.hunny().balanceOf(address(this)));

        // set reward distribution on this address
        deployer1.hunnyPool().setRewardsDistribution(address(this));

        // transfer reward to HUNNY Hive Pool
        uint256 rewardAmount = IBEP20(presale.flipToken()).balanceOf(address(this));
        IBEP20(presale.flipToken()).transfer(address(deployer1.hunnyPool()), rewardAmount);
        deployer1.hunnyPool().notifyRewardAmount(rewardAmount);

        // set reward distribution on HUNNY Hive Pool
        deployer1.hunnyPool().setRewardsDistribution(address(deployer1.hunnyMinter()));
    }

    function transferContractOwner(address newOwner) public onlyOwner {
        presale.transferOwnership(newOwner);

        deployer1.helper().transferOwnership(newOwner);

        deployer1.hunnyPool().transferOwnership(newOwner);
        deployer1.hunnyBNBPool().transferOwnership(newOwner);
        deployer1.hunnyMinter().transferOwnership(newOwner);
    }

    // in the emergency situation, transfer remain fund to dev
    // dev will init liquidity and distribute reward
    function emergencyTransfer() public payable onlyOwner {
        payable(owner()).transfer(address(this).balance);
        deployer1.hunny().transfer(owner(), deployer1.hunny().balanceOf(address(this)));
    }
}

// make sure Deployer1 and Deployer2 work well
// deployer3 deploy CAKE vault and FLIP to CAKE pools
// external deployer address need to update token price feed on StrategyHelperV1 contract
contract Deployer3 is Ownable {
    Deployer2 public deployer2;

    CakeVault public cakeVault;
    CakeFlipVault public flipCakeBnb;
    CakeFlipVault public flipBusdBnb;
    CakeFlipVault public flipBusdUsdt;

    constructor(address payable deployer2Address) public {
        deployer2 = Deployer2(deployer2Address);

        cakeVault = new CakeVault(Constants.CAKE, Constants.PANCAKE_CHEF);

        // deploy CAKE-BNB vault
        flipCakeBnb = new CakeFlipVault(
            Constants.PANCAKE_CAKE_BNB_PID, // pancake master chef pid
            Constants.CAKE,
            Constants.PANCAKE_CHEF,
            address(cakeVault),
            address(deployer2.deployer1().hunnyMinter())
        );

        // deploy BUSD-BNB vault
        flipCakeBnb = new CakeFlipVault(
            Constants.PANCAKE_BUSD_BNB_PID, // pancake master chef pid
            Constants.CAKE,
            Constants.PANCAKE_CHEF,
            address(cakeVault),
            address(deployer2.deployer1().hunnyMinter())
        );
    }

    function transferContractOwner(address newOwner) public onlyOwner {
        cakeVault.transferOwnership(newOwner);
        flipCakeBnb.transferOwnership(newOwner);
        flipBusdBnb.transferOwnership(newOwner);
//        flipBusdUsdt.transferOwnership(owner());
    }
}
