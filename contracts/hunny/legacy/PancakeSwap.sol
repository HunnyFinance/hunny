// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../interfaces/IPancakeRouter02.sol";
import "../../interfaces/IPancakePair.sol";
import "../../interfaces/IPancakeFactory.sol";

abstract contract PancakeSwap is OwnableUpgradeable {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    IPancakeRouter02 private constant ROUTER = IPancakeRouter02(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));
    IPancakeFactory private constant factory = IPancakeFactory(address(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73));

    IPancakeRouter02 private constant APE_ROUTER = IPancakeRouter02(address(0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607));

    address internal constant cake = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    address internal constant banana = address(0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95);
    address internal constant banana_bnb = address(0xF65C1C0478eFDe3c19b49EcBE7ACc57BB6B1D713);
    address private constant _hunny = address(0x565b72163f17849832A692A3c5928cc502f46D69);
    address private constant _wbnb = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    function __PancakeSwap_init() internal initializer {
        __Ownable_init();
    }

    function hunnyBNBFlipToken() internal view returns(address) {
        return factory.getPair(_hunny, _wbnb);
    }

    function tokenToHunnyBNB(address token, uint amount) internal returns(uint flipAmount) {
        if (token == cake) {
            flipAmount = _cakeToHunnyBNBFlip(amount);
        } else if (token == banana) {
            flipAmount = _bananaToHunnyBNBFlip(amount);
        } else {
            // flip
            if (token == banana_bnb) {
                flipAmount = _bananaBNBFlipToHunnyBNBFlip(token, amount);
            } else {
                flipAmount = _flipToHunnyBNBFlip(token, amount);
            }
        }
    }

    function _cakeToHunnyBNBFlip(uint amount) private returns(uint flipAmount) {
        uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
        uint256 wbnbBefore = IBEP20(_wbnb).balanceOf(address(this));

        swapToken(cake, amount.div(2), _hunny);
        swapToken(cake, amount.sub(amount.div(2)), _wbnb);

        uint256 hunnyBalance = IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore);
        uint256 wbnbBalance = IBEP20(_wbnb).balanceOf(address(this)).sub(wbnbBefore);

        flipAmount = generateFlipToken(hunnyBalance, wbnbBalance);
    }

    // 1. swap all BANANA -> WBNB from ApeSwap
    // 2. swap 1/2 WBNB -> HUNNY from PancakeSwap
    // 3. add WBNB/HUNNY on PancakeSwap
    function _bananaToHunnyBNBFlip(uint amount) private returns(uint flipAmount) {
        uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
        uint256 wbnbBefore = IBEP20(_wbnb).balanceOf(address(this));

        swapTokenOnApe(banana, amount, _wbnb);

        uint256 wbnbBalanceAfterSwapOnApe = IBEP20(_wbnb).balanceOf(address(this)).sub(wbnbBefore);
        uint256 amountToHunny = wbnbBalanceAfterSwapOnApe.div(2);
        swapToken(_wbnb, amountToHunny, _hunny);

        uint256 hunnyBalance = IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore);
        uint256 wbnbBalance = wbnbBalanceAfterSwapOnApe.sub(amountToHunny);

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
            uint256 wbnbBalance = IBEP20(_wbnb).balanceOf(address(this)).sub(wbnbBefore);

            flipAmount = generateFlipToken(hunnyBalance, wbnbBalance);
        }
    }

    // convert BANANA-BNB FLIP to WBNB on ApeSwap
    // convert 1/2 WBNB to HUNNY on PancakeSwap
    // add liquidity HUNNY+BNB on PancakeSwap
    function _bananaBNBFlipToHunnyBNBFlip(address token, uint amount) private returns(uint flipAmount) {
        IPancakePair pair = IPancakePair(token);
        address _token0 = pair.token0();
        address _token1 = pair.token1();
        IBEP20(token).safeApprove(address(APE_ROUTER), 0);
        IBEP20(token).safeApprove(address(APE_ROUTER), amount);

        // snapshot balance before remove liquidity
        uint256 _token0BeforeRemove = IBEP20(_token0).balanceOf(address(this));
        uint256 _token1BeforeRemove = IBEP20(_token1).balanceOf(address(this));

        APE_ROUTER.removeLiquidity(_token0, _token1, amount, 0, 0, address(this), block.timestamp);

        // swap all BANANA to WBNB
        uint256 bananaBalance;
        uint256 wbnbBalance;
        if (_token0 == _wbnb) {
            bananaBalance = IBEP20(banana).balanceOf(address(this)).sub(_token1BeforeRemove);
            swapTokenOnApe(banana, bananaBalance, _wbnb);
            wbnbBalance = IBEP20(_wbnb).balanceOf(address(this)).sub(_token0BeforeRemove);
        } else {
            bananaBalance = IBEP20(banana).balanceOf(address(this)).sub(_token0BeforeRemove);
            swapTokenOnApe(banana, bananaBalance, _wbnb);
            wbnbBalance = IBEP20(_wbnb).balanceOf(address(this)).sub(_token1BeforeRemove);
        }

        // swap 1/2 WBNB -> HUNNY
        uint256 amountWbnbToSwap = wbnbBalance.div(2);
        uint256 amountWbnbRemain = wbnbBalance.sub(amountWbnbToSwap);
        uint256 hunnyBefore = IBEP20(_hunny).balanceOf(address(this));
        swapToken(_wbnb, amountWbnbToSwap, _hunny);

        flipAmount = generateFlipToken(IBEP20(_hunny).balanceOf(address(this)).sub(hunnyBefore), amountWbnbRemain);
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

    function swapTokenOnApe(address _from, uint _amount, address _to) private {
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

        IBEP20(_from).safeApprove(address(APE_ROUTER), 0);
        IBEP20(_from).safeApprove(address(APE_ROUTER), _amount);
        APE_ROUTER.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp);
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
