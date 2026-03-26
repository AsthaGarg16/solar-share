// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev 这是一个模拟的 USDC，专门用于测试和演示。
 * @dev This is a mock USDC token, used for testing and demonstration purposes.
 */
contract MockUSDC is ERC20 {
    // 构造函数：定义代币名称和符号
    // Constructor: define token name and symbol
    constructor() ERC20("USD Coin (Mock)", "USDC") {}

    /**
     * @dev 水龙头函数：任何人调用它，都会获得 1000 个模拟 USDC
     * 1000 * 10^6 (因为 USDC 是 6 位小数)
     * @dev Faucet function: anyone calling it will receive 1000 mock USDC
     *      1000 * 10^6 (since USDC has 6 decimals)
     */
    function faucet() public {
        _mint(msg.sender, 1000 * 10**6);
    }

    /**
     * @dev 覆盖小数位数，设为 6 位（这是模拟真实 USDC 的关键）
     * @dev Override decimals to 6, simulating real USDC
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /**
     * @dev 允许测试脚本为特定地址铸造代币
     * @dev Allows test scripts to mint tokens to a specific address
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}