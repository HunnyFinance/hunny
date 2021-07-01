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

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract HunnyLotteryNFTV2 is OwnableUpgradeable, ERC1155Upgradeable {
    using SafeMathUpgradeable for uint256;

    uint256 internal _counter;

    // issueID -> tokenIDs
    mapping (uint256 => uint256[]) public lotteryInfo;

    // tokenID -> numbers
    mapping (uint256 => uint8[4]) public lotteryNumbers;

    // tokenID -> amount
    mapping (uint256 => uint256) public lotteryAmount;

    // tokenID -> owner
    mapping (uint256 => address) public owners;

    // tokenID -> issueID
    mapping (uint256 => uint256) public issueIndex;

    // tokenID -> bool
    mapping (uint256 => bool) public claimInfo;

    function initialize() public initializer {
        __Ownable_init();
        __ERC1155_init("hlt");
    }

    function newLotteryItem(address player, uint8[4] memory _lotteryNumber, uint256 _amount, uint256 _issueIndex) external onlyOwner {
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _counter;
        amounts[0] = 1;

        lotteryNumbers[_counter] = _lotteryNumber;
        lotteryAmount[_counter] = _amount;
        lotteryInfo[_issueIndex].push(_counter);
        owners[_counter] = player;
        issueIndex[_counter] = _issueIndex;

        _counter = _counter.add(1);

        _mintBatch(player, tokenIds, amounts, msg.data);
    }

    function newLotteryItems(address player, uint256 _numberOfTickets, uint8[4][] memory _lotteryNumbers, uint256 _amount, uint256 _issueIndex) external onlyOwner {
        uint256[] memory amounts = new uint256[](_numberOfTickets);
        uint256[] memory tokenIds = new uint256[](_numberOfTickets);

        for (uint8 i = 0; i < _numberOfTickets; i++) {
            tokenIds[i] = _counter;
            amounts[i] = 1;

            lotteryNumbers[_counter] = _lotteryNumbers[i];
            lotteryAmount[_counter] = _amount;
            lotteryInfo[_issueIndex].push(_counter);
            issueIndex[_counter] = _issueIndex;
            owners[_counter] = player;

            _counter = _counter.add(1);
        }

        _mintBatch(player, tokenIds, amounts, msg.data);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return owners[tokenId];
    }
    function getLotteryInfo(uint256 tokenId) external view returns (uint256[] memory) {
        return lotteryInfo[tokenId];
    }
    function getLotteryNumbers(uint256 tokenId) external view returns (uint8[4] memory) {
        return lotteryNumbers[tokenId];
    }
    function getLotteryAmount(uint256 tokenId) external view returns (uint256) {
        return lotteryAmount[tokenId];
    }
    function getLotteryIssueIndex(uint256 tokenId) external view returns (uint256) {
        return issueIndex[tokenId];
    }
    function claimReward(uint256 tokenId) external onlyOwner {
        claimInfo[tokenId] = true;
    }
    function multiClaimReward(uint256[] memory _claimTokenIDs) external onlyOwner {
        for (uint i = 0; i < _claimTokenIDs.length; i++) {
            claimInfo[_claimTokenIDs[i]] = true;
        }
    }
    function getClaimStatus(uint256 tokenId) external view returns (bool) {
        return claimInfo[tokenId];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        owners[id] = to;
        super.safeTransferFrom(from, to, id, amount, data);
    }
}
