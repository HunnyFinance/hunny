// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


library Constants {
    // pancake
    address constant PANCAKE_ROUTER = address(0x6D40e6c66367bcf14D714B7007C4d9f8356F6598);
    address constant PANCAKE_FACTORY = address(0xA1C32f1a441F324A23358a93a7781B3A051933E8);
    address constant PANCAKE_CHEF = address(0x8F845853e3feCa57C9d566aFBe22f20A263CcBb9);

    uint constant PANCAKE_CAKE_BNB_PID = 3;
    // uint constant PANCAKE_CAKE_BNB_PID = 251; // mainnet

    // uint constant PANCAKE_BUSD_BNB_PID = 252; // mainnet
     uint constant PANCAKE_BUSD_BNB_PID = 4;

    // uint constant PANCAKE_BUSD_USDT_PID = 258; // mainnet
    uint constant PANCAKE_BUSD_USDT_PID = 0;

    // tokens
    address constant WBNB = address(0x56b6a8b995d98f017Bb16Dd8aFB7F532C2a2B4Cc);
    address constant CAKE = address(0xe5d917e53ddC8CdE9281c14ec83c550F894D2626);
    address constant BUSD = address(0x6C4559ca2d83a5780B0242b16dFD6eC8Cc0EA027);

    // external addresses
    address constant HUNNY_DEPLOYER = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);
    address constant HUNNY_LOTTERY = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);
    address constant HUNNY_KEEPER = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);

    // minter
    uint256 constant HUNNY_PER_BLOCK_LOTTERY = 12e18;       // 12 HUNNY per block for lottery pool
    uint256 constant HUNNY_PER_PROFIT_BNB = 3200e18;        // 1 BNB earned, mint 3200 HUNNY
    uint256 constant HUNNY_PER_HUNNY_BNB_FLIP = 3500e18;    // 1 HUNNY-BNB, earn 3500 HUNNY / 365 days
}
