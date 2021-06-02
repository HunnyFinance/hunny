// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


library Constants {
    // pancake
    address constant PANCAKE_ROUTER = address(0x10ED43C718714eb63d5aA57B78B54704E256024E); // v2
    address constant PANCAKE_FACTORY = address(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    address constant PANCAKE_CHEF = address(0x73feaa1eE314F8c655E354234017bE2193C9E24E);

//    uint constant PANCAKE_CAKE_BNB_PID = 3;
     uint constant PANCAKE_CAKE_BNB_PID = 251; // mainnet

     uint constant PANCAKE_BUSD_BNB_PID = 252; // mainnet
//     uint constant PANCAKE_BUSD_BNB_PID = 4;

     uint constant PANCAKE_BUSD_USDT_PID = 264; // mainnet
//    uint constant PANCAKE_BUSD_USDT_PID = 0;

    // tokens
    address constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address constant CAKE = address(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    address constant BUSD = address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

    // external addresses
    address constant HUNNY_DEPLOYER = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);
    address constant HUNNY_LOTTERY = address(0); // update later
    address constant HUNNY_KEEPER = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);

    // minter
    uint256 constant HUNNY_PER_BLOCK_LOTTERY = 12e18;       // 12 HUNNY per block for lottery pool
    uint256 constant HUNNY_PER_PROFIT_BNB = 3200e18;        // 1 BNB earned, mint 3200 HUNNY
    uint256 constant HUNNY_PER_HUNNY_BNB_FLIP = 150e18;    // 1 HUNNY-BNB, earn 150 HUNNY / 365 days
}
