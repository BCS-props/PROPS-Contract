// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./governance.sol";

/*
    들어가야 하는 것들.
ok  1. 총 계약 수 (totalSupply)
ok  2. 민팅 시, 보험 기금으로 전송
    ***보험료 = bumpedPrice - priceDrop 
    

    ***bumpedPrice = spotPrice + capacity% of the pool to be used / 1% x 0.2
    ***bumpedPrice = 0.5% + 1% = 1.5%

    ***priceDrop = timeSinceLastCoverBuy * speed
    ***priceDrop = 0.5 days * 0.5% = 0.25%

ok  3. 민팅 날짜 (30일, 1년) => (attributes 안에 넣기)
ok  4. 커버 종류(eth? staking?) 를 어떻게 나눌지? (attributes 안에 넣기
ok  5. 커버 amount (attributes 안에 넣기)
    6. nft 를 가지고 있음을 증명하면 보험금 지급ok ? 어떻게? (balanceOf 함수 사용, attributes..?)

    --------------------------------------------------------------------------------

ok  1. 내가 보유한 스테이블 코인 갯수
  2. 내가 보험계약에 쓴 금액
ok  3. 투표권 갯수
*/

contract Mint721Token is ERC721Enumerable, ERC2981 {
    governance governances;

    struct NFT_Data {
        uint mintTime;
        uint coinPrice;
        uint coverAmount;
        bool isActive;
    }
    NFT_Data[] NFT_Datas;

    string public URI;
    address insurPool;
    address governance_address;
    uint tokenId;
    uint LastMintedTime;

    mapping(address => mapping(uint => NFT_Data)) NFT;
    mapping(address => uint) totalSpend;

    uint8 priceFormula = 75; // 수수료율

    constructor(string memory _uri, address _insurPool, address _governance_address) ERC721("Sand Cover","SC"){
        URI = _uri;
        insurPool = _insurPool;
        _setDefaultRoyalty(_insurPool, 500); // 5% 로열티 설정. << OPENSEA 와 같은 사이트에서 인식함. 실제 거래에선 적용 안됨.
        governances = governance(_governance_address);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintNFT_Cover() public payable {
        address msgsender = msg.sender;
        IERC20 token = IERC20(0x078d1B0B379d1c76C9944Fa6ed5eEdf11D6A4D80);
        uint coverPrice = msg.value * (priceFormula / 100);
        require(coverPrice <= token.balanceOf(msgsender),"Your balance is not enough.");
        token.transferFrom(msgsender, insurPool, coverPrice);
        totalSpend[msgsender] += coverPrice;
        NFT_Datas.push(NFT_Data(block.timestamp, 1000 ,msg.value, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(calculateVotePower(coverPrice), msgsender);
        _mint(msgsender, ++tokenId);
    }

    function tokenURI(uint) public view override returns(string memory){
        uint tokenIds = tokenId+1;
        return string(abi.encodePacked(URI, "/", Strings.toString(tokenIds), ".json"));
    } // uri 붙히는 작업

    function getTotalSpend(address _msgsender) public view returns(uint){
        return totalSpend[_msgsender];
    } // 보험 구매에 사용한 금액 총액

    function calculateVotePower(uint _amount) internal pure returns(uint){
        if(_amount >= 1 && _amount < 100){
            return 1;
        } else if(_amount <= 200){
            return 2;
        } else {
            return 3;
        }
    } // 민팅 비용에 따른 투표권 지급을 계산하는 함수
}