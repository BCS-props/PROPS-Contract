// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./governance.sol";
import "./getTokenByUniswap.sol";

/*
    보험료 계산 (nexus mutual) => 사실상 운영팀이 알아서 결정함.
    ***보험료 = bumpedPrice - priceDrop 
    ***bumpedPrice = spotPrice + capacity% of the pool to be used / 1% x 0.2
    ***bumpedPrice = 0.5% + 1% = 1.5%
    ***priceDrop = timeSinceLastCoverBuy * speed
    ***priceDrop = 0.5 days * 0.5% = 0.25%
    --------------------------------------------------------------------------------
*/

contract Mint721Token is ERC721URIStorage, ERC2981 {
    governance governances;
    getBalance getBalances;

    struct NFT_Data {
        uint8 coverTerm; // 0 : 30일, 1: 365일
        uint mintTime;
        uint tokenPrice;
        uint coverAmount;
        bool isActive; // true : 활성화, false : 비활성화
    }

    NFT_Data[] private NFT_Datas;
    ERC20 public token = ERC20(0xBd8C68BFC0Dc66C639B9CbD3AE65bEb94DE300a5); // test USDT CA
    string public baseURI;
    address public insurPool;
    address public admin;
    uint public tokenId;

    mapping(address => uint) private totalSpend;
    
    uint8 priceFormula_30 = 125; // 수수료율 1.25% | daily 0.0416%
    uint16 priceFormula_365 = 760; // 수수료율 7.60% | daily 0.0208%

    constructor(string memory _baseUri, address _insurPool, address _governance_address, address _admin) ERC721("InsurSand","IS"){
        getBalances = getBalance(0x2F5136C8f0Bdf1DC797Cb52419D28143D6F72f93); // 토큰 가격 가져오기 위한 CA 설정
        baseURI = _baseUri;
        insurPool = _insurPool; // 보험 기금 풀
        governances = governance(_governance_address); // 거버넌스 투표 컨트랙트
        admin = _admin; // 수수료율을 관리할 어드민 지정
        _setDefaultRoyalty(_insurPool, 500); // 5% 로열티 설정. << OPENSEA 와 같은 사이트에서 인식함. 실제 거래에선 적용 안됨.
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintNFT_Cover(uint8 _coverTerm, uint _amount, string memory _ipfsHash) public {
        address msgsender = msg.sender;
        uint coverPrice;
        if(_coverTerm == 0){ // 30일로 계산
            coverPrice = _amount * priceFormula_30 / 10000;
        } else if(_coverTerm == 1){ // 365일로 계산
            coverPrice = _amount * priceFormula_365 / 10000; 
        } else { // 다른 날짜 커버는 미완성이므로 revert
            revert("It is the wrong approach."); 
        }

        (uint token1, uint token2) = getBalances.getPoolBalances(); // 토큰 가격 계산 from uniswap
        uint currentTokenPrice = token1 / token2; // WETH 가격 = DAI 예치량 / WETH 예치량

        require(coverPrice <= token.balanceOf(msgsender),"Insufficient balances.");
        require(coverPrice != 0,"Invaild Cover Price");

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msgsender] += coverPrice;
        NFT_Datas.push(NFT_Data(_coverTerm, block.timestamp, currentTokenPrice , _amount, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(calculateVotePower(coverPrice), msgsender);

        _mint(msgsender, tokenId);
        _setTokenURI(tokenId++, string(abi.encodePacked(baseURI, _ipfsHash)));
    } // NFT 구매 시, 투표권 증가시키는 함수. 다른 컨트랙트에서 사용됨.
         // 30일 커버 | 민팅비 = 커버할 총량 * 1.25%
        // 365일 커버 | 민팅비 = 커버할 총량 * 7.60%

    function claimCover(uint _tokenId) public {
        require(msg.sender == ownerOf(_tokenId),"You are Not Owner of NFT."); // msg.sender 가 NFT 를 보유중인지 확인
        if(NFT_Datas[_tokenId].coverTerm == 0){
            require(NFT_Datas[_tokenId].isActive == true &&
            NFT_Datas[_tokenId].mintTime + 2592000 > block.timestamp,"Your Cover expired.");
        } // 30일 커버의 유효기간 확인 
        else if(NFT_Datas[_tokenId].coverTerm == 1){
            require(NFT_Datas[_tokenId].isActive == true && 
            NFT_Datas[_tokenId].mintTime + 31536000 > block.timestamp,"Your Cover expired.");
        } // 365일 커버의 유효기간 확인

        uint currentTokenPrice = 1800; // @@@@@@@ 토큰 가격 from uniswap @@@@@@@@
        require(NFT_Datas[_tokenId].tokenPrice * 50 / 100 >= currentTokenPrice
        ,"Your Claim is not Accepted. Check current token price first."); 
        // 현재 토큰 가격이 커버를 구매했을 당시 토큰 가격의 절반이라면, claim 해준다.
        // 토큰 가격이 $2000, 10000 amount 만큼 커버를 구매함.
        // 현재 가격이 $1000 이라면, 10000 amount 만큼 커버를 받는다?

        NFT_Datas[tokenId].isActive = false;
        token.transferFrom(address(this),msg.sender,NFT_Datas[tokenId].coverAmount);
    } // 보험금을 claim 하는 함수

    function setPriceFormula(uint8 _setFormula_30, uint8 _setFormula_365) public {
        require(msg.sender == admin,"Your are not admin");
        priceFormula_30 = _setFormula_30;
        priceFormula_365 = _setFormula_365;
    } // 커버 수수료 변경

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

    function getCurrentFormula_30() public view returns(string memory){
        return Strings.toString(priceFormula_30);
    } // 30일 커버의 보험비 계산

    function getCurrentFormula_365() public view returns(string memory){
        return Strings.toString(priceFormula_365);
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

    // 2nd eoa > 0x88cDBb31196Af16412F9a3D4196D645a830E5a4b
    // usdt > 0x078d1B0B379d1c76C9944Fa6ed5eEdf11D6A4D80
    // uri > https://teal-individual-peafowl-274.mypinata.cloud/ipfs/QmazmBGmFZJBXp5RAY83wZMVfXdSdyoq4SJkwajKH4s3o1
}