// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;


library Constants {
    // presale
    uint constant PRESALE_START_TIME = 1621239775;
    uint constant PRESALE_END_TIME = 1621844575;
    uint256 constant PRESALE_EXCHANGE_RATE = 5500;      // 1 BNB ~ 5500 HUNNY
    uint256 constant PRESALE_MIN_AMOUNT = 2e17;         // 0.2 BNB
    uint256 constant PRESALE_MAX_AMOUNT = 4e18;         // 4 BNB (not whitelist only)
    uint256 constant PRESALE_PUBLIC_AMOUNT = 20e18;     // 20 BNB available for public address
    uint256 constant PRESALE_WHITELIST_AMOUNT = 40e18;  // 40 BNB available for whitelist address

    // pancake
    address constant PANCAKE_ROUTER = address(0x6D40e6c66367bcf14D714B7007C4d9f8356F6598);
    address constant PANCAKE_FACTORY = address(0xA1C32f1a441F324A23358a93a7781B3A051933E8);
    address constant PANCAKE_CHEF = address(0x8F845853e3feCa57C9d566aFBe22f20A263CcBb9);

    // tokens
    address constant WBNB = address(0x56b6a8b995d98f017Bb16Dd8aFB7F532C2a2B4Cc);
    address constant CAKE = address(0xe5d917e53ddC8CdE9281c14ec83c550F894D2626);
    address constant BUSD = address(0x6C4559ca2d83a5780B0242b16dFD6eC8Cc0EA027);

    // pairs
    address constant CAKE_BNB_POOL = address(0x9cFF88173B28bb68e16c166Da3459610b098cf9c);
    address constant BNB_BUSD_POOL = address(0x42a93eD4AcE1BF2AA7979cFC975D85568A51Cf3f);

    // external addresses
    address constant HUNNY_DEPLOYER = address(0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a);

    // minter
    uint256 constant HUNNY_PER_PROFIT_BNB = 10e18;
    uint256 constant HUNNY_PER_HUNNY_BNB_FLIP = 6e18;
}
