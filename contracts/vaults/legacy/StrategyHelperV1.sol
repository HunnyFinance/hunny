// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../library/HomoraMath.sol";
import "../../interfaces/IPancakeFactory.sol";
import "../../interfaces/IPancakePair.sol";
import "../../interfaces/IMasterChef.sol";
import "../../interfaces/IHunnyMinter.sol";
import "../../interfaces/IHunnyOracle.sol";
import "../../interfaces/AggregatorV3Interface.sol";

// no storage
// There are only calculations for apy, tvl, etc.
// integrate with Hunny Oracle V2
contract StrategyHelperV1 is OwnableUpgradeable {
    using SafeMath for uint;
    address private constant WBNB   = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address private constant CAKE   = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    address private constant BUSD   = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    address private constant BANANA = address(0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95);
    address private constant HUNNY  = address(0x565b72163f17849832A692A3c5928cc502f46D69);

    IMasterChef private constant master = IMasterChef(0x73feaa1eE314F8c655E354234017bE2193C9E24E);
    IPancakeFactory private constant factory = IPancakeFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);

    IHunnyOracle public oracle;
    mapping(address => address) public tokenFeeds;

    function initialize() external initializer {
        __Ownable_init();

        // auto add ChainLink price feeds
        setTokenFeed(WBNB, address(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE));
        setTokenFeed(CAKE, address(0xB6064eD41d4f67e353768aA239cA86f4F73665a1));
    }

    // get hunny price to in BNB
    function tokenPriceInBNB(address _token) public view returns(uint) {
        if (_token == CAKE) {
            return  cakePriceInBNB();
        } else {
            uint priceInBNB = oracle.capture(_token);
            if (priceInBNB != 0) {
                return priceInBNB;
            } else {
                return unsafeTokenPriceInBNB(_token);
            }
        }
    }

    function unsafeTokenPriceInBNB(address _token) private view returns(uint) {
        address pair = factory.getPair(_token, WBNB);
        uint decimal = uint(BEP20(_token).decimals());

        (uint reserve0, uint reserve1, ) = IPancakePair(pair).getReserves();
        if (IPancakePair(pair).token0() == _token) {
            return reserve1.mul(10**decimal).div(reserve0);
        } else if (IPancakePair(pair).token1() == _token) {
            return reserve0.mul(10**decimal).div(reserve1);
        } else {
            return 0;
        }
    }

    function cakePriceInUSD() view public returns(uint) {
        (, int price, , ,) = AggregatorV3Interface(tokenFeeds[CAKE]).latestRoundData();
        return uint(price).mul(1e10);
    }

    function cakePriceInBNB() view public returns(uint) {
        return cakePriceInUSD().mul(1e18).div(bnbPriceInUSD());
    }

    function bnbPriceInUSD() view public returns(uint) {
        (, int price, , ,) = AggregatorV3Interface(tokenFeeds[WBNB]).latestRoundData();
        return uint(price).mul(1e10);
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
        if (_flip == CAKE) {
            return cakePriceInUSD().mul(amount).div(1e18);
        }

        if (_flip == HUNNY) {
            return tokenPriceInBNB(HUNNY).mul(bnbPriceInUSD()).mul(amount).div(1e36);
        }

        if (_flip == BANANA) {
            return tokenPriceInBNB(BANANA).mul(bnbPriceInUSD()).mul(amount).div(1e36);
        }

        address _token0 = IPancakePair(_flip).token0();
        address _token1 = IPancakePair(_flip).token1();

        // calculate tvl of WBNB
        if (_token0 == WBNB || _token1 == WBNB) {
            uint bnb;
            (uint256 reserve0, uint256 reserve1,) = IPancakePair(_flip).getReserves();
            if (_token0 == WBNB) {
                bnb = reserve0.mul(amount).div(IBEP20(_flip).totalSupply());
            } else {
                bnb = reserve1.mul(amount).div(IBEP20(_flip).totalSupply());
            }
            return bnb.mul(bnbPriceInUSD()).mul(2).div(1e18);
        }

        // it not safe, because token price in BNB not got from any oracle
        uint balanceToken0 = IBEP20(_token0).balanceOf(_flip);
        uint price = tokenPriceInBNB(_token0);
        return balanceToken0.mul(price).div(1e18).mul(bnbPriceInUSD()).mul(2).div(1e18);
    }

    function tvlInBNB(address _flip, uint amount) public view returns (uint) {
        if (_flip == CAKE) {
            return cakePriceInBNB().mul(amount).div(1e18);
        }

        if (_flip == HUNNY) {
            return tokenPriceInBNB(HUNNY).mul(amount).div(1e18);
        }

        if (_flip == BANANA) {
            return tokenPriceInBNB(BANANA).mul(amount).div(1e18);
        }

        address _token0 = IPancakePair(_flip).token0();
        address _token1 = IPancakePair(_flip).token1();

        if (_token0 == WBNB || _token1 == WBNB) {
            uint bnb;
            (uint256 reserve0, uint256 reserve1,) = IPancakePair(_flip).getReserves();
            if (_token0 == WBNB) {
                bnb = reserve0.mul(amount).mul(2).div(IBEP20(_flip).totalSupply());
            } else {
                bnb = reserve1.mul(amount).mul(2).div(IBEP20(_flip).totalSupply());
            }
            return bnb;
        }

        // it is not safe, need to implement oracle
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

    function setOracle(address oracleAddress) public onlyOwner {
        oracle = IHunnyOracle(oracleAddress);
    }

    function setTokenFeed(address asset, address feed) public onlyOwner {
        tokenFeeds[asset] = feed;
    }
}
