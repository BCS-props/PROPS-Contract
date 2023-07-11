// SPDX-License-Identifier: MIT
pragma solidity 0.8.9-0.8.18;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts@v4.4/token/ERC20/IERC20.sol";

    /* 
유니스왑의 풀에 예치된 토큰 갯수를 가져오는 컨트랙트 

uniswap V3 dev reference : https://docs.uniswap.org/contracts/v3/reference/deployments

uniswap V3 factory Address : 0x1F98431c8aD98523631AE4a59f267346ea31F984

0x6E47d80aA74D5c65d5CeA5d6013ecf4EAD152d51 create Pool
0xA2E2e1a8891C9c85403a8632366ae73E228f60B0 getpool

@@@@@@@@@ ERC20 TOKEN Address @@@@@@@@@
goerli WETH : 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
goerli DAI : 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844
goerli UNI : 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984
goerli LINK : 0x326c977e6efc84e512bb9c30f76e30c160ed06fb
goerli stETH : 0x1643e812ae58766192cf7d2cf9567df2c37e9b7f
// 아래는 직접 만든 토큰
goerli UNI : 0x64f784E9Ff6268F1478aA2c666F951D61A909912
goerli wETH : 0x7a79603fC330157e1f447602520C1e1F74F770a3
goerli LINK : 0xBa14CbF8B0d0B5F05092A71633945540326a64F2

    @@@@@@@@@ UNISWAP Pool CA @@@@@@@@@
    goerli DAI/WETH pool CA : 0xB7Eb1cd21c39791Ca61a2A6FFf510248840b71E1
    goerli DAI/UNI pool CA : 0x5bDC607576bB5Fa9684E1b12c15AC4BE6faCAdcd
    goerli DAI/LINK pool CA : 0x60d1Ef64eE998c9F1b2b10eFBfbe0773B445d5a7
    // 아래는 직접 만든 풀
    goerli USDT/UNI pool CA : 0x42F1f26bE75098587b5924115F8a67847CDeBBa7
    goerli USDT/wETH pool CA : 0xc8832335c8A652a1dF29FF6a72F502B578EBDAa1
    goerli USDT/LINK pool CA : 0x84647B99Ca1ee4128013b08f6f3e6E87fda7B260

        @@@@@@@@@ UNISWAP GetBalance CA @@@@@@@@@
        0xE28C4C68e85135903d92e554dc10f60245a5Cd24 getbalance (DAI/LINK)
        0x2F5136C8f0Bdf1DC797Cb52419D28143D6F72f93 getbalance (DAI/WETH)
        0x418b2be7F5ABE9a7104f503F8FCf25192A5e091f getbalance (DAI/UNI)
        // 아래는 직접 만든 풀
        0xad89ea694eD2C5EB8Ecb197Bb633b673AdFC0AaC getbalance (USDT/UNI) / 100
        0xA75deC799397430a0F9Ea1E3b9B2e5046Ef64584 getbalance (USDT/wETH)
        0x18a93F0bbD067279cBcb880f3E81dD925f6FD54a getbalance (USDT/LINK) / 100
        
    */

// 풀의 예치량을 가져오는 컨트랙트
contract getBalance {
    address public poolAddress;  
    
    constructor(address _poolAddress) {
        poolAddress = _poolAddress;
    }   // WETH/DAI 페어의 풀 컨트랙트 주소
    
    function getPoolBalances() public view returns (uint256 DAI_Balance, uint256 WETH_Balance) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        address WETH_Token = pool.token0();
        IERC20 WETH = IERC20(WETH_Token);
        WETH_Balance = WETH.balanceOf(poolAddress);
        // WETH 예치량 가져오기
        
        address DAI_Token = pool.token1();
        IERC20 DAI = IERC20(DAI_Token);
        DAI_Balance = DAI.balanceOf(poolAddress);
        // DAI 예치량 가져오기
        
        return (WETH_Balance, DAI_Balance);
    }
}

interface UniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
    function createPool(address tokenA,address tokenB,uint24 fee) external returns (address pool);
} // 인터페이스 선언.

// 풀 주소를 가져오는 컨트랙트
contract getPool_Address {
    address public factoryAddress; 
    
    constructor(address _factoryAddress) {
        factoryAddress = _factoryAddress;
    }  // Uniswap V3 Factory CA 를 넣어야 함.
    
    function getPoolInfo(address tokenA, address tokenB, uint24 fee) external view returns (address) {
        IUniswapV3Factory factory = IUniswapV3Factory(factoryAddress);
        address pool = factory.getPool(tokenA, tokenB, fee);
        return pool;
    } // 각 토큰 CA , 수수료를 입력. 수수료는 보통 3000(0.3)
}

// 풀을 만드는 컨트랙트
contract Create_Pool {
    address public factoryAddress;

    constructor(address _factoryAddress) {
        factoryAddress = _factoryAddress;
    }  // Uniswap V3 Factory CA 를 넣어야 함.
    
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address) {
        IUniswapV3Factory factory = IUniswapV3Factory(factoryAddress);
        address pool = factory.createPool(tokenA, tokenB, fee);
        return pool;
    } // 각 토큰 CA , 수수료를 입력. 수수료는 보통 3000(0.3)
}

// wETH, UNI LINK 의 현재 가격을 반환하는 함수를 제공.
contract getPoolsBalances {
    getBalance getWETHBalance;
    getBalance getUNIBalance;
    getBalance getLINKBalance;
    
    constructor(){
        getWETHBalance = getBalance(0xA75deC799397430a0F9Ea1E3b9B2e5046Ef64584);
        getUNIBalance = getBalance(0xad89ea694eD2C5EB8Ecb197Bb633b673AdFC0AaC);
        getLINKBalance = getBalance(0x18a93F0bbD067279cBcb880f3E81dD925f6FD54a);
    }

    // 현재 wETH 가격 반환
    function getWETHBalances() public view returns(uint) {
        (uint token1, uint token2) = getWETHBalance.getPoolBalances();
        uint currentTokenPrice = token1 / token2;
        return currentTokenPrice;
    }

    // 현재 UNI 가격 반환 ( / 1000 해주어야 함 )
    function getUNIBalances() public view returns(uint) {
        (uint token1, uint token2) = getUNIBalance.getPoolBalances();
        uint currentTokenPrice = token1 / token2;
        return currentTokenPrice;
    }

    // 현재 LINK 가격 반환 ( / 1000 해주어야 함 )
    function getLINKBalances() public view returns(uint) {
        (uint token1, uint token2) = getLINKBalance.getPoolBalances();
        uint currentTokenPrice = token1 / token2;
        return currentTokenPrice;
    }
}