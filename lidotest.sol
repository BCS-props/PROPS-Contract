// SPDX-License-Identifier: MIT
pragma solidity 0.8.8-0.8.18;

import "contracts/0.8.9/WithdrawalQueue.sol";
import "contracts/0.8.9/WithdrawalQueueBase.sol";

contract testLido is WithdrawalQueueBase {
    WithdrawalQueue withdrawalQueues;

    constructor(){
        withdrawalQueues = WithdrawalQueue(0xCF117961421cA9e546cD7f50bC73abCdB3039533);
    }

    function getRequests(address msgsender) public view returns(uint[] memory){
        return withdrawalQueues.getWithdrawalRequests(msgsender);
    }

    function checkStatus(uint[] memory _id) public view returns(uint){
        require(_id.length == 1);

        uint withdrawalAmount;
        uint timestamp;
        address owners;
        bool isFinalizeds;
        WithdrawalRequestStatus[] memory status;

        status = withdrawalQueues.getWithdrawalStatus(_id);
        (isFinalizeds,owners,timestamp,withdrawalAmount) = 
        (status[0].isFinalized,status[0].owner,status[0].timestamp,status[0].amountOfStETH);

        if(withdrawalAmount >= 10 ** 15 && timestamp + 432000 > block.timestamp && owners == msg.sender && isFinalizeds == false){
            return withdrawalAmount;
        } else revert("false");
    }
 
    //@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//

    // /// @notice output format struct for `_getWithdrawalStatus()` method
    // struct WithdrawalRequestStatus {
    //     /// @notice stETH token amount that was locked on withdrawal queue for this request
    //     uint256 amountOfStETH;
    //     /// @notice amount of stETH shares locked on withdrawal queue for this request
    //     uint256 amountOfShares;
    //     /// @notice address that can claim or transfer this request
    //     address owner;
    //     /// @notice timestamp of when the request was created, in seconds
    //     uint256 timestamp;
    //     /// @notice true, if request is finalized
    //     bool isFinalized;
    //     /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
    //     bool isClaimed;
    // }

    //     function getWithdrawalStatus(uint256[] calldata _requestIds)
    //     external
    //     view
    //     returns (WithdrawalRequestStatus[] memory statuses)
    // {
    //     statuses = new WithdrawalRequestStatus[](_requestIds.length);
    //     for (uint256 i = 0; i < _requestIds.length; ++i) {
    //         statuses[i] = _getStatus(_requestIds[i]);
    //     }
    // }

    // function getWithdrawalRequests(address _owner) external view returns (uint256[] memory requestsIds) {
    //     return _getRequestsByOwner()[_owner].values();
    // }

    // /// @notice Returns status for requests with provided ids
    // /// @param _requestIds array of withdrawal request ids
    // function getWithdrawalStatus(uint256[] calldata _requestIds)
    //     external
    //     view
    //     returns (WithdrawalRequestStatus[] memory statuses)
    // {
    //     statuses = new WithdrawalRequestStatus[](_requestIds.length);
    //     for (uint256 i = 0; i < _requestIds.length; ++i) {
    //         statuses[i] = _getStatus(_requestIds[i]);
    //     }
    // }


    //     function getClaimableEther(uint256[] calldata _requestIds, uint256[] calldata _hints)
    //     external
    //     view
    //     returns (uint256[] memory claimableEthValues)
    // {
    //     claimableEthValues = new uint256[](_requestIds.length);
    //     for (uint256 i = 0; i < _requestIds.length; ++i) {
    //         claimableEthValues[i] = _getClaimableEther(_requestIds[i], _hints[i]);
    //     }
    // }
}