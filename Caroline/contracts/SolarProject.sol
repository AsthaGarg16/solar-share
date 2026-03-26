// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SolarShare.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SolarProject
 * @dev 太阳能资产管理主合约：支持筹款状态机、线性折旧、自动资金释放及买断分账。
 * @dev Main contract for solar asset management: supports funding state machine, linear depreciation,
 *      automatic fund release, and buyout settlement.
 */
contract SolarProject is Ownable, ReentrancyGuard {
    // --- 状态定义 ---
    // --- Status definition ---
    enum ProjectStatus { Funding, Generating, Liquidated }
    ProjectStatus public status;

    // --- 引入外部合约 ---
    // --- External contracts ---
    SolarShare public shareToken; 
    IERC20 public usdcToken;      
    address public governance;    

    // --- 项目基本信息 ---
    // --- Basic project information ---
    uint256 public initialValue;   // 初始估值 & 筹款上限 initial valuation & funding cap
    uint256 public totalInvested;  // 当前已筹集总额 total funds raised so far
    uint256 public startTime;      // 发电开始时间戳（用于计算折旧） generation start timestamp (used for depreciation calculation)
    address public platformAdmin;  // 平台管理地址 (接收2%费用) platform admin address (receives 2% fee)
    address public host;           // 资产持有者/业主 (接收筹款本金) asset owner/host (receives principal)

    // --- 资金池 ---
    // --- Fund pool ---
    uint256 public maintenanceFund; 

    // --- 分账比例 (基数 10000) ---
    // --- Revenue split ratios (base 10000) ---
    uint256 public constant PLATFORM_FEE_BPS = 200;    
    uint256 public constant MAINTENANCE_FEE_BPS = 500; 
    uint256 public constant INVESTOR_SHARE_BPS = 9300; 

    // --- 分红账本 ---
    // --- Dividend accounting ---
    uint256 public accDividendPerShare;
    mapping(address => uint256) public rewardDebt;

    // --- 事件 ---
    // --- Events ---
    event Invested(address indexed user, uint256 amount);
    event ProjectStarted(uint256 timestamp);
    event RevenueDistributed(uint256 totalAmount, uint256 platformFee, uint256 maintenanceFee);
    event DividendClaimed(address indexed user, uint256 amount);
    event ProjectLiquidated(uint256 finalBookValue, uint256 returnedMaintenance);
    event MaintenanceWithdrawn(address indexed receiver, uint256 amount);

    constructor(
        address _usdcAddress, 
        address _shareAddress, 
        address _platformAdmin,
        address _governance,
        address _host,
        address _initialOwner, 
        uint256 _initialValue
    ) Ownable(_initialOwner) { 
        usdcToken = IERC20(_usdcAddress);
        shareToken = SolarShare(_shareAddress);
        platformAdmin = _platformAdmin;
        governance = _governance;
        host = _host;
        initialValue = _initialValue;
        status = ProjectStatus.Funding; 
    }

    /**
     * @notice 1. 投资逻辑：仅在 Funding 阶段开放
     * @notice 1. Investment logic: only available during Funding stage
     */
    function invest(uint256 _usdcAmount) external nonReentrant {
        require(status == ProjectStatus.Funding, "Project not in funding stage");
        require(_usdcAmount > 0, "Amount must > 0");
        require(totalInvested + _usdcAmount <= initialValue, "Exceeds funding cap");

        // 转移 USDC 到合约托管
        // Transfer USDC into contract custody
        require(usdcToken.transferFrom(msg.sender, address(this), _usdcAmount), "USDC transfer failed");

        totalInvested += _usdcAmount;
        shareToken.mint(msg.sender, _usdcAmount);

        // 检查是否融资完成
        // Check if funding is completed
        if (totalInvested == initialValue) {
            status = ProjectStatus.Generating;
            startTime = block.timestamp; 
            
            // 将全部本金释放给 Host (资产端)
            // Release all principal to the host (asset side)
            require(usdcToken.transfer(host, totalInvested), "Release to host failed");
            
            emit ProjectStarted(startTime);
        }

        emit Invested(msg.sender, _usdcAmount);
    }

    /**
     * @notice 2. 核心分账：仅在 Generating 阶段接收收益
     * @notice 2. Core revenue distribution: only active during Generating stage
     */
    function depositRevenue(uint256 _revenueAmount) external nonReentrant {
        require(status == ProjectStatus.Generating, "Project is not generating revenue");
        require(usdcToken.transferFrom(msg.sender, address(this), _revenueAmount), "Transfer failed");

        uint256 platformFee = (_revenueAmount * PLATFORM_FEE_BPS) / 10000;
        uint256 maintenanceFee = (_revenueAmount * MAINTENANCE_FEE_BPS) / 10000;
        uint256 investorAmount = _revenueAmount - platformFee - maintenanceFee;

        // 实时支付平台管理费
        // Transfer platform fee in real time
        require(usdcToken.transfer(platformAdmin, platformFee), "Platform fee transfer failed");
        
        maintenanceFund += maintenanceFee;

        uint256 totalSupply = shareToken.totalSupply();
        if (totalSupply > 0) {
            accDividendPerShare += (investorAmount * 1e12) / totalSupply;
        }

        emit RevenueDistributed(_revenueAmount, platformFee, maintenanceFee);
    }

    /**
     * @notice 3. 算法估值：每年 4% 线性折旧
     * @notice 3. Valuation algorithm: 4% linear depreciation per year
     */
    function getBookValue() public view returns (uint256) {
        if (status == ProjectStatus.Funding) return initialValue;
        
        uint256 timePassed = block.timestamp - startTime;
        uint256 yearsPassed = timePassed / 365 days;
        
        if (yearsPassed >= 25) return 0; 
        
        uint256 totalDepreciation = (initialValue * 4 * yearsPassed) / 100;
        return (initialValue > totalDepreciation) ? (initialValue - totalDepreciation) : 0;
    }

    /**
     * @notice 4. 领取分红
     * @notice 4. Claim dividends
     */
    function claimDividend() public nonReentrant {
        uint256 userBalance = shareToken.balanceOf(msg.sender);
        uint256 accumulated = (userBalance * accDividendPerShare) / 1e12;
        uint256 pending = accumulated - rewardDebt[msg.sender]; 
        
        if (pending > 0) {
            rewardDebt[msg.sender] = accumulated;
            require(usdcToken.transfer(msg.sender, pending), "Claim transfer failed");
            emit DividendClaimed(msg.sender, pending);
        }
    }

    /**
     * @notice 5. 买断逻辑：强制回购清算
     * @notice 5. Buyout logic: forced buyback and liquidation
     * 优化点：买断时自动清空维修基金并全部分配给投资者
     * Optimization: remaining maintenance fund is distributed to investors during buyout
     */
    function buyout() external onlyOwner nonReentrant {
        require(status == ProjectStatus.Generating, "Only active projects can be bought out");
        
        uint256 currentPrice = getBookValue();
        uint256 totalSupply = shareToken.totalSupply();
        
        // 计算买断总额
        // Calculate total buyout cost
        uint256 totalBuyoutCost = (totalSupply * currentPrice) / initialValue;

        // 扣除 Owner 的买断资金
        // Transfer buyout funds from owner
        require(usdcToken.transferFrom(msg.sender, address(this), totalBuyoutCost), "Buyout fund missing");

        // 【闭环优化】将剩余未使用的维修基金也加入分配池
        // Add remaining maintenance fund into distribution pool
        uint256 remainingMaintenance = maintenanceFund;
        maintenanceFund = 0; 

        // 投资者获得 = 买断款 + 剩余维修费
        // Investors receive buyout amount + remaining maintenance fund
        uint256 finalInvestorAmount = totalBuyoutCost + remainingMaintenance;
        accDividendPerShare += (finalInvestorAmount * 1e12) / totalSupply;
        
        status = ProjectStatus.Liquidated;
        
        emit ProjectLiquidated(currentPrice, remainingMaintenance);
    }

    /**
     * @notice 6. 维护费支取：仅限 Governance 角色拨付给第三方维修单位
     * @notice 6. Maintenance withdrawal: only Governance can release funds to service providers
     */
    function withdrawMaintenance(address _receiver, uint256 _amount) external {
        require(msg.sender == governance, "Only Governance can withdraw");
        require(_amount <= maintenanceFund, "Insufficient maintenance fund");
        
        maintenanceFund -= _amount;
        require(usdcToken.transfer(_receiver, _amount), "Maintenance transfer failed");

        emit MaintenanceWithdrawn(_receiver, _amount);
    }

    /**
     * @notice 7. 撤销项目：如果筹款进度不如预期，Owner 可以手动撤销
     * @notice 7. Cancel project: owner can cancel if funding progress is insufficient
     * @dev 撤销后状态变为 Liquidated，且 startTime 保持为 0，以此触发退款逻辑
     * @dev After cancellation, status becomes Liquidated and startTime remains 0 to enable refund logic
     */
    function cancelProject() external onlyOwner {
        require(status == ProjectStatus.Funding, "Can only cancel during funding");
        
        status = ProjectStatus.Liquidated;
        
        // 发射清算事件，标记账面价值为初始价值（本金）
        // Emit liquidation event with initial value (principal)
        emit ProjectLiquidated(initialValue, 0);
    }

    /**
     * @notice 8. 投资者退款：仅在项目被撤销（未开始发电）时有效
     * @notice 8. Investor refund: only valid if project is canceled before generation
     * @dev 用户调用此函数，销毁股份并 1:1 取回 USDC
     * @dev User burns shares and withdraws USDC at 1:1 ratio
     */
    function claimRefund() external nonReentrant {
        require(status == ProjectStatus.Liquidated, "Project not canceled/liquidated");
        require(startTime == 0, "Project already started, use claimDividend");

        uint256 userBalance = shareToken.balanceOf(msg.sender);
        require(userBalance > 0, "No investment to refund");

        // 1. 更新债务账本（防止退款后再去领分红的逻辑漏洞，虽然startTime为0领不到）
        // 1. Update reward debt to prevent claiming dividends after refund
        syncReward(msg.sender);

        // 2. 销毁投资者的股份 (需要 SolarShare 支持 burn)
        // 2. Burn investor shares (requires SolarShare burn support)
        shareToken.burn(msg.sender, userBalance);

        // 3. 退还等额 USDC
        // 3. Refund equivalent USDC
        require(usdcToken.transfer(msg.sender, userBalance), "Refund transfer failed");
    }

    /**
     * @notice 辅助函数：当用户转账股份前建议同步
     * @notice Helper function: recommended to sync before transferring shares
     * 演示时，如果手动测试分账，可以在转账前调用此函数
     * During testing, call this before transfers to ensure accurate accounting
     */
    function syncReward(address _user) public {
        uint256 userBalance = shareToken.balanceOf(_user);
        rewardDebt[_user] = (userBalance * accDividendPerShare) / 1e12;
    }
}