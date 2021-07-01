// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

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
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";

import "../../Constants.sol";
import "../../interfaces/IMasterChef.sol";
import "../../interfaces/IHunnyMinter.sol";
import "../../interfaces/legacy/IStrategyHelper.sol";
import "../../interfaces/legacy/IStrategyLegacy.sol";

contract CakeVault is IStrategyLegacy, Ownable {
    using SafeBEP20 for IBEP20;
    using SafeMath for uint256;

    IBEP20 private CAKE;
    IMasterChef private CAKE_MASTER_CHEF;

    address public keeper = Constants.HUNNY_KEEPER;

    uint public poolId = 0;

    uint public totalShares;
    mapping (address => uint) private _shares;

    IStrategyHelper public helper;
    mapping (address => bool) private _whitelist;

    constructor(address cake, address cakeMasterChef) public {
        CAKE = IBEP20(cake);
        CAKE_MASTER_CHEF = IMasterChef(cakeMasterChef);

        CAKE.safeApprove(address(CAKE_MASTER_CHEF), uint(~0));
    }

    function setKeeper(address _keeper) external {
        require(msg.sender == _keeper || msg.sender == owner(), 'auth');
        require(_keeper != address(0), 'zero address');
        keeper = _keeper;
    }

    function setHelper(IStrategyHelper _helper) external {
        require(msg.sender == address(_helper) || msg.sender == owner(), 'auth');
        require(address(_helper) != address(0), "zero address");

        helper = _helper;
    }

    function setWhitelist(address _address, bool _on) external onlyOwner {
        _whitelist[_address] = _on;
    }

    function balance() override public view returns (uint) {
        (uint amount,) = CAKE_MASTER_CHEF.userInfo(poolId, address(this));
        return CAKE.balanceOf(address(this)).add(amount);
    }

    // @returns cake amount
    function balanceOf(address account) override public view returns(uint) {
        if (totalShares == 0) return 0;
        return balance().mul(sharesOf(account)).div(totalShares);
    }

    function withdrawableBalanceOf(address account) override public view returns (uint) {
        return balanceOf(account);
    }

    function sharesOf(address account) public view returns (uint) {
        return _shares[account];
    }

    function principalOf(address account) override public view returns (uint) {
        return balanceOf(account);
    }

    function profitOf(address) override public view returns (uint _usd, uint _hunny, uint _bnb) {
        // Not available
        return (0, 0, 0);
    }

    function tvl() override public view returns (uint) {
        return helper.tvl(address(CAKE), balance());
    }

    function apy() override public view returns(uint _usd, uint _hunny, uint _bnb) {
        return helper.apy(IHunnyMinter(address (0)), poolId);
    }

    function info(address account) override external view returns(UserInfo memory) {
        UserInfo memory userInfo;

        userInfo.balance = balanceOf(account);
        userInfo.principal = principalOf(account);
        userInfo.available = withdrawableBalanceOf(account);

        Profit memory profit;
        (uint usd, uint hunny, uint bnb) = profitOf(account);
        profit.usd = usd;
        profit.hunny = hunny;
        profit.bnb = bnb;
        userInfo.profit = profit;

        userInfo.poolTVL = tvl();

        APY memory poolAPY;
        (usd, hunny, bnb) = apy();
        poolAPY.usd = usd;
        poolAPY.hunny = hunny;
        poolAPY.bnb = bnb;
        userInfo.poolAPY = poolAPY;

        return userInfo;
    }

    function priceShare() public view returns(uint) {
        if (totalShares == 0) return 0;
        return balance().mul(1e18).div(totalShares);
    }

    function _depositTo(uint _amount, address _to) private {
        require(_whitelist[msg.sender], "not whitelist");

        uint _pool = balance();
        CAKE.safeTransferFrom(msg.sender, address(this), _amount);
        uint shares = 0;
        if (totalShares == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalShares)).div(_pool);
        }

        totalShares = totalShares.add(shares);
        _shares[_to] = _shares[_to].add(shares);

        CAKE_MASTER_CHEF.leaveStaking(0);
        uint balanceOfCake = CAKE.balanceOf(address(this));
        CAKE_MASTER_CHEF.enterStaking(balanceOfCake);
    }

    function deposit(uint _amount) override public {
        _depositTo(_amount, msg.sender);
    }

    function depositAll() override external {
        deposit(CAKE.balanceOf(msg.sender));
    }

    function withdrawAll() override external {
        uint amount = sharesOf(msg.sender);
        withdraw(amount);
    }

    function harvest() override external {
        CAKE_MASTER_CHEF.leaveStaking(0);
        uint cakeAmount = CAKE.balanceOf(address(this));
        CAKE_MASTER_CHEF.enterStaking(cakeAmount);
    }

    // salvage purpose only
    function withdrawToken(address token, uint amount) external {
        require(msg.sender == keeper || msg.sender == owner(), 'auth');
        require(token != address(CAKE));

        IBEP20(token).safeTransfer(msg.sender, amount);
    }

    function withdraw(uint256 _amount) override public {
        uint _withdraw = balance().mul(_amount).div(totalShares);
        totalShares = totalShares.sub(_amount);
        _shares[msg.sender] = _shares[msg.sender].sub(_amount);

        CAKE_MASTER_CHEF.leaveStaking(_withdraw.sub(CAKE.balanceOf(address(this))));
        CAKE.safeTransfer(msg.sender, _withdraw);

        CAKE_MASTER_CHEF.enterStaking(CAKE.balanceOf(address(this)));
    }

    function getReward() override external {
        revert("N/A");
    }
}
