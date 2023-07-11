// SPDX-License-Identifier: MIT
pragma solidity 0.8.8-0.8.18;

import "contracts/0.8.9/WithdrawalQueue.sol";
import "contracts/0.8.9/WithdrawalQueueBase.sol";

contract lido is WithdrawalQueueBase {
    WithdrawalQueue withdrawalQueues;

    constructor(){
        withdrawalQueues = WithdrawalQueue(0xCF117961421cA9e546cD7f50bC73abCdB3039533);
    }

    function getRequests(address msgsender) public view returns(uint[] memory){
        return withdrawalQueues.getWithdrawalRequests(msgsender);
    }

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

    function getAmountTimestamp(uint[] memory _id) public view returns(uint, uint){
        require(_id.length == 1);

        uint withdrawalAmount;
        uint timestamp;
        WithdrawalRequestStatus[] memory status;

        status = withdrawalQueues.getWithdrawalStatus(_id);
        (timestamp,withdrawalAmount) = (status[0].timestamp,status[0].amountOfStETH);
        
        return (timestamp,withdrawalAmount);
    }
}