// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

import "../../Constants.sol";
import "../../interfaces/IPancakeFactory.sol";
import "../../interfaces/IPancakePair.sol";
import "../../interfaces/IMasterChef.sol";
import "../../interfaces/IHunnyMinter.sol";

// no storage
// There are only calculations for apy, tvl, etc.
contract StrategyHelperV1 is Ownable {
    using SafeMath for uint;
    address private CAKE_POOL = Constants.CAKE_BNB_POOL;
    address private BNB_BUSD_POOL = Constants.BNB_BUSD_POOL;

    IBEP20 private WBNB = IBEP20(Constants.WBNB);
    IBEP20 private CAKE = IBEP20(Constants.CAKE);
    IBEP20 private BUSD = IBEP20(Constants.BUSD);

    IMasterChef private master = IMasterChef(Constants.PANCAKE_CHEF);
    IPancakeFactory private factory = IPancakeFactory(Constants.PANCAKE_FACTORY);

    constructor() public {}

    function tokenPriceInBNB(address _token) view public returns(uint) {
        address pair = factory.getPair(_token, address(WBNB));
        uint decimal = uint(BEP20(_token).decimals());

        return WBNB.balanceOf(pair).mul(10**decimal).div(IBEP20(_token).balanceOf(pair));
    }

    function cakePriceInBNB() view public returns(uint) {
        return WBNB.balanceOf(CAKE_POOL).mul(1e18).div(CAKE.balanceOf(CAKE_POOL));
    }

    function bnbPriceInUSD() view public returns(uint) {
        return BUSD.balanceOf(BNB_BUSD_POOL).mul(1e18).div(WBNB.balanceOf(BNB_BUSD_POOL));
    }

    function cakePerYearOfPool(uint pid) view public returns(uint) {
        (, uint allocPoint,,) = master.poolInfo(pid);
        return master.cakePerBlock().mul(blockPerYear()).mul(allocPoint).div(master.totalAllocPoint());
    }

    function blockPerYear() pure public returns(uint) {
        // 86400 / 3 * 365
        return 10512000;
    }

    function profitOf(address minter, address flip, uint amount) external view returns (uint _usd, uint _hunny, uint _bnb) {
        _usd = tvl(flip, amount);
        if (address(minter) == address(0)) {
            _hunny = 0;
        } else {
            uint performanceFee = IHunnyMinter(minter).performanceFee(_usd);
            _usd = _usd.sub(performanceFee);
            uint bnbAmount = performanceFee.mul(1e18).div(bnbPriceInUSD());
            _hunny = IHunnyMinter(minter).amountHunnyToMint(bnbAmount);
        }
        _bnb = 0;
    }

    // apy() = cakePrice * (cakePerBlock * blockPerYear * weight) / PoolValue(=WBNB*2)
    function _apy(uint pid) view private returns(uint) {
        (address token,,,) = master.poolInfo(pid);
        uint poolSize = tvl(token, IBEP20(token).balanceOf(address(master))).mul(1e18).div(bnbPriceInUSD());
        return cakePriceInBNB().mul(cakePerYearOfPool(pid)).div(poolSize);
    }

    function apy(address, uint pid) view public returns(uint _usd, uint _hunny, uint _bnb) {
        _usd = compoundingAPY(pid, 1 days);
        _hunny = 0;
        _bnb = 0;
    }

    function tvl(address _flip, uint amount) public view returns (uint) {
        if (_flip == address(CAKE)) {
            return cakePriceInBNB().mul(bnbPriceInUSD()).mul(amount).div(1e36);
        }
        address _token0 = IPancakePair(_flip).token0();
        address _token1 = IPancakePair(_flip).token1();
        if (_token0 == address(WBNB) || _token1 == address(WBNB)) {
            uint bnb = WBNB.balanceOf(address(_flip)).mul(amount).div(IBEP20(_flip).totalSupply());
            uint price = bnbPriceInUSD();
            return bnb.mul(price).div(1e18).mul(2);
        }

        uint balanceToken0 = IBEP20(_token0).balanceOf(_flip);
        uint price = tokenPriceInBNB(_token0);
        return balanceToken0.mul(price).div(1e18).mul(bnbPriceInUSD()).div(1e18).mul(2);
    }

    function tvlInBNB(address _flip, uint amount) public view returns (uint) {
        if (_flip == address(CAKE)) {
            return cakePriceInBNB().mul(amount).div(1e18);
        }
        address _token0 = IPancakePair(_flip).token0();
        address _token1 = IPancakePair(_flip).token1();
        if (_token0 == address(WBNB) || _token1 == address(WBNB)) {
            uint bnb = WBNB.balanceOf(address(_flip)).mul(amount).div(IBEP20(_flip).totalSupply());
            return bnb.mul(2);
        }

        uint balanceToken0 = IBEP20(_token0).balanceOf(_flip);
        uint price = tokenPriceInBNB(_token0);
        return balanceToken0.mul(price).div(1e18).mul(2);
    }

    function compoundingAPY(uint pid, uint compoundUnit) view public returns(uint) {
        uint __apy = _apy(pid);
        uint compoundTimes = 365 days / compoundUnit;
        uint unitAPY = 1e18 + (__apy / compoundTimes);
        uint result = 1e18;

        for(uint i=0; i<compoundTimes; i++) {
            result = (result * unitAPY) / 1e18;
        }

        return result - 1e18;
    }

    // backup for invalid configs, emergency only
    function configTokenAddresses(address wbnb, address cake, address busd) public onlyOwner {
        WBNB = IBEP20(wbnb);
        CAKE = IBEP20(cake);
        BUSD = IBEP20(busd);
    }

    function configPoolAddresses(address cake_bnb, address bnb_busd) public onlyOwner {
        CAKE_POOL = cake_bnb;
        BNB_BUSD_POOL = bnb_busd;
    }

    function configContractAddresses(address pancakeChef, address pancakeFactory) public onlyOwner {
        master = IMasterChef(pancakeChef);
        factory = IPancakeFactory(pancakeFactory);
    }
}
