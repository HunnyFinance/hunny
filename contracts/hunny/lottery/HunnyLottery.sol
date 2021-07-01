// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./HunnyLotteryNFT.sol";
import "../../interfaces/IHunnyLotteryNFTV2.sol";
import "../../library/RewardsDistributionRecipientUpgradeable.sol";

contract HunnyLottery is RewardsDistributionRecipientUpgradeable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using SafeERC20 for IERC20;

    address public constant DEV = address(0x84e3157944dFE9Dd2c9008f29d678F7090fB798F);
    address public constant DEAD = address(0x8441D8f22ccb532afaE6AA1ee3bC5ABff0020C80);
    address public constant HUNNY_BEE = address(0x5E456328B9F12c6B6CF8E6385356FF03CEB6AAA3);
    address public constant BUMBLE_BEE = address(0x6174A829829c009Cb2B66caE09A0Ee34462285a8);

    IHunnyLotteryNFTV2 public constant LOTTERY_NFT_V2 = IHunnyLotteryNFTV2(address(0xf3B11C00eAA421B089a7362a91d7032aeEdf2521));

    uint constant DEV_ALLOC = 30; // 30%
    uint constant BURN_ALLOC = 50; // 50%
    uint constant HUNNY_BEE_ALLOC = 12; // 12%
    uint constant BUMBLE_BEE_ALLOC = 8; // 8%

    uint8 constant keyLengthForEachBuy = 11;

    // Allocation for first/sencond/third reward
    uint8[3] public allocation;
    // The TOKEN to buy lottery
    IERC20 public hunny;
    // The Lottery NFT for tickets
    HunnyLotteryNFT public lotteryNFT;
    // adminAddress
    address public adminAddress;
    // maxNumber
    uint8 public maxNumber;
    // minPrice, if decimal is not 18, please reset it
    uint256 public minPrice;

    // =================================

    // issueId => winningNumbers[numbers]
    mapping (uint256 => uint8[4]) public historyNumbers;
    // issueId => [tokenId]
    mapping (uint256 => uint256[]) public lotteryInfo;
    // issueId => [totalAmount, firstMatchAmount, secondMatchingAmount, thirdMatchingAmount]
    mapping (uint256 => uint256[]) public historyAmount;
    // issueId => trickyNumber => buyAmountSum
    mapping (uint256 => mapping(uint64 => uint256)) public userBuyAmountSum;
    // address => [tokenId]
    mapping (address => uint256[]) public userInfo;

    uint256 public issueIndex = 0;
    uint256 public totalAddresses = 0;
    uint256 public totalAmount = 0;
    uint256 public lastTimestamp;

    uint8[4] public winningNumbers;

    // default false
    bool public drawingPhase;

    // =================================

    event Buy(address indexed user, uint256 tokenId);
    event Drawing(uint256 indexed issueIndex, uint8[4] winningNumbers);
    event Claim(address indexed user, uint256 tokenid, uint256 amount);
    event DevWithdraw(address indexed user, uint256 amount);
    event Reset(uint256 indexed issueIndex);
    event MultiClaim(address indexed user, uint256 amount);
    event MultiBuy(address indexed user, uint256 amount);
    event RewardAdded(address indexed from, uint256 amount);

    function initialize() public initializer {
        __RewardsDistributionRecipient_init();

        //        hunny = IERC20(0xFa454473F6B01DCa65F6beC24181316f605764b8);
        //        lotteryNFT = HunnyLotteryNFT(0xf4634895dFe48E33d62F33ddb8073310E7fAd204);
        //        minPrice = 5e18; // 5 HUNNY
        //        maxNumber = 14;
        //        adminAddress = 0xe5F7E3DD9A5612EcCb228392F47b7Ddba8cE4F1a;
        //        lastTimestamp = block.timestamp;
        //        allocation = [50, 30, 10];
    }

    uint8[4] private nullTicket = [0,0,0,0];

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "admin: wut?");
        _;
    }

    function drawed() public view returns(bool) {
        return winningNumbers[0] != 0;
    }

    function reset() external onlyAdmin {
        require(drawed(), "drawed?");
        lastTimestamp = block.timestamp;
        totalAddresses = 0;
        totalAmount = 0;
        winningNumbers[0]=0;
        winningNumbers[1]=0;
        winningNumbers[2]=0;
        winningNumbers[3]=0;
        drawingPhase = false;
        issueIndex = issueIndex + 1;

        uint totalAlloc = 0;
        for (uint i = 0; i < allocation.length; i++) {
            totalAlloc = totalAlloc.add(allocation[i]);
        }

        uint distributionAmount = getTotalRewards(issueIndex-1).sub(
            getTotalRewards(issueIndex-1).mul(totalAlloc).div(100)
        );
        distributeContributionAmount(distributionAmount);

        uint totalBurn = 0;

        if(getMatchingRewardAmount(issueIndex-1, 4) == 0) {
            totalBurn = totalBurn.add(getTotalRewards(issueIndex-1).mul(allocation[0]).div(100));
        }

        if(getMatchingRewardAmount(issueIndex-1, 3) == 0) {
            totalBurn = totalBurn.add(getTotalRewards(issueIndex-1).mul(allocation[1]).div(100));
        }

        if(getMatchingRewardAmount(issueIndex-1, 2) == 0) {
            totalBurn = totalBurn.add(getTotalRewards(issueIndex-1).mul(allocation[2]).div(100));
        }

        if (totalBurn > 0) {
            uint amount = totalBurn.div(2);
            internalBuy(amount, nullTicket);

            hunny.safeTransfer(DEAD, totalBurn.sub(amount));
        }

        emit Reset(issueIndex);
    }

    function enterDrawingPhase() external onlyAdmin {
        require(!drawed(), 'drawed');
        drawingPhase = true;
    }

    // add externalRandomNumber to prevent node validators exploiting
    function drawing(uint256 _externalRandomNumber) external onlyAdmin {
        require(!drawed(), "reset?");
        require(drawingPhase, "enter drawing phase first");
        bytes32 _structHash;
        uint256 _randomNumber;
        uint8 _maxNumber = maxNumber;
        bytes32 _blockhash = blockhash(block.number-1);

        // waste some gas fee here
        for (uint i = 0; i < 10; i++) {
            getTotalRewards(issueIndex);
        }
        uint256 gasRemain = gasleft();

        // 1
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                totalAddresses,
                gasRemain,
                _externalRandomNumber
            )
        );
        _randomNumber  = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[0]=uint8(_randomNumber);

        // 2
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                totalAmount,
                gasRemain,
                _externalRandomNumber
            )
        );
        _randomNumber  = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[1]=uint8(_randomNumber);

        // 3
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                lastTimestamp,
                gasRemain,
                _externalRandomNumber
            )
        );
        _randomNumber  = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[2]=uint8(_randomNumber);

        // 4
        _structHash = keccak256(
            abi.encode(
                _blockhash,
                gasRemain,
                _externalRandomNumber
            )
        );
        _randomNumber  = uint256(_structHash);
        assembly {_randomNumber := add(mod(_randomNumber, _maxNumber),1)}
        winningNumbers[3]=uint8(_randomNumber);
        historyNumbers[issueIndex] = winningNumbers;
        historyAmount[issueIndex] = calculateMatchingRewardAmount();
        drawingPhase = false;

        emit Drawing(issueIndex, winningNumbers);
    }

    function internalBuy(uint256 _price, uint8[4] memory _numbers) internal {
        require (!drawed(), 'drawed, can not buy now');
        for (uint i = 0; i < 4; i++) {
            require (_numbers[i] <= maxNumber, 'exceed the maximum');
        }
        LOTTERY_NFT_V2.newLotteryItem(DEAD, _numbers, _price, issueIndex);
        totalAmount = totalAmount.add(_price);
        lastTimestamp = block.timestamp;
        emit MultiBuy(address(this), _price);
    }

    function buy(uint256 _price, uint8[4] memory _numbers) external {
        require(!drawed(), 'drawed, can not buy now');
        require(!drawingPhase, 'drawing, can not buy now');
        require (_price >= minPrice, 'price must above minPrice');
        for (uint i = 0; i < 4; i++) {
            require (_numbers[i] <= maxNumber, 'exceed number scope');
        }
        LOTTERY_NFT_V2.newLotteryItem(DEAD, _numbers, _price, issueIndex);
        if (userInfo[msg.sender].length == 0) {
            totalAddresses = totalAddresses + 1;
        }
        totalAmount = totalAmount.add(_price);
        lastTimestamp = block.timestamp;
        uint64[keyLengthForEachBuy] memory userNumberIndex = generateNumberIndexKey(_numbers);
        for (uint i = 0; i < keyLengthForEachBuy; i++) {
            userBuyAmountSum[issueIndex][userNumberIndex[i]]=userBuyAmountSum[issueIndex][userNumberIndex[i]].add(_price);
        }
        hunny.safeTransferFrom(address(msg.sender), address(this), _price);
        emit MultiBuy(address(this), _price);
    }

    function multiBuy(uint256 _price, uint8[4][] memory _numbers) external {
        require (!drawed(), 'drawed, can not buy now');
        require(!drawingPhase, 'drawing, can not buy now');
        require (_price >= minPrice, 'price must above minPrice');

        // update price
        uint256 totalPrice  = _price.mul(_numbers.length);
        totalAmount = totalAmount.add(totalPrice);

        for (uint i = 0; i < _numbers.length; i++) {
            for (uint j = 0; j < 4; j++) {
                require (_numbers[i][j] <= maxNumber && _numbers[i][j] > 0, 'exceed number scope');
            }

            lastTimestamp = block.timestamp;
            uint64[keyLengthForEachBuy] memory numberIndexKey = generateNumberIndexKey(_numbers[i]);
            for (uint k = 0; k < keyLengthForEachBuy; k++) {
                userBuyAmountSum[issueIndex][numberIndexKey[k]] = userBuyAmountSum[issueIndex][numberIndexKey[k]].add(_price);
            }
        }

        LOTTERY_NFT_V2.newLotteryItems(msg.sender, _numbers.length, _numbers, _price, issueIndex);

        hunny.safeTransferFrom(address(msg.sender), address(this), totalPrice);
        emit MultiBuy(msg.sender, totalPrice);
    }

    function claimReward(uint256 _tokenId) external {
        uint256 reward;
        if (
            msg.sender == lotteryNFT.ownerOf(_tokenId)
            && !lotteryNFT.getClaimStatus(_tokenId)
        ) {
            reward = getRewardViewLegacy(_tokenId);
            lotteryNFT.claimReward(_tokenId);
        } else {
            require(msg.sender == LOTTERY_NFT_V2.ownerOf(_tokenId), "not from owner");
            require (!LOTTERY_NFT_V2.getClaimStatus(_tokenId), "claimed");
            reward = getRewardView(_tokenId);
            LOTTERY_NFT_V2.claimReward(_tokenId);
        }

        if(reward>0) {
            hunny.safeTransfer(address(msg.sender), reward);
        }
        emit Claim(msg.sender, _tokenId, reward);
    }

    function multiClaim(uint256[] memory _tickets) external {
        uint256 totalReward = 0;

        if (
            msg.sender == lotteryNFT.ownerOf(_tickets[0])
            && !lotteryNFT.getClaimStatus(_tickets[0])
        ) {
            for (uint i = 0; i < _tickets.length; i++) {
                uint256 reward = getRewardViewLegacy(_tickets[i]);
                if(reward>0) {
                    totalReward = reward.add(totalReward);
                }
            }
            lotteryNFT.multiClaimReward(_tickets);
        } else {
            for (uint i = 0; i < _tickets.length; i++) {
                require (msg.sender == LOTTERY_NFT_V2.ownerOf(_tickets[i]), "not from owner");
                require (!LOTTERY_NFT_V2.getClaimStatus(_tickets[i]), "claimed");
                uint256 reward = getRewardView(_tickets[i]);
                if(reward>0) {
                    totalReward = reward.add(totalReward);
                }
            }
            LOTTERY_NFT_V2.multiClaimReward(_tickets);
        }

        if(totalReward>0) {
            hunny.safeTransfer(address(msg.sender), totalReward);
        }

        emit MultiClaim(msg.sender, totalReward);
    }

    function generateNumberIndexKey(uint8[4] memory number) public pure returns (uint64[keyLengthForEachBuy] memory) {
        uint64[4] memory tempNumber;
        tempNumber[0]=uint64(number[0]);
        tempNumber[1]=uint64(number[1]);
        tempNumber[2]=uint64(number[2]);
        tempNumber[3]=uint64(number[3]);

        uint64[keyLengthForEachBuy] memory result;
        result[0] = tempNumber[0]*256*256*256*256*256*256 + 1*256*256*256*256*256 + tempNumber[1]*256*256*256*256 + 2*256*256*256 + tempNumber[2]*256*256 + 3*256 + tempNumber[3];

        result[1] = tempNumber[0]*256*256*256*256 + 1*256*256*256 + tempNumber[1]*256*256 + 2*256+ tempNumber[2];
        result[2] = tempNumber[0]*256*256*256*256 + 1*256*256*256 + tempNumber[1]*256*256 + 3*256+ tempNumber[3];
        result[3] = tempNumber[0]*256*256*256*256 + 2*256*256*256 + tempNumber[2]*256*256 + 3*256 + tempNumber[3];
        result[4] = 1*256*256*256*256*256 + tempNumber[1]*256*256*256*256 + 2*256*256*256 + tempNumber[2]*256*256 + 3*256 + tempNumber[3];

        result[5] = tempNumber[0]*256*256 + 1*256+ tempNumber[1];
        result[6] = tempNumber[0]*256*256 + 2*256+ tempNumber[2];
        result[7] = tempNumber[0]*256*256 + 3*256+ tempNumber[3];
        result[8] = 1*256*256*256 + tempNumber[1]*256*256 + 2*256 + tempNumber[2];
        result[9] = 1*256*256*256 + tempNumber[1]*256*256 + 3*256 + tempNumber[3];
        result[10] = 2*256*256*256 + tempNumber[2]*256*256 + 3*256 + tempNumber[3];

        return result;
    }

    function calculateMatchingRewardAmount() internal view returns (uint256[4] memory) {
        uint64[keyLengthForEachBuy] memory numberIndexKey = generateNumberIndexKey(winningNumbers);

        uint256 totalAmout1 = userBuyAmountSum[issueIndex][numberIndexKey[0]];

        uint256 sumForTotalAmout2 = userBuyAmountSum[issueIndex][numberIndexKey[1]];
        sumForTotalAmout2 = sumForTotalAmout2.add(userBuyAmountSum[issueIndex][numberIndexKey[2]]);
        sumForTotalAmout2 = sumForTotalAmout2.add(userBuyAmountSum[issueIndex][numberIndexKey[3]]);
        sumForTotalAmout2 = sumForTotalAmout2.add(userBuyAmountSum[issueIndex][numberIndexKey[4]]);

        uint256 totalAmout2 = sumForTotalAmout2.sub(totalAmout1.mul(4));

        uint256 sumForTotalAmout3 = userBuyAmountSum[issueIndex][numberIndexKey[5]];
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[6]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[7]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[8]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[9]]);
        sumForTotalAmout3 = sumForTotalAmout3.add(userBuyAmountSum[issueIndex][numberIndexKey[10]]);

        uint256 totalAmout3 = sumForTotalAmout3.add(totalAmout1.mul(6)).sub(sumForTotalAmout2.mul(3));

        return [totalAmount, totalAmout1, totalAmout2, totalAmout3];
    }

    function getMatchingRewardAmount(uint256 _issueIndex, uint256 _matchingNumber) public view returns (uint256) {
        return historyAmount[_issueIndex][5 - _matchingNumber];
    }

    function getTotalRewards(uint256 _issueIndex) public view returns(uint256) {
        require (_issueIndex <= issueIndex, '_issueIndex <= issueIndex');

        if(!drawed() && _issueIndex == issueIndex) {
            return totalAmount;
        }
        return historyAmount[_issueIndex][0];
    }

    function getRewardView(uint256 _tokenId) public view returns(uint256) {
        uint256 _issueIndex = LOTTERY_NFT_V2.getLotteryIssueIndex(_tokenId);
        uint8[4] memory lotteryNumbers = LOTTERY_NFT_V2.getLotteryNumbers(_tokenId);
        uint8[4] memory _winningNumbers = historyNumbers[_issueIndex];

        if (_winningNumbers[0] == 0) return 0;

        uint256 matchingNumber = 0;
        for (uint i = 0; i < lotteryNumbers.length; i++) {
            if (_winningNumbers[i] == lotteryNumbers[i]) {
                matchingNumber= matchingNumber +1;
            }
        }
        uint256 reward = 0;
        if (matchingNumber > 1) {
            uint256 amount = LOTTERY_NFT_V2.getLotteryAmount(_tokenId);
            uint256 poolAmount = getTotalRewards(_issueIndex).mul(allocation[4-matchingNumber]).div(100);
            reward = amount.mul(1e12).div(getMatchingRewardAmount(_issueIndex, matchingNumber)).mul(poolAmount);
        }
        return reward.div(1e12);
    }

    function getRewardViewLegacy(uint256 _tokenId) public view returns(uint256) {
        uint256 _issueIndex = lotteryNFT.getLotteryIssueIndex(_tokenId);
        uint8[4] memory lotteryNumbers = lotteryNFT.getLotteryNumbers(_tokenId);
        uint8[4] memory _winningNumbers = historyNumbers[_issueIndex];

        if (_winningNumbers[0] == 0) return 0;

        uint256 matchingNumber = 0;
        for (uint i = 0; i < lotteryNumbers.length; i++) {
            if (_winningNumbers[i] == lotteryNumbers[i]) {
                matchingNumber= matchingNumber +1;
            }
        }
        uint256 reward = 0;
        if (matchingNumber > 1) {
            uint256 amount = lotteryNFT.getLotteryAmount(_tokenId);
            uint256 poolAmount = getTotalRewards(_issueIndex).mul(allocation[4-matchingNumber]).div(100);
            reward = amount.mul(1e12).div(getMatchingRewardAmount(_issueIndex, matchingNumber)).mul(poolAmount);
        }
        return reward.div(1e12);
    }

    function lotteryInfoOf(uint256 issueId) public view returns (uint256[] memory) {
        if (issueId < 6) {
            return lotteryInfo[issueId];
        }
        return LOTTERY_NFT_V2.getLotteryInfo(issueId);
    }

    function lotteryInfoOfAccount(uint256 issueId, address account) public view returns (uint256[] memory) {
        uint256[] memory lotteries;
        uint256[] memory list = lotteryInfoOf(issueId);

        uint256 total;
        for (uint256 i = 0; i < list.length; i++) {
            if (issueId < 6) {
                if (lotteryNFT.ownerOf(list[i]) == account) {
                    total = total.add(1);
                }
            } else {
                if (LOTTERY_NFT_V2.ownerOf(list[i]) == account) {
                    total = total.add(1);
                }
            }
        }

        lotteries = new uint256[](total);
        uint256 idx;
        for (uint256 i = 0; i < list.length; i++) {
            if (issueId < 6) {
                if (lotteryNFT.ownerOf(list[i]) == account) {
                    lotteries[idx] = list[i];
                    idx += 1;
                }
            } else {
                if (LOTTERY_NFT_V2.ownerOf(list[i]) == account) {
                    lotteries[idx] = list[i];
                    idx += 1;
                }
            }
        }

        return lotteries;
    }

    function winnersOf(uint256 issueId) public view returns (uint256[] memory four, uint256[] memory three, uint256[] memory two) {
        uint8[4] memory _winningNumbers = historyNumbers[issueId];
        if (_winningNumbers[0] == 0) {
            four = new uint256[](0);
            three = new uint256[](0);
            two = new uint256[](0);
        } else {
            uint matchingFour;
            uint matchingThree;
            uint matchingTwo;
            uint256[] memory lotteries = lotteryInfoOf(issueId);

            for (uint i = 0; i < lotteries.length; i++) {
                uint matching;
                uint8[4] memory numbers = LOTTERY_NFT_V2.getLotteryNumbers(lotteries[i]);
                if (_winningNumbers[0] == numbers[0]) matching = matching + 1;
                if (_winningNumbers[1] == numbers[1]) matching = matching + 1;
                if (_winningNumbers[2] == numbers[2]) matching = matching + 1;
                if (_winningNumbers[3] == numbers[3]) matching = matching + 1;

                if (matching == 4) matchingFour += 1;
                if (matching == 3) matchingThree += 1;
                if (matching == 2) matchingTwo += 1;
            }

            four = new uint256[](matchingFour);
            three = new uint256[](matchingThree);
            two = new uint256[](matchingTwo);

            uint fourIdx;
            uint threeIdx;
            uint twoIdx;

            for (uint i = 0; i < lotteries.length; i++) {
                uint matching;
                uint8[4] memory numbers = LOTTERY_NFT_V2.getLotteryNumbers(lotteries[i]);
                if (_winningNumbers[0] == numbers[0]) matching = matching + 1;
                if (_winningNumbers[1] == numbers[1]) matching = matching + 1;
                if (_winningNumbers[2] == numbers[2]) matching = matching + 1;
                if (_winningNumbers[3] == numbers[3]) matching = matching + 1;

                if (matching == 4) {
                    four[fourIdx] = lotteries[i];
                    fourIdx += 1;
                }
                if (matching == 3) {
                    three[threeIdx] = lotteries[i];
                    threeIdx += 1;
                }
                if (matching == 2) {
                    two[twoIdx] = lotteries[i];
                    twoIdx += 1;
                }
            }
        }
    }

    // Update admin address by the previous dev.
    function setAdmin(address _adminAddress) public onlyOwner {
        adminAddress = _adminAddress;
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function adminWithdraw(uint256 _amount) public onlyAdmin {
        hunny.safeTransfer(address(msg.sender), _amount);
        emit DevWithdraw(msg.sender, _amount);
    }

    // Set the minimum price for one ticket
    function setMinPrice(uint256 _price) external onlyAdmin {
        minPrice = _price;
    }

    // Set the minimum price for one ticket
    function setMaxNumber(uint8 _maxNumber) external onlyAdmin {
        maxNumber = _maxNumber;
    }

    // Set the allocation for one reward
    function setAllocation(uint8 _allcation1, uint8 _allcation2, uint8 _allcation3) external onlyAdmin {
        allocation = [_allcation1, _allcation2, _allcation3];
    }

    function notifyRewardAmount(uint256 reward) public override onlyRewardsDistribution {
        totalAmount = totalAmount.add(reward);

        emit RewardAdded(msg.sender, reward);
    }

    function distributeContributionAmount(uint256 amount) private {
        uint256 hunnyBeeAmount = amount.mul(HUNNY_BEE_ALLOC).div(100);
        uint256 bumbleBeeAmount = amount.mul(BUMBLE_BEE_ALLOC).div(100);
        uint256 devAmount = amount.mul(DEV_ALLOC).div(100);
        uint256 burnAmount = amount.sub(hunnyBeeAmount).sub(bumbleBeeAmount).sub(devAmount);

        hunny.safeTransfer(DEV, devAmount);
        hunny.safeTransfer(HUNNY_BEE, hunnyBeeAmount);
        hunny.safeTransfer(BUMBLE_BEE, bumbleBeeAmount);
        hunny.safeTransfer(DEAD, burnAmount);
    }
}
