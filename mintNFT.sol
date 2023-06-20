// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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

contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    IERC20 public tokenAddress;
    uint256 public rate = 100 * 10 ** 18;

    Counters.Counter private _tokenIdCounter;

    constructor(address _tokenAddress) ERC721("Sand Cover", "SC") {
        tokenAddress = IERC20(_tokenAddress);
    }

    function safeMint() public {
        tokenAddress.transferFrom(msg.sender, address(this), rate);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
    }

    function withdrawToken() public onlyOwner {
        tokenAddress.transfer(msg.sender, tokenAddress.balanceOf(address(this)));
    }
    // 0x88cDBb31196Af16412F9a3D4196D645a830E5a4b 2nd EOA
    // 0x078d1B0B379d1c76C9944Fa6ed5eEdf11D6A4D80 USDT CA
}