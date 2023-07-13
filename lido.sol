// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "0.8.9/WithdrawalQueue.sol";
import "0.8.9/WithdrawalQueueBase.sol";
import "getTokenByUniswap.sol";

// Lido 파이낸스의 출금 대기열 정보를 받아오는 컨트랙트
contract lido is WithdrawalQueueBase {
    WithdrawalQueue withdrawalQueues;
    getPoolsBalances getTokenBalance;

    constructor(){
        withdrawalQueues = WithdrawalQueue(0xCF117961421cA9e546cD7f50bC73abCdB3039533);
        getTokenBalance = getPoolsBalances(0x238f0c7C5eA55281C8035FB2EC2255070c1de840);
    }
    
    // Lido 에서 출금 신청한 주소 값의 모든 출금 신청 id 값을 반환
    function getRequests(address msgsender) public view returns(uint[] memory){
        return withdrawalQueues.getWithdrawalRequests(msgsender);
    }

    // 커버 구매 로직에 사용되는 함수. 아래의 사항을 확인한 후 이더 갯수, 출금 신청 시간 값을 반환해줌
    // 0.1 ether 이상, 현재 시각이 출금 신청 시각 + 5일이 지나지 않았는지, 민팅하는 사람이 출금 신청자인지, 출금이 완료되지 않았는지.
    function checkStatus(uint[] memory _id) public view returns(uint, uint){
        require(_id.length == 1);

        uint withdrawalAmount;
        uint timestamp;
        address owners;
        bool isFinalizeds;
        WithdrawalRequestStatus[] memory status;

        status = withdrawalQueues.getWithdrawalStatus(_id);
        (isFinalizeds,owners,timestamp,withdrawalAmount) = 
        (status[0].isFinalized,status[0].owner,status[0].timestamp,status[0].amountOfStETH);

        if(withdrawalAmount >= 10 ** 17 && timestamp + 432000 > block.timestamp && owners == tx.origin && isFinalizeds == false){
            return (withdrawalAmount,timestamp);
        } else revert("false");
    }

    // Lido 출금 신청한 시간, 이더 갯수를 반환
    function getAmountTimestamp(uint[] memory _id) public view returns(uint, uint){
        require(_id.length == 1);

        uint withdrawalAmount;
        uint timestamp;
        WithdrawalRequestStatus[] memory status;

        status = withdrawalQueues.getWithdrawalStatus(_id);
        (timestamp,withdrawalAmount) = (status[0].timestamp,status[0].amountOfStETH);
        
        return (timestamp,withdrawalAmount);
    }

    // 1__보험료 계산, 시간 차이에 의한 할인율 계산 ( unstaking cover )
    function calculateLido(uint _amount, uint _coverRatio, uint _timestamp) public view returns(uint, uint){

        // 현재 wETH 가격 가져옴
        uint currentTokenPrice = getTokenBalance.getWETHBalances();

        // 출금 신청 시간과 커버 신청 시간의 차이를 계산
        uint amount = _amount * currentTokenPrice / (10 ** 18);

        // timeDiffer => 3자리 값 반환. 120 = 12.0%.  출금 신청 후 2.5 일 뒤 커버 신청했다면 50.0 %.
        uint timeDiffer = (7200 - ((_timestamp + 432000 - block.timestamp) / 60)) * 1000 / 7200;
        uint coverPrice = (amount * _coverRatio / 1500) - ((amount * _coverRatio / 100) * timeDiffer / 15000);
        return (coverPrice, timeDiffer);
    }

    // 2__보험료 계산, 시간 차이에 의한 할인율 계산 ( unstaking cover )
    function calculateLido_two(uint[] memory _id, uint _coverRatio) public view returns(uint, uint){
        // id 값으로 받아온 시간, 이더 수량
        (uint _timestamp, uint _amount) = getAmountTimestamp(_id);

        // 현재 wETH 가격 가져옴
        uint currentTokenPrice = getTokenBalance.getWETHBalances();

        // 출금 신청 시간과 커버 신청 시간의 차이를 계산
        uint amount = _amount * currentTokenPrice / (10 ** 18);

        // timeDiffer => 3자리 값 반환. 120 = 12.0%.  출금 신청 후 2.5 일 뒤 커버 신청했다면 50.0 %.
        uint timeDiffer = (7200 - ((_timestamp + 432000 - block.timestamp) / 60)) * 1000 / 7200;
        uint coverPrice = (amount * _coverRatio / 1500) - ((amount * _coverRatio / 100) * timeDiffer / 15000);
        return (coverPrice, timeDiffer);
    }
}