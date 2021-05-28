// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "../Constants.sol";
import "../library/uniswap/FixedPoint.sol";
import "../library/uniswap/UniswapV2Library.sol";
import "../library/uniswap/UniswapV2OracleLibrary.sol";


// fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract HunnyOracle is Ownable {
    using FixedPoint for *;

    uint public constant PERIOD = 10 minutes;
    uint112 public constant BOOTSTRAP_HUNNY_PRICE = 250000000000000; // 1 BNB = 4000 HUNNY

    bool public initialized;

    address public hunnyToken;
    IUniswapV2Pair pair;
    address public token0;
    address public token1;

    uint    public price0CumulativeLast;
    uint    public price1CumulativeLast;
    uint32  public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    constructor(address hunny) public {
        hunnyToken = hunny;
    }

    function initialize() internal {
        IUniswapV2Pair _pair = IUniswapV2Pair(IUniswapV2Factory(Constants.PANCAKE_FACTORY).getPair(hunnyToken, Constants.WBNB));

        pair = _pair;

        token0 = _pair.token0();
        token1 = _pair.token1();

        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)

        // get the blockTimestampLast
        (,, blockTimestampLast) = _pair.getReserves();

        _update();
        initialized = true;
    }

    function update() public onlyOwner {
        if (!initialized) {
            initialize();
        }

        (, , uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // ensure that at least one full period has passed since the last update
        if (timeElapsed >= PERIOD) {
            _update();
        }
    }

    function _update() internal {
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
        UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
        price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address token, uint amountIn) public view returns (uint amountOut) {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, 'HunnyOracle: INVALID_TOKEN');
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    function capture() public view returns(uint) {
        uint consultAmount = consult(hunnyToken, 1e18);
        if (consultAmount == 0) {
            return BOOTSTRAP_HUNNY_PRICE;
        } else {
            return consultAmount;
        }
    }
}
