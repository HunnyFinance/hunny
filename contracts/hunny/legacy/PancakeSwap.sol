// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "../../Constants.sol";
import "../../interfaces/IPancakeRouter02.sol";
import "../../interfaces/IPancakePair.sol";
import "../../interfaces/IPancakeFactory.sol";

contract PancakeSwap {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    IPancakeRouter02 private ROUTER = IPancakeRouter02(Constants.PANCAKE_ROUTER);
    IPancakeFactory private factory = IPancakeFactory(Constants.PANCAKE_FACTORY);

    address internal cake = Constants.CAKE;
    address private _hunny;
    address private _wbnb = Constants.WBNB;

    constructor(address _hunnyAddress) public {
        _hunny = _hunnyAddress;
    }

    function hunnyBNBFlipToken() internal view returns(address) {
        return factory.getPair(_hunny, _wbnb);
    }

    function tokenToHunnyBNB(address token, uint amount) internal returns(uint flipAmount) {
        if (token == cake) {
            flipAmount = _cakeToHunnyBNBFlip(amount);
        } else {
            // flip
            flipAmount = _flipToHunnyBNBFlip(token, amount);
        }
    }

    function _cakeToHunnyBNBFlip(uint amount) private returns(uint flipAmount) {
        uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
        uint256 wbnbBefore = IBEP20(_wbnb).balanceOf(address(this));

        swapToken(cake, amount.div(2), _hunny);
        swapToken(cake, amount.sub(amount.div(2)), _wbnb);

        uint256 hunnyBalance = IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore);
        uint256 wbnbBalance = IBEP20(_hunny).balanceOf(address(this)).sub(wbnbBefore);

        flipAmount = generateFlipToken(hunnyBalance, wbnbBalance);
    }

    function _flipToHunnyBNBFlip(address token, uint amount) private returns(uint flipAmount) {
        IPancakePair pair = IPancakePair(token);
        address _token0 = pair.token0();
        address _token1 = pair.token1();
        IBEP20(token).safeApprove(address(ROUTER), 0);
        IBEP20(token).safeApprove(address(ROUTER), amount);

        // snapshot balance before remove liquidity
        uint256 _token0BeforeRemove = IBEP20(_token0).balanceOf(address(this));
        uint256 _token1BeforeRemove = IBEP20(_token1).balanceOf(address(this));

        ROUTER.removeLiquidity(_token0, _token1, amount, 0, 0, address(this), block.timestamp);
        if (_token0 == _wbnb) {
            uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
            swapToken(_token1, IBEP20(_token1).balanceOf(address(this)).sub(_token1BeforeRemove), _hunny);
            uint256 hunnyBalance = IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore);

            flipAmount = generateFlipToken(hunnyBalance, IBEP20(_wbnb).balanceOf(address(this)).sub(_token0BeforeRemove));
        } else if (_token1 == _wbnb) {
            uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
            swapToken(_token0, IBEP20(_token0).balanceOf(address(this)).sub(_token0BeforeRemove), _hunny);
            uint256 hunnyBalance = IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore);

            flipAmount = generateFlipToken(hunnyBalance, IBEP20(_wbnb).balanceOf(address(this)).sub(_token1BeforeRemove));
        } else {
            uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
            uint256 wbnbBefore = IBEP20(_wbnb).balanceOf(address(this));

            swapToken(_token0, IBEP20(_token0).balanceOf(address(this)).sub(_token0BeforeRemove), _hunny);
            swapToken(_token1, IBEP20(_token1).balanceOf(address(this)).sub(_token1BeforeRemove), _wbnb);

            uint256 hunnyBalance = IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore);
            uint256 wbnbBalance = IBEP20(_hunny).balanceOf(address(this)).sub(wbnbBefore);

            flipAmount = generateFlipToken(hunnyBalance, wbnbBalance);
        }
    }

    function swapToken(address _from, uint _amount, address _to) private {
        if (_from == _to) return;

        address[] memory path;
        if (_from == _wbnb || _to == _wbnb) {
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        } else {
            path = new address[](3);
            path[0] = _from;
            path[1] = _wbnb;
            path[2] = _to;
        }

        IBEP20(_from).safeApprove(address(ROUTER), 0);
        IBEP20(_from).safeApprove(address(ROUTER), _amount);
        ROUTER.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp);
    }

    function generateFlipToken(uint256 amountADesired, uint256 amountBDesired) private returns(uint liquidity) {
        IBEP20(_hunny).safeApprove(address(ROUTER), 0);
        IBEP20(_hunny).safeApprove(address(ROUTER), amountADesired);
        IBEP20(_wbnb).safeApprove(address(ROUTER), 0);
        IBEP20(_wbnb).safeApprove(address(ROUTER), amountBDesired);

        (,,liquidity) = ROUTER.addLiquidity(_hunny, _wbnb, amountADesired, amountBDesired, 0, 0, address(this), block.timestamp);

        // send dust
        IBEP20(_hunny).transfer(msg.sender, IBEP20(_hunny).balanceOf(address(this)));
        IBEP20(_wbnb).transfer(msg.sender, IBEP20(_wbnb).balanceOf(address(this)));
    }
}
