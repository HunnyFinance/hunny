// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "../library/WhitelistUpgradeable.sol";
import "../library/uniswap/FixedPoint.sol";
import "../library/uniswap/UniswapV2Library.sol";
import "../library/uniswap/UniswapV2OracleLibrary.sol";


// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
// support multiple pairs
contract HunnyOracle is WhitelistUpgradeable {
    using FixedPoint for *;

    uint public constant PERIOD = 10 minutes;

    address public constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public constant HUNNY = address(0x565b72163f17849832A692A3c5928cc502f46D69);
    address public constant BANANA = address(0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95);

    address public constant PANCAKE_FACTORY = address(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    address public constant APE_FACTORY = address(0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6);

    struct Pair {
        IUniswapV2Factory factory;
        IUniswapV2Pair pair;

        address token0;
        address token1;

        uint   price0CumulativeLast;
        uint   price1CumulativeLast;
        uint32 blockTimestampLast;

        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average;
    }

    address[] public tokens;
    mapping (address => Pair) public pairs;

    function initialize() external initializer {
        __WhitelistUpgradeable_init();

        addPair(HUNNY, PANCAKE_FACTORY);
        addPair(BANANA, APE_FACTORY);

        _update(HUNNY);
        _update(BANANA);
    }

    function addPair(address token, address factory) public onlyOwner {
        require(address(pairs[token].pair) == address(0), "HUNNY_ORACLE: PAIR_EXISTED");

        pairs[token].factory = IUniswapV2Factory(factory);
        pairs[token].pair = IUniswapV2Pair(pairs[token].factory.getPair(token, WBNB));
        pairs[token].token0 = pairs[token].pair.token0();
        pairs[token].token1 = pairs[token].pair.token1();
        pairs[token].price0CumulativeLast = pairs[token].pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        pairs[token].price1CumulativeLast = pairs[token].pair.price1CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        pairs[token].blockTimestampLast = 0;

        tokens.push(token);
    }

    function update() public onlyWhitelisted {
        _update(HUNNY);
        _update(BANANA);
    }

    function _update(address token) internal {
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(address(pairs[token].pair));

        uint32 timeElapsed = blockTimestamp - pairs[token].blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        if (timeElapsed >= PERIOD) {
            // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
            pairs[token].price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - pairs[token].price0CumulativeLast) / timeElapsed));
            pairs[token].price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - pairs[token].price1CumulativeLast) / timeElapsed));

            pairs[token].price0CumulativeLast = price0Cumulative;
            pairs[token].price1CumulativeLast = price1Cumulative;
            pairs[token].blockTimestampLast = blockTimestamp;
        }
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint amountIn) public view returns (uint amountOut) {
        Pair memory pair = pairs[token];
        require(address(pair.pair) != address(0), "HunnyOracle: INVALID_PAIR");

        if (token == pair.token0) {
            amountOut = pair.price0Average.mul(amountIn).decode144();
        } else {
            require(token == pair.token1, 'HunnyOracle: INVALID_TOKEN');
            amountOut = pair.price1Average.mul(amountIn).decode144();
        }
    }

    function capture(address token) public view returns(uint) {
        return consult(token, 1e18);
    }
}
