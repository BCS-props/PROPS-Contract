// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.18;

/*
거버넌스 투표에서 생각해야 할 것.
1. 투표권 갯수는 다른 컨트랙트에서
2. 제안 넘버, 안건 생성 시간, 안건 제안자(지갑주소), 제목, 내용, 찬반, 상태
3. 여러장의 투표권을 갖고 있는 유저에게 하나의 안건당 한번의 투표만 가능하게 할 것인가?
*/

contract governance {
    struct proposal {
        uint num; // 자동 카운팅
        uint time; // 자동 카운팅
        address maker; // msg.sender
        string subject;
        string detail;
        uint accept;
        uint deny;
        bool status; // false : 진행중, true : 종료
        voteResult voteResults;
    }

    struct myStatus { 
        voteCheck voteChecks;
        uint count;
    } // 특정 유저의 정보
    
    enum voteResult {
        inProgress,
        passed,
        rejected
    }

    enum voteCheck {
        notYet,
        accept,
        deny
    }
    
    proposal[] public proposals;

    mapping(address => mapping(uint => myStatus)) checkMyStatus; // 내 투표 확인하기
    mapping(address => uint) votePower; // 투표권 갯수
    
    address mintNFTContract;
    address admin;
    uint public P_number; // 제안된 안건 수.

    constructor(address _admin) {
        admin = _admin; 
    } // 관리자 지갑 주소 설정

    modifier checkVotePower{ 
        require(votePower[msg.sender] >= 1,"At least one voting power is required.");
        _;
    } // 유저가 갖고 있는 투표 수 확인

    function setMintNFTContract(address _addr) public {
        require(msg.sender == admin);
        mintNFTContract = _addr;
    } // mintNFT 컨트랙트 주소 설정

    function openProposal(string memory _subject, string memory _detail) public checkVotePower {
        votePower[msg.sender] -= 1;
        proposals.push( proposal ( ++P_number, block.timestamp, msg.sender,_subject, 
        _detail, 0, 0, false, voteResult.inProgress ));
    } // 안건 제안. 투표권을 1개 소모하고, 2주가 지나면 자동으로 종료 됨. 어떻게 자동종료..?

    function closeProposal(uint P_numbers) public {
        require(block.timestamp >= proposals[P_numbers].time + 2 weeks // 안건 제안 후 2주가 지난 상태에서 제안자가 종료
        && proposals[P_numbers].maker == msg.sender || admin == msg.sender); // 또는, admin 이 직접 close 가능.
        proposals[P_numbers].status = true;
        if(proposals[P_numbers].accept > proposals[P_numbers].deny 
        /* && users * 33 / 100 =< proposals[P_numbers].accept + proposals[P_numbers].deny 
        총 투표수가 전체 유저의 33% 이상이면서 찬성표가 반대표보다 많아야 passed. */){
        proposals[P_numbers].voteResults = voteResult.passed;
        } else {
        proposals[P_numbers].voteResults = voteResult.rejected;
        }
    }

    function openVotesAccept(uint P_numbers) public checkVotePower {
        require(checkMyStatus[msg.sender][P_numbers].count < 4,"Not allowed to vote on this proposal more than three times");
        votePower[msg.sender] -= 1;
        proposals[P_numbers].accept++;
        checkMyStatus[msg.sender][P_numbers].count++;
        checkMyStatus[msg.sender][P_numbers].voteChecks = voteCheck.accept;
    } // n번 안건 찬성 버튼을 누르면 작동

    function openVotesDeny(uint P_numbers) public checkVotePower {
        require(checkMyStatus[msg.sender][P_numbers].count < 4,"Not allowed to vote on this proposal more than three times");
        votePower[msg.sender] -= 1;
        proposals[P_numbers].deny++;
        checkMyStatus[msg.sender][P_numbers].count++;
        checkMyStatus[msg.sender][P_numbers].voteChecks = voteCheck.deny;
    } // n번 안건 반대 버튼을 누르면 작동

    function increaseVotePower(uint _number, address _address) external {
        require(mintNFTContract == msg.sender); // 민팅 컨트랙트에서만 호출 가능
        votePower[_address] += _number;
    } // NFT 구매 시, 투표권 증가시키는 함수. 다른 컨트랙트에서 사용됨.

    function userVoteCheck(uint P_numbers) public view returns(myStatus memory){
        return checkMyStatus[msg.sender][P_numbers]; 
    } // n번 안건에 투표 했는지 확인.

    function getVotePower(address msgsender) public view returns(uint){
        return votePower[msgsender]; 
    } // 유저의 투표권 갯수 값 불러오기

    function getP_number() public view returns(uint){
        return P_number; 
    } // 현재 제안된 안건의 갯수 값 불러오기

    function getMyStatus(uint P_numbers) public view returns(uint){
        return checkMyStatus[msg.sender][P_numbers].count; 
    } // 유저가 n번째 안건에 몇번 투표했는지 값 불러오기

    function getProposal(uint P_number) public view returns(proposal memory){
        return proposals[P_number-1]; 
    } // 안건번호로 카운팅.

    function Test_increasedVotePower() public {
        votePower[msg.sender] += 3;
    } // 테스트를 위해 만든 버튼!!!!!
}