// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol";
import "./governance.sol";

/*
    보험료 계산 (nexus mutual)
    ***보험료 = bumpedPrice - priceDrop 
    ***bumpedPrice = spotPrice + capacity% of the pool to be used / 1% x 0.2
    ***bumpedPrice = 0.5% + 1% = 1.5%
    ***priceDrop = timeSinceLastCoverBuy * speed
    ***priceDrop = 0.5 days * 0.5% = 0.25%
    --------------------------------------------------------------------------------
*/

contract Mint721Token is ERC721Enumerable, ERC2981 {
    governance governances;

    struct NFT_Data {
        uint mintTime;
        uint tokenPrice;
        uint coverAmount;
        bool isActive; // true : 활성화, false : 비활성화
    }
    NFT_Data[] private NFT_Datas;

    ERC20 public token = ERC20(0x078d1B0B379d1c76C9944Fa6ed5eEdf11D6A4D80); // test USDT CA
    string public URI;
    address public insurPool;
    address public admin;
    uint public tokenId = 1;

    mapping(address => uint) private totalSpend;
    mapping(uint => uint) public totalVotePower;
    
    uint8 priceFormula_30 = 125; // 수수료율 1.25%
    uint8 priceFormula_365 = 100; // 수수료율 1.00%

    constructor(string memory _uri, address _insurPool, address _governance_address, address _admin) ERC721("Sand Cover","SC"){
        URI = _uri;
        insurPool = _insurPool; // 보험 기금 풀
        governances = governance(_governance_address); // 거버넌스 투표 컨트랙트
        admin = _admin; // 수수료율을 관리할 어드민 지정
        _setDefaultRoyalty(_insurPool, 500); // 5% 로열티 설정. << OPENSEA 와 같은 사이트에서 인식함. 실제 거래에선 적용 안됨.
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintNFTCover_30(uint _a) public {
        address msgsender = msg.sender;
        uint coverPrice = _a * priceFormula_30 / 1000;
        uint currentTokenPrice = 1000; // 코인 가격 from uniswap
        require(coverPrice <= token.balanceOf(msgsender),"Your balance is not enough.");
        require(coverPrice != 0,"Invaild Cover Price");

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msgsender] += coverPrice;
        NFT_Datas.push(NFT_Data(block.timestamp, currentTokenPrice , _a, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(calculateVotePower(coverPrice), msgsender);
        governances.increaseTotalVotePower(calculateVotePower(coverPrice));
        _mint(msgsender, tokenId++);
    } // 30일 커버 | 민팅비 = 커버할 총량 * 1.25%

    function mintNFTCover_365(uint _a) public {
        address msgsender = msg.sender;
        uint coverPrice = _a * priceFormula_365 / 1000;
        uint currentTokenPrice = 1000; // 토큰 가격 from uniswap
        require(coverPrice <= token.balanceOf(msgsender),"Your balance is not enough.");
        require(coverPrice != 0,"Invaild Cover Price");

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msgsender] += coverPrice;
        NFT_Datas.push(NFT_Data(block.timestamp, currentTokenPrice , _a, true));
        governances.increaseVotePower(calculateVotePower(coverPrice), msgsender);
        governances.increaseTotalVotePower(calculateVotePower(coverPrice));
        _mint(msgsender, tokenId++);
    } // 365일 커버 | 민팅비 = 커버할 총량 * 1%

    function claimCover(uint _tokenId) public {
        require(msg.sender == ownerOf(_tokenId),"You are Not Owner of NFT."); // msg.sender 가 NFT 를 보유중인지 확인
        require(NFT_Datas[_tokenId].isActive == true,"This cover is expired."); // NFT 가 유효한지 확인
        uint currentTokenPrice = 1000; // 토큰 가격 from uniswap

        // 코인 가격 가져오는 로직
    
        
        NFT_Datas[tokenId-1].isActive = false;
        token.transferFrom(address(this),msg.sender,NFT_Datas[tokenId-1].coverAmount);
    } // 보험금을 claim 하는 함수

    function setPriceFormula(uint8 _setFormula_30, uint8 _setFormula_365) public {
        require(msg.sender == admin,"Your are not admin");
        priceFormula_30 = _setFormula_30;
        priceFormula_365 = _setFormula_365;
    } // 커버 수수료 변경

    function tokenURI(uint) public view override returns(string memory){
        if(NFT_Datas[tokenId-1].isActive){
            return string(abi.encodePacked(URI, "/", Strings.toString(tokenId), ".json"));
        } else {
            return string(abi.encodePacked(URI, "/", Strings.toString(tokenId), ".json"));
        }
    } // uri 붙히는 작업, cover 가 활성화 된 상태라면 1, 아니라면 2번 이미지 띄워줌

    function getTotalCoverAmount() public view returns(uint){
        uint TotalCoverAmount;
        for(uint i; i < NFT_Datas.length; i++){
            TotalCoverAmount += NFT_Datas[i].coverAmount;
        }
        return TotalCoverAmount;
    } // 총 커버 금액 (만료된 커버 포함)

    function getTotalActiveCoverAmount() public view returns(uint){
        uint TotalActiveCoverAmount;
        for(uint i; i < NFT_Datas.length; i++){
            if(NFT_Datas[i].isActive == true){
                TotalActiveCoverAmount += NFT_Datas[i].coverAmount;
            }
        }
        return TotalActiveCoverAmount;
    } // 총 커버 금액 (만료된 커버 제외)
        
    function getTotalSpend(address _msgsender) public view returns(uint){
        return totalSpend[_msgsender];
    } // 보험 구매에 사용한 금액 총액

    function getCurrentFormula_30() public view returns(uint){
        return priceFormula_30 / 1000;
    } // 30일 커버의 보험비 계산

    function getCurrentFormula_365() public view returns(uint){
        return priceFormula_365 / 1000;
    } // 365일 커버의 보험비 계산

    function calculateVotePower(uint _amount) internal pure returns(uint){
        require(_amount > 0,"Cover Price is invaild.");
        if(_amount < 100){
            return 1;
        } else if(_amount <= 200){
            return 2;
        } else {
            return 3;
        }
    } // 민팅 비용에 따른 투표권 지급을 계산하는 함수 (internal)

    // governance ca > 0x4fc7Db345FA6f0C4725772a694ff1A3a49E2E738
    // 2nd eoa > 0x88cDBb31196Af16412F9a3D4196D645a830E5a4b
    // usdt > 0x078d1B0B379d1c76C9944Fa6ed5eEdf11D6A4D80
    // uri > https://teal-individual-peafowl-274.mypinata.cloud/ipfs/QmazmBGmFZJBXp5RAY83wZMVfXdSdyoq4SJkwajKH4s3o1
}