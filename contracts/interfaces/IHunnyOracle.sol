// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IHunnyOracle {
    function price0CumulativeLast(address token) external view returns(uint);
    function price1CumulativeLast(address token) external view returns(uint);
    function blockTimestampLast(address token) external view returns(uint);
    function capture(address token) external view returns(uint224);

    function update() external;
}
