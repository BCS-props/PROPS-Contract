// SPDX-License-Identifier: MIT
pragma solidity 0.8.9-0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT_TEST is ERC20("US Dollar Tether","USDT") {
    
    receive() external payable{}
    constructor(uint _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }

    function mintToken(uint _amount) public {
        _mint(address(this), _amount);
    }
    
    function decimals() public pure override returns (uint8) {
        return 0;
    }
}