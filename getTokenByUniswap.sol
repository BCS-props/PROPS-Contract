// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    /* 
유니스왑의 풀에 예치된 토큰 갯수를 가져오는 컨트랙트 

uniswap V3 dev reference : https://docs.uniswap.org/contracts/v3/reference/deployments

uniswap V3 factory Address : 0x1F98431c8aD98523631AE4a59f267346ea31F984

goerli WETH : 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
goerli DAI : 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844
goerli UNI : 0x1f9840a85d5af5bf1d1762f925bdaddc4201f984

goerli DAI/WETH pool CA : 0xB7Eb1cd21c39791Ca61a2A6FFf510248840b71E1
goerli UNI/WETH pool CA : 0x5bDC607576bB5Fa9684E1b12c15AC4BE6faCAdcd

0xA2E2e1a8891C9c85403a8632366ae73E228f60B0 getpool
0x2F5136C8f0Bdf1DC797Cb52419D28143D6F72f93 getbalance (DAI/WETH)
0x418b2be7F5ABE9a7104f503F8FCf25192A5e091f getbalance (DAI/UNI)

    */

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
} // 인터페이스 선언. getPool 함수를 사용함..

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
