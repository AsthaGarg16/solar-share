// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SolarProject.sol";
import "./SolarShare.sol";
import "./SolarGovernance.sol";

/**
 * @title SolarFactory
 * @dev 太阳能项目工厂：负责一键部署并绑定全套合约系统，确保权限链路闭环。
 * @dev Solar project factory: responsible for one-click deployment and binding of the full contract system,
 *      ensuring a complete and secure permission flow.
 */
contract SolarFactory {
    // 记录所有部署出来的项目地址
    // Store all deployed project addresses
    address[] public allProjects;

    event ProjectCreated(
        address indexed project, 
        address indexed share, 
        address indexed governance, 
        string name
    );

    /**
     * @notice 创建一个全新的太阳能项目
     * @notice Create a new solar project
     * @param _usdc USDC 代币地址
     * @param _usdc USDC token address
     * @param _platformAdmin 平台 2% 分账收款地址
     * @param _platformAdmin Platform fee (2%) recipient address
     * @param _governance 外部治理合约地址（如果传入 address(0) 则在内部新建）
     * @param _governance External governance contract address (if address(0), a new one will be deployed internally)
     * @param _host 业主地址（众筹满额后接收本金的人）
     * @param _host Host address (receives principal after full funding)
     * @param _initialValue 项目初始估值/筹款上限
     * @param _initialValue Initial project valuation / funding cap
     * @param _tokenName 代币名称 (如 "Solar Share A")
     * @param _tokenName Token name (e.g. "Solar Share A")
     * @param _tokenSymbol 代币符号 (如 "SLSA")
     * @param _tokenSymbol Token symbol (e.g. "SLSA")
     */
    function createProject(
        address _usdc,
        address _platformAdmin,
        address _governance,
        address _host,
        uint256 _initialValue,
        string memory _tokenName,
        string memory _tokenSymbol
    ) external returns (address) {
        
        // 1. 部署股份代币 (SLS)
        // 1. Deploy share token (SLS)
        // 关键点：传入 address(this)，让工厂暂时成为代币的 Owner，以便后续转让权限
        // Key point: pass address(this) so the factory temporarily owns the token for later ownership transfer
        SolarShare newShare = new SolarShare(_tokenName, _tokenSymbol, address(this));

        // 2. 治理合约逻辑处理
        // 2. Governance contract handling
        address finalGov = _governance;
        if (finalGov == address(0)) {
            // 如果没传治理合约，工厂现场部署一个，并将初始 Owner 设为工厂自己以便配置
            // If no governance contract is provided, deploy one and set factory as initial owner for setup
            SolarGovernance newGov = new SolarGovernance(address(newShare), address(this));
            finalGov = address(newGov);
        }

        // 3. 部署项目主合约
        // 3. Deploy main project contract
        // 构造函数参数顺序: usdc, share, admin, gov, host, owner, value
        // Constructor params: usdc, share, admin, gov, host, owner, value
        SolarProject newProject = new SolarProject(
            _usdc,
            address(newShare),
            _platformAdmin,
            finalGov,
            _host,
            msg.sender, // 将项目主合约的 Owner 设为调用者 Set project contract owner as the caller
            _initialValue
        );

        // 4. 执行权限与绑定配置 (原子操作)
        // 4. Perform permission and binding setup (atomic operation)
        
        // A. 将 SLS 代币的铸造权从工厂移交给项目合约 (项目合约需要调用 mint)
        // A. Transfer minting ownership of SLS token from factory to project contract (needed for mint)
        newShare.transferOwnership(address(newProject));

        // B. 如果是新部署的治理合约，进行初始化绑定并移交所有权给用户
        // B. If governance contract was newly deployed, bind it and transfer ownership to user
        if (_governance == address(0)) {
            // 绑定治理合约要控制的项目地址
            // Bind governance contract to the project
            SolarGovernance(finalGov).setProjectContract(address(newProject));
            // 将治理合约的管理权从工厂移交给用户 (msg.sender)
            // Transfer governance ownership from factory to user (msg.sender)
            SolarGovernance(finalGov).transferOwnership(msg.sender);
        }

        // 5. 登记并触发事件
        // 5. Register and emit event
        allProjects.push(address(newProject));
        emit ProjectCreated(
            address(newProject), 
            address(newShare), 
            finalGov, 
            _tokenName
        );

        return address(newProject);
    }

    // 获取部署的项目总数
    // Get total number of deployed projects
    function getProjectCount() external view returns (uint256) {
        return allProjects.length;
    }
}