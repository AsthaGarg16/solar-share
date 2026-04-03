// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 引入 OpenZeppelin 的标准 ERC20 和 权限控制
// Import OpenZeppelin standard ERC20 and access control contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SolarShare Token
 * @dev 代表太阳能项目的投资份额。1个 Token = 1个股份。
 * @dev Represents investment shares of a solar project. 1 Token = 1 share.
 */
contract SolarShare is ERC20, Ownable {
    
    /**
     * @dev 构造函数修改：不再写死名字。
     * @dev Constructor updated: name is no longer hardcoded.
     * 这样 Factory 部署时可以传入 "Shanghai Solar", "SHS" 等参数。
     * This allows the Factory to pass parameters like "Shanghai Solar", "SHS", etc. during deployment.
     * Ownable(initialOwner) 兼容 OpenZeppelin 5.0 语法。
     * Ownable(initialOwner) is compatible with OpenZeppelin 5.0 syntax.
     */
    constructor(
        string memory name, 
        string memory symbol, 
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
    }

    /**
     * @dev 铸造代币函数：只有管理员（主控合约 SolarProject）有权调用
     * @dev Mint function: only the admin (main SolarProject contract) can call this
     * @param to 接收份额的投资人地址
     * @param to Address of the investor receiving shares
     * @param amount 铸造的数量
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev 销毁代币函数：当发生“买断（Buyout）”或“撤销退款”时，由 Project 合约触发。
     * @dev Burn function: triggered by the Project contract during buyout or refund reversal.
     * @param _from 被扣除份额的地址
     * @param _from Address from which shares are deducted
     * @param _amount 销毁的数量
     * @param _amount Amount to burn
     */
    function burn(address _from, uint256 _amount) external {
        // 权限检查：确保只有拥有该 Share 合约所有权的 Project 合约才能执行销毁
        // Permission check: ensure only the Project contract (owner of this Share contract) can execute burn
        require(msg.sender == owner(), "Only Project contract can burn");
        _burn(_from, _amount);
    }

    /**
     * @dev 覆盖小数位数：设为 6 位（和 USDC 保持一致）
     * @dev Override decimals: set to 6 (consistent with USDC)
     * 这样 1个 USDC = 1个 SLS，计算最精准。
     * This ensures 1 USDC = 1 SLS for precise calculations.
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}