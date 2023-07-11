// SPDX-License-Identifier: MIT
pragma solidity 0.8.9-0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {IERC20} from "@openzeppelin/contracts@v4.4/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./governance.sol";
import "./getTokenByUniswap.sol";
import "lido.sol";

/*
    --------------------------------------------------------------------------------
    @@@ 가격 하락 보험
    보험 가입자가 토큰 20개를 들고있거나, 조만간 20개를 사서 투자하고 싶음. 현재 20개의 토큰 가치는 200불이다.
    그런데, 그냥 현물 투자를 하기엔 너무 리스크가 큼. 가격이 20% 정도 하락할 수도 있다는 생각을 하고 보험 가입 서비스를 이용하러 옴.

    1. 20개의 토큰가치인 200불(200 usdt) 을 갖고있는지 확인.
    2. 200불의 20% 를 커버 보험 가입으로 사용.
    3. (40불 * 기간별, 토큰별 보혐료율) 적용 한 금액을 보험료 결제, NFT 를 민팅함
    4. 얼마 후, 민팅 시의 가격에서 20% 하락. 보험금 청구하러 옴
    5. 청구할 때, 필요한 정보들 => 기간, 토큰타입(가격확인), 얼마만큼의 보험금을 청구할지
    
    프론트 : 얼마 만큼의 토큰을 커버할건지 확인함 => uniswap 풀 가격 가져와서 현재 토큰의 가격을 프론트에 띄워줌
    위에서 받은 1토큰당 가격에, 커버할 토큰 갯수를 사용자가 입력, mintNFT 함수에 인자로 들어갈 _amount(가격 x 토큰) 값이 나옴.
    예를 들어, 토큰 20개 x 10불 = 200불의 _amount 값을 설정.
    사용자는 몇% 하락했을 때, 보험금을 지급받을 지 결정하고, 정수단위(15,45,50..)를 _coverRatio 인자로 넣음.
    20을 입력했다면, 200불의 20% 인 40불에 기간별, 토큰별 보혐료율을 곱해서 지불할 금액으로 띄워주고 approve 시키고 민팅
    
    컨트랙트 : 200불의 _amount, 20의 _coverRatio 를 설정하고 민팅을 눌렀다.
    40불의 토큰을 전송받아서 insurPool 주소로 넘기고 NFT 민팅해줌.
    토큰의 가격이 20% 하락할 경우, NFT 보유자가 보험금 받으러 옴.
    Claim 로직에서는, 아래 3가지 사항을 확인.
    1. NFT 의 주인인가? (ownerOf 확인)
    2. 유효한가? (기간, 이미 청구했는지)(term, minttime, isActive 확인)
    3. 토큰의 가격이 20% 만큼 하락했는가? (ratio, type 확인)
    확인 후 coverAmount * ratio 만큼을 msg.sender 에게 지급함.

    @@@ 언스테이킹 보험
    보험 가입자가 Lido 의 이더리움 스테이킹 서비스를 이용 중임.
    가격하락이 예상되어 언스테이킹 함. 하지만, 출금까지 짧으면 1일. 길면 5일을 기다려야 함.
    가격 급락 시, 출금 신청이 많아지게 된다면 최대 기간인 5일을 기다릴 확률이 높아짐.
    이러한 이유로, 보험 가입자는 출금 대기 기간 동안,
    자신이 가진 1 이더를 20% 하락만큼의 보장을 해주는 보험을 가입하려고 함.
    Lido 출금 신청으로 부터 5일의 기간이 보험 커버 기간임.
    
    프론트 : 보험 가입 예정자의 지갑주소 값을 이용해, 현재 출금 대기 중인지 확인하고 출금 신청 id 를 띄워줌
    보험 가입을 원하는 출금 신청 id 를 선택한 후, coverRatio 20% 설정 후 민팅.

    컨트랙트 : 민팅 로직에서는, 보험 가입자의 정보를 Lido withdrawal 컨트랙트에서 가져옴.
    보험 가입 조건
    1. 0.1 ether 이상, 출금 진행 중 일것.
    2. 보험 가입자의 지갑 주소가 Lido 의 출금 신청한 owner 일 것.
    주의 사항
    1. Lido 출금 신청 시각 + 5일의 기간만을 고정적으로 커버함. (보험을 구매한 시각이 아님.)
    2. 출금 신청 시각 + 5일 이내에 Lido 로 부터 출금이 완료되어도 커버는 유효함.
    3. 출금 신청 시각 + 5일 이후까지 출금이 완료되지 않아도 커버는 종료.
    4. 기준 가격은 보험 가입 시점의 wETH 가격.
    현재 이더의 가격과 출금 예정량을 확인하고, 출금 예정 ether 를 현재 USDT(달러) 가치로 환산 후,
    NFT data struct 로 push. 보험료 결제 => insurPool 로 전송, 거버넌스 투표권 지급. 그리고 NFT 를 민팅.
    5일내로 20% 하락했다면, 보험금을 청구하러 옴.
    청구 로직에서는,
    1. NFT 의 주인인가? (ownerOf 확인)
    2. 유효한가? (기간, 이미 청구했는지)(minttime, isActive 확인)
    3. 이더의 가격이 20% 만큼 하락했는가? (ratio 확인)
    확인 후 coverAmount * ratio 만큼을 msg.sender 에게 지급함.
    --------------------------------------------------------------------------------
    보험료 계산 (nexus mutual) => 사실상 운영팀 마음대로 결정함.
    ***보험료 = bumpedPrice - priceDrop 
    ***bumpedPrice = spotPrice + capacity% of the pool to be used / 1% x 0.2
    ***bumpedPrice = 0.5% + 1% = 1.5%
    ***priceDrop = timeSinceLastCoverBuy * speed
    ***priceDrop = 0.5 days * 0.5% = 0.25%

    * 토큰마다 보험료를 다르게 적용함. (wETH + 0%, UNI +7%, LINK + 5%)
    ** 사용자가 지정한 하락률마다 보험료를 적용함 ( 30일 10~15% 구간 할증, 365일 10~20% 구간 할증 )
    *** 언스테이킹 보험은 5일의 기간을 커버함. 보험료는 가격하락 보험과 다르게 적용됨.
    --------------------------------------------------------------------------------
*/

