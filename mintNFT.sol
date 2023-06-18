// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

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
    string public URI;
    address insurPool;
    uint public tokenId;
    uint LastMintedTime;
    
    mapping(address => uint) totalSpend;
    uint8 priceFormula = 10; // 수수료율

    constructor(string memory _uri, address _insurPool) ERC721("cover","BCS"){
        URI = _uri;
        insurPool = _insurPool;
        _setDefaultRoyalty(_insurPool, 1000); // 10% 로열티 설정. << OPENSEA 와 같은 사이트에서 인식함. 실제 거래에선 적용 안됨.
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintNFT_Cover(uint _amount) public payable {
        ERC20 token = ERC20(0xA2c688D07831D6875F796dc02684f5F4AC185519);
        uint coverPrice = _amount * (priceFormula * 1/100);
        LastMintedTime = block.timestamp;
        totalSpend[msg.sender] += coverPrice;

        // 토큰 허용량 설정 (위 설정한 erc20 컨트랙트에서, increaseAllowance 설정하면 전송됨.
        // 상속받아서, increaseAllowance 를 건드리는건 가능. 하지만 msg.sender 가 들어가있어서 안됨.)
        token.approve(address(this), _amount);
        // require(token.allowance(msg.sender, address(this)) >= _amount,"Your balance is not enougth");
        // 토큰 전송하기
        token.transferFrom(msg.sender, insurPool, _amount); // _amount 로. 테스트 하기 위해 설정

        _mint(msg.sender, ++tokenId);
    }

    function getLastMintTime() public view returns(uint) {
        return LastMintedTime;
    }

    function tokenURI(uint) public view override returns(string memory){
        uint tokenIds = tokenId+1;
        return string(abi.encodePacked(URI, "/", Strings.toString(tokenIds), ".json"));
    } // uri 붙히는 작업

    function getTotalSpend() public view returns(uint){
        return totalSpend[msg.sender];
    }
    // 0x88cDBb31196Af16412F9a3D4196D645a830E5a4b
}
