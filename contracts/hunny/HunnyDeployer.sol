// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "./HunnyToken.sol";
import "./HunnyOracle.sol";
import "./legacy/HunnyMinter.sol";
import "../Constants.sol";
import "../vaults/legacy/StrategyHelperV1.sol";
import "../vaults/legacy/HunnyPool.sol";
import "../vaults/legacy/HunnyBNBPool.sol";
import "../vaults/legacy/CakeVault.sol";
import "../vaults/legacy/CakeFlipVault.sol";
import "../interfaces/IPancakeRouter02.sol";

interface Presale {
    function totalBalance() external view returns(uint);
    function flipToken() external view returns(address);
    function initialize(address _token, address _masterChef, address _rewardToken) external;
    function distributeTokens(uint _pid, uint _fromIndex, uint _toIndex) external;
    function distributeTokensWhiteList(uint _pid) external;
    function finalize() external;
}

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
        hunnyOracle = new HunnyOracle();
        helper = new StrategyHelperV1();

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
        hunnyMinter = new HunnyMinter();
    }

    function transferContractOwner(address deployer2) public onlyOwner {
        hunny.transferOwnership(deployer2);
        hunny.transferOperator(deployer2);
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
    Presale public presale;

    constructor(address deployer1Address, address payable presaleAddress) public {
        deployer1 = Deployer1(deployer1Address);
        presale = Presale(presaleAddress);
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

        // update anti-whale max value
        // anti bots
        deployer1.hunny().updateMaxTransferAmountRate(4);
    }

    function step2_1_presaleDistributeTokens(uint fromIndex, uint toIndex) public onlyOwner {
        deployer1.hunny().updateMaxTransferAmountRate(10000);
        presale.distributeTokens(0, fromIndex, toIndex);
        deployer1.hunny().updateMaxTransferAmountRate(4);
    }

    function step2_2_presaleDistributeTokensWhiteList() public onlyOwner {
        deployer1.hunny().updateMaxTransferAmountRate(10000);
        presale.distributeTokensWhiteList(0);
        deployer1.hunny().updateMaxTransferAmountRate(4);
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
        deployer1.hunny().updateMaxTransferAmountRate(10000);
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

        deployer1.hunny().updateMaxTransferAmountRate(4);
    }

    function transferContractOwner(address newOwner) public onlyOwner {
        Ownable(address(presale)).transferOwnership(newOwner);

        deployer1.hunny().transferOperator(newOwner);
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