contract Mint721Token is ERC721URIStorage, ERC2981 {
    governance governances;
    getPoolsBalances getTokenBalance;
    lido lidos;

    struct NFT_Data {
        uint coverTerm; // 0 : 30일, 1: 365일, 2 이상: Lido 의 id 값을 저장, 중복 가입 방지.
        uint8 tokenType; // 0 : wETH/Lido, 1 : UNI, 2 : LINK
        uint coverRatio; // 10~90% , 하락한 만큼 보험금 지급
        uint mintTime; // 보험 계약 시간
        uint tokenPrice; // 보험 계약(민팅) 당시의 토큰 가격 
        uint coverAmount; // 총 커버할 금액. 청구 가능 보험금 = coverAmount * coverRatio
        bool isActive; // true : 활성화, false : 비활성화
    }

    NFT_Data[] private NFT_Datas;
    IERC20 public token = IERC20(0x617489EDf1b0E9546D34aA50f22194F582E17f81); // test USDT CA
    string public baseURI;
    address public insurPool;
    address public admin;
    uint public tokenId;

    mapping(address => uint) private totalSpend;
    
    uint16 priceFormula_30 = 125; // 수수료율 1.25% | daily 0.0416%
    uint16 priceFormula_365 = 760; // 수수료율 7.60% | daily 0.0208%
    uint8 priceDiscount = 10; // 가격 할인율. 5000불 이상 커버를 구매할때, 100불마다 0.001% 할인. ex) 15000불 구매시 0.1% 할인

    constructor(string memory _baseUri, address _insurPool, address _governance_address, address _admin) ERC721("InsurSand","IS"){
        getTokenBalance = getPoolsBalances(0x238f0c7C5eA55281C8035FB2EC2255070c1de840);
        lidos = lido(0x8ED38Ce48c6e2A60Acb1c48Cf1ded93623eE5b82); // LIDO 의 출금 상태 CA 설정
        baseURI = _baseUri;
        insurPool = _insurPool; // 보험 기금 풀
        governances = governance(_governance_address); // 거버넌스 투표 컨트랙트
        admin = _admin; // 수수료율을 관리할 어드민 지정
        _setDefaultRoyalty(_insurPool, 500); // 5% 로열티 설정. << OPENSEA 와 같은 거래소에서 인식함. 개인간 거래에선 적용 안됨.
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721URIStorage, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // wETH 가격 하락에 대한 커버를 민팅하는 함수 ( 30일 : _coverRatio 10~15% 구간, 365일은 10~20% 구간이 제일 비쌈 )
    function mintNFTCover_wETH(uint _coverTerm, uint8 _coverRatio, uint _amount, string memory _ipfsHash) public {
        require(_coverRatio >= 10 && _coverRatio <= 90);
        
        uint wETHFee = 100; // wETH 토큰의 가중치 1
        uint coverPrice = calculateCoverFee(_coverTerm, _coverRatio, _amount); // 커버 가격 계산
        coverPrice = coverPrice * wETHFee / 100;

        uint currentTokenPrice = getTokenBalance.getWETHBalances(); // wETH 가격 계산 from uniswap | 1wETH = 1879 USDT

        // 보유한 wETH 의 평가액이 _amount 이상이면서 보유한 USDT 로 보험금 결제가 가능한지, 또는 USDT 보유량이 _amount 이상인지 확인.
        require(/*_amount <= token_wETH.balanceOf(msg.sender) * currentTokenPrice && coverPrice <= token.balanceOf(msg.sender) || */ 
        _amount <= token.balanceOf(msg.sender));
        require(coverPrice >= 1);

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msg.sender] += coverPrice;
        NFT_Datas.push(NFT_Data(_coverTerm, 0, _coverRatio, block.timestamp, currentTokenPrice, _amount, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(governances.calculateVotePower(coverPrice), msg.sender);

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId++, string(abi.encodePacked(baseURI, _ipfsHash)));
    }

    // UNI 가격 하락에 대한 커버를 민팅하는 함수
    function mintNFTCover_UNI(uint _coverTerm, uint8 _coverRatio, uint _amount, string memory _ipfsHash) public {
        require(_coverRatio >= 10 && _coverRatio <= 90);

        uint UNIFee = 107; // UNI 토큰의 가중치 7%
        uint coverPrice = calculateCoverFee(_coverTerm, _coverRatio, _amount); // 커버 가격 계산
        coverPrice = coverPrice * UNIFee / 100;

        uint currentTokenPrice = getTokenBalance.getUNIBalances(); // UNI 가격 계산 from uniswap | 1 UNI = 5.263 USDT

        // 보유한 UNI 의 평가액이 _amount 이상이면서 보유한 USDT 로 보험금 결제가 가능한지(테스트넷이므로 주석처리), 또는 USDT 보유량이 _amount 이상인지 확인.
        require(/*_amount <= token_UNI.balanceOf(msg.sender) * (10 ** 18) * currentTokenPrice && coverPrice <= token.balanceOf(msg.sender) || */ 
        _amount <= token.balanceOf(msg.sender));
        require(coverPrice >= 1);

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msg.sender] += coverPrice;
        NFT_Datas.push(NFT_Data(_coverTerm, 1, _coverRatio, block.timestamp, currentTokenPrice, _amount, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(governances.calculateVotePower(coverPrice), msg.sender);

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId++, string(abi.encodePacked(baseURI, _ipfsHash)));
    }

    // LINK 가격 하락에 대한 커버를 민팅하는 함수
    function mintNFTCover_LINK(uint _coverTerm, uint8 _coverRatio, uint _amount, string memory _ipfsHash) public {
        require(_coverRatio >= 10 && _coverRatio <= 90);

        uint LINKFee = 105; // LINK 토큰의 가중치 5%
        uint coverPrice = calculateCoverFee(_coverTerm, _coverRatio, _amount); // 커버 가격 계산
        coverPrice = coverPrice * LINKFee / 100;

        uint currentTokenPrice = getTokenBalance.getLINKBalances(); // LINK 가격 계산 from uniswap | 1 LINK = 6.172 USDT

        // 보유한 LINK 의 평가액이 _amount 이상이면서 보유한 USDT 로 보험금 결제가 가능한지(테스트넷이므로 주석처리), 또는 USDT 보유량이 _amount 이상인지 확인.
        require(/*_amount <= token_LINK.balanceOf(msg.sender) * (10 ** 18) * currentTokenPrice && coverPrice <= token.balanceOf(msg.sender) || */ 
        _amount <= token.balanceOf(msg.sender));
        require(coverPrice >= 1);

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msg.sender] += coverPrice;
        NFT_Datas.push(NFT_Data(_coverTerm, 2, _coverRatio, block.timestamp, currentTokenPrice, _amount, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(governances.calculateVotePower(coverPrice), msg.sender);

        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId++, string(abi.encodePacked(baseURI, _ipfsHash)));
    }

    // Lido 언스테이킹 커버를 민팅하는 함수 ( 10 ** 17 = 0.1 ether 이상 커버 가입 가능.) 
    function mintNFTCover_Lido(uint[] memory _id, uint _coverRatio, string memory _ipfsHash) public {
        require(_coverRatio >= 5 && _coverRatio <= 90);
        uint id = _id[0];

        // 같은 출금 요청 id 의 보험 중복 가입을 방지
        for(uint i ; tokenId > i ; i++){
            if(NFT_Datas[i].coverTerm == id){
                revert();
            }
        }
        
        (uint withdrawETH, uint _timestamp) = lidos.checkStatus(_id);
        require(1 >= withdrawETH / (10 ** 17) && _timestamp + 432000 > block.timestamp); // 0.1 ether 이상, 출금 신청 후 5일이 지나지 않아야 함
        uint currentTokenPrice = getTokenBalance.getWETHBalances();
        uint _amount = withdrawETH * currentTokenPrice / (10 ** 18);

        // 출금 신청 시간과 커버 신청 시간의 차이를 계산
        uint timeDiffer = (7200 - ((_timestamp + 432000 - block.timestamp) / 60)) * 1000 / 7200 + 1; // 4자리. 3560 => 35.6 %
        uint coverPrice = _amount * currentTokenPrice / 10 * _coverRatio * timeDiffer / 10000;

        token.transferFrom(tx.origin, insurPool, coverPrice);
        totalSpend[msg.sender] += coverPrice;
        NFT_Datas.push(NFT_Data(id, 0, _coverRatio, _timestamp, currentTokenPrice, _amount, true)); // 중간에 코인 가격 받아와서 넣어야 함
        governances.increaseVotePower(governances.calculateVotePower(coverPrice), msg.sender);

        _mint(msg.sender, tokenId); 
        _setTokenURI(tokenId++, string(abi.encodePacked(baseURI, _ipfsHash)));
    }

    // 보험금을 claim 하는 함수 (wETH, UNI, LINK, Lido, 모든 커버는 이 함수를 사용해서 claim)
    function claimCover(uint _tokenId) public {
        require(_tokenId < tokenId);
        require(msg.sender == ownerOf(_tokenId)); // msg.sender 가 NFT 를 보유중인지 확인

        // 30일 커버의 유효기간 확인
        if(NFT_Datas[_tokenId].coverTerm == 0){
            require(NFT_Datas[_tokenId].isActive == true &&
            NFT_Datas[_tokenId].mintTime + 2592000 > block.timestamp);

        } // 365일 커버의 유효기간 확인
        else if(NFT_Datas[_tokenId].coverTerm == 1){
            require(NFT_Datas[_tokenId].isActive == true && 
            NFT_Datas[_tokenId].mintTime + 31536000 > block.timestamp);
        } // Lido 커버의 5일 기간 확인
        else {
            require(NFT_Datas[_tokenId].isActive == true && NFT_Datas[_tokenId].mintTime + 432000 > block.timestamp);
        } 
        
        // wETH 가격하락 / Lido 언스테이킹의 claim 조건 확인 (현재 wETH 가격을 불러옴)
        if(NFT_Datas[_tokenId].tokenType == 0){
            uint currentTokenPrice = getTokenBalance.getWETHBalances() / 5; // claim 테스트를 위해서 /5
            require( NFT_Datas[_tokenId].tokenPrice - (NFT_Datas[_tokenId].tokenPrice * NFT_Datas[_tokenId].coverRatio / 100) >= currentTokenPrice);
        } // UNI 의 claim 조건 확인 (현재 UNI 가격을 불러옴)
        else if(NFT_Datas[_tokenId].tokenType == 1){
            uint currentTokenPrice = getTokenBalance.getUNIBalances() / 5; // claim 테스트를 위해서 /5
            require( NFT_Datas[_tokenId].tokenPrice - (NFT_Datas[_tokenId].tokenPrice * NFT_Datas[_tokenId].coverRatio / 100) >= currentTokenPrice);
        } // LINK 의 claim 조건 확인 (현재 LINK 가격을 불러옴)
        else if(NFT_Datas[_tokenId].tokenType == 2) {
            uint currentTokenPrice = getTokenBalance.getLINKBalances() / 5; // claim 테스트를 위해서 /5
            require( NFT_Datas[_tokenId].tokenPrice - (NFT_Datas[_tokenId].tokenPrice * NFT_Datas[_tokenId].coverRatio / 100) >= currentTokenPrice);
        }

        NFT_Datas[_tokenId].isActive = false;
        token.transfer(msg.sender, NFT_Datas[_tokenId].coverAmount * NFT_Datas[_tokenId].coverRatio / 100);
        // 여기에 NFT 이미지를 expired 로 변경하는 _setTokenURI(_tokenId, string(abi.encodePacked(baseURI, _ipfsHash))); 함수 넣기
    }

    // 거버넌스 address 변경
    function setGovernanceAddress(address _addr) public {
        require(msg.sender == admin);
        governances = governance(_addr);
    }

    // 총 커버 금액 (만료된 커버 포함)
    function getTotalCoverAmount() public view returns(uint){
        uint TotalCoverAmount;
        for(uint i; i < NFT_Datas.length; i++){
            TotalCoverAmount += NFT_Datas[i].coverAmount;
        }
        return TotalCoverAmount;
    }

    // 특정 tokenId 의 NFT Data 를 반환
    function getNFTDatas(uint _tokenId, address msgsender) public view returns(NFT_Data memory){
        require(msgsender == ownerOf(_tokenId));
        return NFT_Datas[_tokenId];
    }
        
    // 보험 구매에 사용한 금액 총액
    function getTotalSpend(address _msgsender) public view returns(uint){
        return totalSpend[_msgsender];
    }
    
    // 보험료를 %로 나타내는 함수.
    function getCoverFees(uint _coverTerm, uint8 _coverRatio, uint _amount) public view returns(uint){
        uint coverPrice = calculateCoverFee(_coverTerm, _coverRatio, _amount);
        uint coverFees = coverPrice * 1000000 / _coverRatio / _amount;
        return coverFees;
    }

    // 보험료 계산 함수
    function calculateCoverFee(uint _coverTerm, uint8 _coverRatio, uint _amount) public view returns(uint){
        uint coverPrice; // 커버 구매 시 내야 할 금액
        uint percentage; // 커버액 5100 불 이상의 할인율 적용

        if(_amount >= 5100){
            uint discount = _amount - 5000;
            percentage = discount / 100;
        } else {
            percentage = 0;
        }

        // 커버기간 30일인 경우 10~15% 구간이 제일 비쌈
        if(_coverTerm == 0){
            if(_coverRatio < 16) {
                unchecked{
                    uint ratioWeight = 91 - _coverRatio;
                    uint prePrice = (priceFormula_365 * 10 - percentage) * ratioWeight * _amount / 100;
                    coverPrice = prePrice * 625 / 100000000;
                }

            }
            else {
                unchecked{
                    uint ratioWeight = 91 - _coverRatio; 
                    uint prePrice = (priceFormula_30 * 10 - percentage) * ratioWeight * _amount / 100;
                    coverPrice = prePrice * 312 / 10000000;
                }
            }
        // 커버기간 365일인 경우 10~20% 구간이 제일 비쌈
        } else if(_coverTerm == 1){
                if(_coverRatio < 21) {
                    unchecked{
                        uint ratioWeight = 91 - _coverRatio; 
                        uint prePrice = (priceFormula_30 * 10 - percentage) * ratioWeight * _amount / 100;
                        coverPrice = prePrice * 625 / 10000000;
                    }
            }
            else {
                unchecked{
                    uint ratioWeight = 91 - _coverRatio; 
                    uint prePrice = (priceFormula_365 * 10 - percentage) * ratioWeight * _amount / 100;
                    coverPrice =  prePrice * 312 / 100000000;
                }
            }
        }
        return coverPrice;
    }

    // tokenURI 값 반환
    function getTokenURI(address msgsender) public view returns(string[] memory){
        string[] memory uriStorages = new string[](balanceOf(msgsender));
        uint count;

        for(uint i ; tokenId > i ; i++){
            if(keccak256(abi.encodePacked(ownerOf(i))) == keccak256(abi.encodePacked(msgsender))) {
                uriStorages[count++] = tokenURI(i);
            }
        }
        return uriStorages;
    }

    // 유저가 가진 tokenId 값 반환
    function getTokenId(address msgsender) public view returns(uint[] memory){
        uint[] memory tokenIdStorage = new uint[](balanceOf(msgsender));
        uint count;

        for(uint i ; tokenId > i ; i++){
            if(keccak256(abi.encodePacked(ownerOf(i))) == keccak256(abi.encodePacked(msgsender))){
                tokenIdStorage[count++] = i;
            }
        }
        return tokenIdStorage;
    }
}
    /* 
    usdt > 0x617489EDf1b0E9546D34aA50f22194F582E17f81
    insurPool (EOA) > 0x88cDBb31196Af16412F9a3D4196D645a830E5a4b
    BaseUri > https://teal-individual-peafowl-274.mypinata.cloud/ipfs/
    ipfsHash > QmRU8FLyF6wa34Jh9C2cbANiTezhb6XUVC5Y8LSbFz4KGG

    @@@ 현재 배포, 프론트에서 사용중인 컨트랙트들 => 12.07.2023
    erc20 - 0x617489EDf1b0E9546D34aA50f22194F582E17f81
    gov - 0x3c35155297EB63797Cd9c3952547b27f882603aE
    nft - 0x626af05a6394E639faEC2E93b602eaa7065C3e34
    getbalance - 0x2F5136C8f0Bdf1DC797Cb52419D28143D6F72f93
    getPoolsBalances - 0x238f0c7C5eA55281C8035FB2EC2255070c1de840
    */