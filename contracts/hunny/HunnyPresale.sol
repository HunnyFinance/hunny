// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

import "../Constants.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakeFactory.sol";


interface IHunnyBNBPool {
    function depositTo(uint256 _pid, uint256 _amount, address _to) external;
}

interface IHunnyPool {
    function stakeTo(uint256 amount, address _to) external;
}

contract HunnyPresale is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    IPancakeFactory private factory = IPancakeFactory(Constants.PANCAKE_FACTORY);
    IPancakeRouter02 private router = IPancakeRouter02(Constants.PANCAKE_ROUTER);

    uint public startTime;
    uint public endTime;

    uint256 public exchangeRate;
    uint256 public minAmount;
    uint256 public maxAmount;
    uint256 public publicSaleTotal;
    uint256 public whitelistSaleTotal;

    address public token;

    address public masterChef;
    address public stakingRewards;

    uint public totalBalance;
    uint public totalFlipBalance;

    mapping (address => uint) private balance;
    mapping (address => bool) private whitelist;
    address[] public users;

    event Deposited(address indexed account, uint256 indexed amount);
    event Whitelisted(address indexed account, bool indexed allow);

    constructor() public {
        startTime = Constants.PRESALE_START_TIME;
        endTime = Constants.PRESALE_END_TIME;

        exchangeRate = Constants.PRESALE_EXCHANGE_RATE;

        minAmount = Constants.PRESALE_MIN_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);
        maxAmount = Constants.PRESALE_MAX_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);

        publicSaleTotal = Constants.PRESALE_PUBLIC_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);
        whitelistSaleTotal = Constants.PRESALE_WHITELIST_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);

        // add whitelist addresses
        configWhitelist(0xF628FA04Ae606530ef9EcAa79586b8d338Db94B8, true);
        configWhitelist(0x7fa889B83dE30a17Cd739588Ad765b5C1658fA33, true);
        configWhitelist(0x4C9343d92E9001fd4786E2A11029483a8f38D4AB, true);
        configWhitelist(0x6d9a8BfAC1bECE4b3B47730CC824a52812E34c3F, true);
        configWhitelist(0x34f3f50e9F576bD27b9EfC2d65c9DD74Db5a3d21, true);
        configWhitelist(0x6e7E602373404d4492e8D906557F07Bb6192a6Cd, true);
        configWhitelist(0xc85584eA7C9db6E1f5bdb536aF4F858eE4D56AC0, true);
        configWhitelist(0x3A6968224FeFcA80025994805F7cCcCE13480a5B, true);
        configWhitelist(0x3b6E6C9ff79CA9C5848229d95F6F110d2Bc2268d, true);
        configWhitelist(0x95D81FE1afCAE89de159142Fcb749b2FE2769F72, true);
        configWhitelist(0xdc50EB964e8D8BCACBCf86289d188Cb9dA29A2eF, true);
        configWhitelist(0x6BCd7D0B0b874b79592c356D51847d4852dEB10b, true);
        configWhitelist(0xEB382283eA0EaF1cFA91454C66160c1dcB26331b, true);
        configWhitelist(0x2f2bCA81b98c33ef5a65155fa0C6Df7d1e7D3D86, true);
        configWhitelist(0xcB17Aa0c15089027f756c913302693b28A825A97, true);
        configWhitelist(0x6eaBB6aa644a76765458b3a084820bBb65A0C778, true);
        configWhitelist(0x253eF98454d0C57E6C3E063b4d190E981b53E6a4, true);
        configWhitelist(0x77CAf519078Ca71Ac7E1F592A8C55f9D5460d50e, true);
        configWhitelist(0xD0e500c4fB2e03fae75C1C37cAe211C096c8e719, true);
    }

    receive() payable external {}

    function balanceOf(address account) public view returns(uint) {
        return balance[account];
    }

    function flipToken() public view returns(address) {
        return factory.getPair(token, router.WETH());
    }

    function usersLength() public view returns (uint256) {
        return users.length;
    }

    // return available amount for deposit in BNB
    function availableOf(address account) public view returns (uint256) {
        uint256 available;

        if (now < startTime || now > endTime) {
            return 0;
        }

        if (whitelist[account]) {
            available = whitelistSaleTotal;
        } else {
            available = maxAmount.sub(balance[account]);
            if (available > publicSaleTotal) {
                available = publicSaleTotal;
            }
        }

        return available.div(exchangeRate);
    }

    function deposit() public payable {
        address user = msg.sender;
        uint256 amount = msg.value.mul(exchangeRate); // convert BNB to HUNNY amount

        require(now >= startTime || now <= endTime, "!open");

        uint256 available = availableOf(user).mul(exchangeRate);
        require(amount <= available, "!available");
        require(amount >= minAmount, "!minimum");

        if (!findUser(user)) {
            users.push(user);
        }

        balance[user] = balance[user].add(amount);
        totalBalance = totalBalance.add(amount);

        if (whitelist[user]) {
            // whitelist
            whitelistSaleTotal = whitelistSaleTotal.sub(amount);
        } else {
            // public sale
            publicSaleTotal = publicSaleTotal.sub(amount);
        }

        emit Deposited(user, amount);
    }

    function findUser(address user) private view returns (bool) {
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == user) {
                return true;
            }
        }

        return false;
    }

    // init and add liquidity
    function initialize(address _token, address _masterChef, address _rewards) public onlyOwner {
        token = _token;
        masterChef = _masterChef;
        stakingRewards = _rewards;

        require(IBEP20(token).balanceOf(address(this)) >= totalBalance, "less token");

        uint256 tokenAmount = totalBalance.div(2);
        uint256 amount = address(this).balance;

        IBEP20(token).safeApprove(address(router), 0);
        IBEP20(token).safeApprove(address(router), tokenAmount);
        router.addLiquidityETH{value: amount.div(2)}(token, tokenAmount, 0, 0, address(this), block.timestamp);

        address lp = flipToken();
        totalFlipBalance = IBEP20(lp).balanceOf(address(this));
    }

    function distributeTokens(uint256 _pid) public onlyOwner {
        address lpToken = flipToken();
        require(lpToken != address(0), 'not set flip');
        require(masterChef != address (0), 'not set masterChef');
        require(stakingRewards != address(0), 'not set stakingRewards');

        IBEP20(lpToken).safeApprove(masterChef, 0);
        IBEP20(lpToken).safeApprove(masterChef, totalFlipBalance);

        IBEP20(token).safeApprove(stakingRewards, 0);
        IBEP20(token).safeApprove(stakingRewards, totalBalance.div(2));

        for(uint i=0; i<usersLength(); i++) {
            address user = users[i];
            uint share = shareOf(user);

            _distributeFlip(user, share, _pid);
            _distributeToken(user, share);

            delete balance[user];
        }
    }

    function _distributeFlip(address user, uint share, uint pid) private {
        uint remaining = IBEP20(flipToken()).balanceOf(address(this));
        uint amount = totalFlipBalance.mul(share).div(1e18);
        if (amount == 0) return;

        if (remaining < amount) {
            amount = remaining;
        }
        IHunnyBNBPool(masterChef).depositTo(pid, amount, user);
    }

    function _distributeToken(address user, uint share) private {
        uint remaining = IBEP20(token).balanceOf(address(this));
        uint amount = totalBalance.div(2).mul(share).div(1e18);
        if (amount == 0) return;

        if (remaining < amount) {
            amount = remaining;
        }
        IHunnyPool(stakingRewards).stakeTo(amount, user);
    }


    function finalize() public onlyOwner {
        // will go to the HUNNY pool as reward
        payable(owner()).transfer(address(this).balance);

        // will burn unsold tokens
        uint tokenBalance = IBEP20(token).balanceOf(address(this));
        if (tokenBalance > 0) {
            IBEP20(token).transfer(owner(), tokenBalance);
        }
    }

    function shareOf(address _user) private view returns(uint256) {
        return balance[_user].mul(1e18).div(totalBalance);
    }

    function configWhitelist(address user, bool allow) public onlyOwner {
        whitelist[user] = allow;

        emit Whitelisted(user, allow);
    }

    // config the presale rate
    function configMoney(
        uint256 _exchangeRate,
        uint256 _minBNBAmount,
        uint256 _maxBNBAmount,
        uint256 _publicBNBTotal,
        uint256 _whitelistBNBTotal
    ) public onlyOwner {
        exchangeRate = _exchangeRate;

        minAmount = _minBNBAmount.mul(_exchangeRate);
        maxAmount = _maxBNBAmount.mul(_exchangeRate);

        publicSaleTotal = _publicBNBTotal.mul(_exchangeRate);
        whitelistSaleTotal = _whitelistBNBTotal.mul(_exchangeRate);
    }

    // config the presale timeline
    function configTime(
        uint _startTime,
        uint _endTime
    ) public onlyOwner {
        startTime = _startTime;
        endTime = _endTime;
    }

    // backup function for emergency situation
    function setAddress(address _token, address _masterChef, address _rewards) public onlyOwner {
        token = _token;
        masterChef = _masterChef;
        stakingRewards = _rewards;
    }
}
