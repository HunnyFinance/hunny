// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

interface IHunnyOracle {
    function price0CumulativeLast() external view returns(uint);
    function price1CumulativeLast() external view returns(uint);
    function blockTimestampLast() external view returns(uint);
    function capture() external view returns(uint224);

    function update() external;
}
