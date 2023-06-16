// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

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
*/

contract mint721token is ERC721Enumerable,ERC2981 {
    string public URI;
    address insurPool;
    uint public tokenId;
    uint LastMintedTime;

    constructor(string memory _uri, address _insurPool) ERC721("color","clr"){
        URI = _uri;
        insurPool = _insurPool;
        _setDefaultRoyalty(_insurPool, 1000); // 10% 로열티 설정.
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintNFT_Cover() public payable {
        LastMintedTime = block.timestamp;
        uint tokenIds = ++tokenId;
        _mint(msg.sender, tokenIds);
        payable(insurPool).transfer(msg.value);
    }

    function getLastMintTime() public view returns(uint) {
        return LastMintedTime;
    }

    function tokenURI(uint inputAnything) public view override returns(string memory){
        uint tokenIds = tokenId+1;
        return string(abi.encodePacked(URI, "/" , Strings.toString(tokenIds) , ".json"));
    } // uri 붙히는 작업



}