// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

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


interface ICVaultETHLP {
    function validateRequest(uint8 signature, address lp, address account, uint128 leverage, uint collateral) external view returns (uint8 validation, uint112 nonce);
    function canLiquidate(address lp, address account) external view returns (bool);
    function executeLiquidation(address lp, address _account, address _liquidator) external;

    function notifyDeposited(address lp, address account, uint128 eventId, uint112 nonce, uint bscBNBDebt, uint bscFlipBalance) external;
    function notifyUpdatedLeverage(address lp, address account, uint128 eventId, uint112 nonce, uint bscBNBDebt, uint bscFlipBalance) external;
    function notifyWithdrawnAll(address lp, address account, uint128 eventId, uint112 nonce, uint ethProfit, uint ethLoss) external;
    function notifyLiquidated(address lp, address account, uint128 eventId, uint112 nonce, uint ethProfit, uint ethLoss) external;
    function notifyResolvedEmergency(address lp, address account, uint128 eventId, uint112 nonce) external;
}
